package dev.zswatch.app

import android.content.Context
import android.util.Log
import com.google.ai.edge.litertlm.Conversation
import com.google.ai.edge.litertlm.Engine
import com.google.ai.edge.litertlm.MessageCallback
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineDispatcher
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.mockito.Answers
import org.mockito.MockedStatic
import org.mockito.Mockito.*
import java.util.concurrent.CancellationException
import kotlin.coroutines.CoroutineContext

/** Real bridge/coroutines with SDK terminal callbacks controlled by the test.
 * These cover channel settlement/lifetime, not inference with a real model. */
class LiteRtLmBridgeTest {
    private class QueueDispatcher : CoroutineDispatcher() {
        val tasks = ArrayDeque<Runnable>()
        override fun dispatch(context: CoroutineContext, block: Runnable) { tasks.add(block) }
    }
    private class Reply : MethodChannel.Result {
        val values = mutableListOf<Any?>()
        val errors = mutableListOf<String>()
        var onSuccess: (() -> Unit)? = null
        override fun success(value: Any?) { values.add(value); onSuccess?.invoke() }
        override fun error(code: String, message: String?, details: Any?) { errors.add(code) }
        override fun notImplemented() { fail("Unexpected notImplemented") }
        fun count() = values.size + errors.size
    }
    private val io = QueueDispatcher()
    private val main = QueueDispatcher()
    private lateinit var log: MockedStatic<Log>
    private lateinit var engine: Engine
    private lateinit var conversation: Conversation
    private lateinit var bridge: LiteRtLmBridge
    private val callbacks = mutableListOf<MessageCallback>()

    @Before fun setup() {
        // Both dispatch queues execute on this test thread, including static Log.
        log = mockStatic(Log::class.java)
        conversation = mock(Conversation::class.java) { call ->
            if (call.method.name == "sendMessageAsync" && call.arguments.getOrNull(1) is MessageCallback) {
                callbacks.add(call.getArgument(1))
                null
            } else Answers.RETURNS_DEFAULTS.answer(call)
        }
        engine = mock(Engine::class.java) { call ->
            if (call.method.name == "createConversation") conversation
            else Answers.RETURNS_DEFAULTS.answer(call)
        }
        bridge = LiteRtLmBridge(mock(Context::class.java), main, io)
        LiteRtLmBridge::class.java.getDeclaredField("engine").apply { isAccessible = true }.set(bridge, engine)
    }
    @After fun cleanup() {
        try {
            if (::bridge.isInitialized) { bridge.close(); drain() }
        } finally {
            if (::log.isInitialized) log.close()
        }
    }
    private fun drain() {
        var count = 0
        while (io.tasks.isNotEmpty() || main.tasks.isNotEmpty()) {
            check(count++ < 1000) { "Dispatcher did not settle" }
            if (io.tasks.isNotEmpty()) io.tasks.removeFirst().run()
            if (main.tasks.isNotEmpty()) main.tasks.removeFirst().run()
        }
    }
    private fun generate(reply: Reply) {
        LiteRtLmBridge::class.java.getDeclaredMethod("generate", String::class.java,
            Double::class.javaPrimitiveType, Int::class.javaPrimitiveType,
            Double::class.javaPrimitiveType, MethodChannel.Result::class.java)
            .apply { isAccessible = true }.invoke(bridge, "test prompt", 0.3, 40, 1.0, reply)
    }
    private fun cancel() {
        LiteRtLmBridge::class.java.getDeclaredMethod("cancel").apply { isAccessible = true }.invoke(bridge)
    }

    @Test fun cancelBeforeDispatchStillSettlesDartWithoutStartingSdk() {
        val reply = Reply()
        generate(reply)
        cancel()
        drain()
        assertEquals(listOf("CANCELLED"), reply.errors)
        assertEquals(1, reply.count())
        assertTrue(callbacks.isEmpty())
    }

    @Test fun activeCancellationWaitsForNativeTerminalCallbackAndRepliesOnce() {
        val reply = Reply()
        generate(reply)
        drain()
        assertEquals(1, callbacks.size)
        cancel()
        drain()
        verify(conversation).cancelProcess()
        assertEquals("Keep headless engine alive until SDK terminates", 0, reply.count())
        verify(conversation, never()).close()
        callbacks.single().onError(CancellationException("SDK cancellation complete"))
        drain()
        assertEquals(listOf("CANCELLED"), reply.errors)
        callbacks.single().onDone() // A late duplicate terminal callback cannot reply twice.
        drain()
        assertEquals(1, reply.count())
    }

    @Test fun cancellingQueuedGenerationSettlesItWithoutStartingAnotherInference() {
        val first = Reply()
        val queued = Reply()
        generate(first)
        drain()
        generate(queued)
        drain()
        cancel()
        drain()
        assertEquals(listOf("CANCELLED"), queued.errors)
        assertEquals(1, queued.count())
        assertEquals(0, first.count())
        callbacks.single().onError(CancellationException("SDK cancellation complete"))
        drain()
        assertEquals(true, (first.values.single() as Map<*, *>)["cancelled"])
        assertEquals(1, callbacks.size)
        assertEquals(1, first.count())
    }

    @Test fun cancellationAfterSuccessfulReplyCannotSendASecondReply() {
        val reply = Reply().apply { onSuccess = { cancel() } }
        generate(reply)
        drain()
        callbacks.single().onDone()
        drain()
        assertEquals(1, reply.values.size)
        assertTrue(reply.errors.isEmpty())
        assertEquals(1, reply.count())
    }
}
