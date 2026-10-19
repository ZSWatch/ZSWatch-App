package dev.zswatch.app.companion

import java.io.ByteArrayOutputStream
import java.net.HttpURLConnection
import java.net.URI
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import javax.net.ssl.HttpsURLConnection
import javax.net.ssl.SSLContext
import javax.net.ssl.X509TrustManager
import java.security.cert.X509Certificate
import java.nio.charset.Charset
import java.io.StringReader
import javax.xml.parsers.DocumentBuilderFactory
import javax.xml.xpath.XPathConstants
import javax.xml.xpath.XPathFactory
import org.xml.sax.InputSource
import org.w3c.dom.NodeList

/** GET only; IO never runs on the BLE handler. TLS bypass is explicit per request,
 * never a global trust-manager change. Redirects are bounded and cannot downgrade
 * HTTPS. Raw body/XML is bounded before parsing; no URL/body goes into diagnostics.
 */
internal class HttpUrlRelayExecutor(private val deliver: (() -> Unit) -> Unit) {
    private val pool = java.util.concurrent.ThreadPoolExecutor(2, 2, 0, java.util.concurrent.TimeUnit.SECONDS,
        java.util.concurrent.ArrayBlockingQueue(4),
        java.util.concurrent.ThreadFactory { task -> Thread(task, "ZSWatchHttp").apply { isDaemon = true } })
    private val cancellations = Executors.newSingleThreadExecutor { task -> Thread(task, "ZSWatchHttpCancel").apply { isDaemon = true } }
    private class Work {
        val cancelled = AtomicBoolean(false)
        @Volatile var connection: HttpURLConnection? = null
    }
    fun execute(request: RelayRequest, done: (RelayResult) -> Unit): () -> Unit {
        val work = Work()
        val future = pool.submit {
            val result = try { RelayResult(body = fetch(request, work)) }
            catch (error: RelayFailure) { RelayResult(error = error.message) }
            catch (_: java.net.SocketTimeoutException) { RelayResult(error = "Request timed out") }
            catch (_: javax.net.ssl.SSLException) { RelayResult(error = "TLS error") }
            catch (_: Exception) { RelayResult(error = "Network or response error") }
            if (!work.cancelled.get()) deliver { if (!work.cancelled.get()) done(result) }
        }
        return {
            if (work.cancelled.compareAndSet(false, true)) {
                future.cancel(true)
                // disconnect() can block on a platform implementation; keep it off BLE.
                runCatching { cancellations.execute { work.connection?.disconnect() } }
            }
        }
    }

    private class RelayFailure(message: String) : Exception(message)
    private fun uri(value: String): URI {
        val uri = try { URI(value) } catch (_: Exception) { throw RelayFailure("Invalid URL") }
        if (uri.scheme !in listOf("http", "https") || uri.host.isNullOrEmpty() || uri.rawUserInfo != null)
            throw RelayFailure("Invalid URL or unsupported scheme")
        return uri
    }
    private fun fetch(request: RelayRequest, work: Work): String {
        val deadline = System.nanoTime() + 6_000_000_000L
        var target = uri(request.url)
        for (redirect in 0..4) {
            if (work.cancelled.get() || Thread.currentThread().isInterrupted) throw RelayFailure("Cancelled")
            val remaining = ((deadline - System.nanoTime()) / 1_000_000).toInt()
            if (remaining <= 0) throw RelayFailure("Request timed out")
            val connection = target.toURL().openConnection() as HttpURLConnection
            work.connection = connection
            try {
                connection.connectTimeout = remaining; connection.readTimeout = remaining
                connection.instanceFollowRedirects = false
                connection.requestMethod = "GET"
                connection.setRequestProperty("User-Agent", "ZSWatch-Companion/1.0")
                connection.setRequestProperty("Accept", "*/*")
                if (request.insecure && connection is HttpsURLConnection) {
                    val tls = SSLContext.getInstance("TLS")
                    tls.init(null, arrayOf(object : X509TrustManager {
                        override fun getAcceptedIssuers(): Array<X509Certificate> = emptyArray()
                        override fun checkClientTrusted(chain: Array<X509Certificate>, authType: String) {}
                        override fun checkServerTrusted(chain: Array<X509Certificate>, authType: String) {}
                    }), null)
                    connection.sslSocketFactory = tls.socketFactory
                    connection.hostnameVerifier = javax.net.ssl.HostnameVerifier { _, _ -> true }
                }
                val status = connection.responseCode
                if (status in listOf(301, 302, 303, 307, 308)) {
                    if (redirect == 4) throw RelayFailure("Too many redirects")
                    val location = connection.getHeaderField("Location") ?: throw RelayFailure("Invalid redirect")
                    val next = uri(target.resolve(location).toString())
                    if (target.scheme == "https" && next.scheme != "https") throw RelayFailure("Insecure redirect")
                    target = next; continue
                }
                if (status !in 200..299) throw RelayFailure("HTTP $status")
                if (connection.contentLengthLong > 65536) throw RelayFailure("Response too large")
                val bytes = ByteArrayOutputStream()
                connection.inputStream.use { stream ->
                    val chunk = ByteArray(4096)
                    while (true) {
                        if (work.cancelled.get() || System.nanoTime() >= deadline) throw RelayFailure("Request timed out")
                        val count = stream.read(chunk)
                        if (count < 0) break
                        if (bytes.size() + count > 65536) throw RelayFailure("Response too large")
                        bytes.write(chunk, 0, count)
                    }
                }
                val charset = Regex("charset=([^;\\s]+)", RegexOption.IGNORE_CASE)
                    .find(connection.contentType ?: "")?.groupValues?.get(1)?.trim('"', '\'') ?: "UTF-8"
                val body = bytes.toByteArray().toString(Charset.forName(charset))
                return if (request.xpath.isNullOrEmpty()) body else xpath(body, request.xpath)
            } finally { connection.disconnect(); if (work.connection === connection) work.connection = null }
        }
        throw RelayFailure("Too many redirects")
    }
    private fun xpath(body: String, expression: String): String {
        try {
            // Android XML providers vary in feature support. Reject DTD syntax
            // before parsing as well as disabling entities where supported.
            if (body.contains("<!DOCTYPE", ignoreCase = true) || body.contains("<!ENTITY", ignoreCase = true))
                throw RelayFailure("XPath error")
            val factory = DocumentBuilderFactory.newInstance()
            runCatching { factory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true) }
            runCatching { factory.setFeature("http://xml.org/sax/features/external-general-entities", false) }
            runCatching { factory.setFeature("http://xml.org/sax/features/external-parameter-entities", false) }
            factory.isExpandEntityReferences = false
            val document = factory.newDocumentBuilder().parse(InputSource(StringReader(body)))
            val nodes = XPathFactory.newInstance().newXPath().evaluate(expression, document, XPathConstants.NODESET) as NodeList
            if (nodes.length == 0) throw RelayFailure("XPath returned no results")
            return (0 until nodes.length).joinToString("\n") { nodes.item(it).textContent }
        } catch (error: RelayFailure) { throw error }
        catch (_: Exception) { throw RelayFailure("XPath error") }
    }
    fun close() { pool.shutdownNow(); cancellations.shutdown() }
}
