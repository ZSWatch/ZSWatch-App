package dev.zswatch.app

import android.content.Context
import android.util.Log
import com.google.ai.edge.litertlm.Backend
import com.google.ai.edge.litertlm.Conversation
import com.google.ai.edge.litertlm.ConversationConfig
import com.google.ai.edge.litertlm.Contents
import com.google.ai.edge.litertlm.Content
import com.google.ai.edge.litertlm.Engine
import com.google.ai.edge.litertlm.EngineConfig
import com.google.ai.edge.litertlm.Message
import com.google.ai.edge.litertlm.MessageCallback
import com.google.ai.edge.litertlm.SamplerConfig
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.Job
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.cancel
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import java.util.concurrent.CancellationException

/**
 * Bridge between Flutter and the LiteRT-LM on-device inference engine.
 *
 * Provides a MethodChannel + EventChannel pair:
 * - MethodChannel: loadModel, generate, cancel, dispose
 * - EventChannel: streams partial tokens during generation
 */
class LiteRtLmBridge(
    private val context: Context,
    private val mainDispatcher: CoroutineDispatcher = Dispatchers.Main,
    workDispatcher: CoroutineDispatcher = Dispatchers.IO,
) {

    companion object {
        private const val TAG = "LiteRtLmBridge"
        private const val METHOD_CHANNEL = "dev.zswatch.app/litert_lm"
        private const val EVENT_CHANNEL = "dev.zswatch.app/litert_lm_events"
    }

    private var engine: Engine? = null
    private var conversation: Conversation? = null
    private var eventSink: EventChannel.EventSink? = null
    private val scope = CoroutineScope(SupervisorJob() + workDispatcher)
    private var currentJob: Job? = null
    private val generateMutex = Mutex()

    fun setup(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            METHOD_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "loadModel" -> {
                    val modelPath = call.argument<String>("modelPath")
                    val backend = call.argument<String>("backend") ?: "gpu"
                    val maxTokens = call.argument<Int>("maxTokens") ?: 4096
                    if (modelPath == null) {
                        result.error("INVALID_ARGUMENT", "modelPath is required", null)
                        return@setMethodCallHandler
                    }
                    scope.launch {
                        try {
                            loadModel(modelPath, backend, maxTokens)
                            launch(mainDispatcher) { result.success(true) }
                        } catch (e: Exception) {
                            Log.e(TAG, "loadModel failed", e)
                            launch(mainDispatcher) {
                                result.error("LOAD_FAILED", e.message, null)
                            }
                        }
                    }
                }
                "generate" -> {
                    val prompt = call.argument<String>("prompt")
                    val temperature = call.argument<Double>("temperature") ?: 0.3
                    val topK = call.argument<Int>("topK") ?: 40
                    val topP = call.argument<Double>("topP") ?: 1.0
                    if (prompt == null) {
                        result.error("INVALID_ARGUMENT", "prompt is required", null)
                        return@setMethodCallHandler
                    }
                    generate(prompt, temperature, topK, topP, result)
                }
                "cancel" -> {
                    cancel()
                    result.success(true)
                }
                "dispose" -> {
                    dispose()
                    result.success(true)
                }
                "isLoaded" -> {
                    result.success(engine != null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            EVENT_CHANNEL,
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    private fun loadModel(modelPath: String, backend: String, maxTokens: Int) {
        // Clean up any previous engine
        dispose()

        val preferredBackend = when (backend) {
            "cpu" -> Backend.CPU()
            "gpu" -> Backend.GPU()
            "npu" -> Backend.NPU(nativeLibraryDir = context.applicationInfo.nativeLibraryDir)
            else -> Backend.GPU()
        }

        Log.i(TAG, "Loading model: $modelPath (backend=$backend, maxTokens=$maxTokens)")

        val config = EngineConfig(
            modelPath = modelPath,
            backend = preferredBackend,
            maxNumTokens = maxTokens,
        )

        val eng = Engine(config)
        eng.initialize()
        engine = eng

        Log.i(TAG, "Model loaded successfully")
    }

    private fun createConversation(temperature: Double, topK: Int, topP: Double): Conversation {
        val eng = engine ?: throw IllegalStateException("Engine not loaded")

        // Close previous conversation if any
        conversation?.close()

        val conv = eng.createConversation(
            ConversationConfig(
                samplerConfig = SamplerConfig(
                    topK = topK,
                    topP = topP,
                    temperature = temperature,
                ),
            ),
        )
        conversation = conv
        return conv
    }

    @OptIn(ExperimentalCoroutinesApi::class)
    private fun generate(
        prompt: String,
        temperature: Double,
        topK: Int,
        topP: Double,
        result: MethodChannel.Result,
    ) {
        if (engine == null) {
            result.error("NOT_LOADED", "Model not loaded. Call loadModel first.", null)
            return
        }

        // Enter the try block even if cancel arrives before IO dispatch starts.
        currentJob = scope.launch(start = CoroutineStart.ATOMIC) {
            // Accessed only in Main dispatcher blocks below.
            var replied = false
            try {
                generateMutex.withLock {
                    currentCoroutineContext().ensureActive()
                    val conv = createConversation(temperature, topK, topP)
                    val accumulated = StringBuilder()
                    var tokenCount = 0
                    val startTime = System.currentTimeMillis()

                    // Prompts and output contain private transcript text; log sizes only.
                    Log.i(TAG, "generate: sending prompt (${prompt.length} chars)")

                    // Use CompletableDeferred to bridge async callbacks → coroutine
                    val deferred = CompletableDeferred<Map<String, Any?>>()

                    conv.sendMessageAsync(
                        Contents.of(listOf(Content.Text(prompt))),
                        object : MessageCallback {
                            override fun onMessage(message: Message) {
                                val text = message.toString()
                                accumulated.append(text)
                                tokenCount++

                                // Stream partial result to Flutter via EventChannel
                                val partialMap = mapOf(
                                    "type" to "token",
                                    "text" to accumulated.toString(),
                                    "tokenCount" to tokenCount,
                                )
                                scope.launch(mainDispatcher) {
                                    eventSink?.success(partialMap)
                                }
                            }

                            override fun onDone() {
                                val elapsed = System.currentTimeMillis() - startTime
                                Log.i(TAG, "onDone: length=${accumulated.length} tokens=$tokenCount elapsed=${elapsed}ms")
                                deferred.complete(
                                    mapOf(
                                        "text" to accumulated.toString(),
                                        "tokenCount" to tokenCount,
                                        "elapsedMs" to elapsed,
                                    ),
                                )
                            }

                            override fun onError(throwable: Throwable) {
                                Log.e(TAG, "onError: ${throwable.javaClass.name}: ${throwable.message}", throwable)
                                if (throwable is CancellationException) {
                                    Log.i(TAG, "Inference cancelled")
                                    deferred.complete(
                                        mapOf(
                                            "text" to accumulated.toString(),
                                            "tokenCount" to tokenCount,
                                            "elapsedMs" to (System.currentTimeMillis() - startTime),
                                            "cancelled" to true,
                                        ),
                                    )
                                } else {
                                    deferred.completeExceptionally(throwable)
                                }
                            }
                        },
                        emptyMap(),
                    )

                    // Retain the conversation and headless engine until the SDK
                    // finishes, including after cancelProcess. Coroutine cancellation
                    // alone does not establish that native inference has stopped.
                    val resultMap = withContext(NonCancellable) { deferred.await() }

                    // Send final event + MethodChannel result on main thread
                    withContext(mainDispatcher) {
                        if (replied) return@withContext
                        replied = true
                        result.success(resultMap)
                        eventSink?.success(
                            mapOf(
                                "type" to "done",
                                "text" to (resultMap["text"] as? String ?: ""),
                                "tokenCount" to (resultMap["tokenCount"] as? Int ?: 0),
                                "elapsedMs" to (resultMap["elapsedMs"] as? Long ?: 0L),
                            ),
                        )
                    }
                } // generateMutex.withLock
            } catch (e: Exception) {
                Log.e(TAG, "generate failed: ${e.javaClass.name}: ${e.message}", e)
                // Cancellation also reaches Dart, including while waiting for
                // the mutex. A cancelled coroutine cannot switch dispatchers
                // normally, which would otherwise leave invokeMethod pending.
                withContext(NonCancellable + mainDispatcher) {
                    // withContext can report cancellation after a successful
                    // reply was sent, while returning to the IO dispatcher.
                    if (replied) return@withContext
                    replied = true
                    result.error(if (e is CancellationException) "CANCELLED" else "GENERATE_FAILED", e.message, null)
                }
            }
        }
    }

    private fun cancel() {
        try {
            conversation?.cancelProcess()
        } catch (e: Exception) {
            Log.w(TAG, "cancel failed: ${e.message}")
        }
        currentJob?.cancel()
    }

    private fun dispose() {
        cancel()
        try {
            conversation?.close()
        } catch (e: Exception) {
            Log.w(TAG, "conversation close failed: ${e.message}")
        }
        try {
            engine?.close()
        } catch (e: Exception) {
            Log.w(TAG, "engine close failed: ${e.message}")
        }
        conversation = null
        engine = null
    }

    /** Called when the owning headless engine ends, including interrupted work. */
    fun close() {
        dispose()
        eventSink = null
        scope.cancel()
    }
}
