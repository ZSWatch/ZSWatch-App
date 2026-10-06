package dev.zswatch.app.companion

import org.junit.Assert.*
import org.junit.Test

class PrototypeLogFilesTest {
    private class Rig {
        var generation = 1L
        val timers = mutableListOf<() -> Unit>()
        val probes = mutableListOf<Pair<String, (Result<Int?>) -> Unit>>()
        val downloads = mutableListOf<(Result<ByteArray>) -> Unit>()
        val releases = mutableListOf<Long>()
        val results = mutableListOf<Result<PrototypeLogReply>>()
        val operation = PrototypeLogFiles({ it == generation }, { _, action -> timers.add(action) },
            { path, done -> probes.add(path to done) }, { _, _, done -> downloads.add(done) }, { releases.add(it) })
        fun start(path: String? = null) = operation.start(generation, path) { results.add(it) }
        fun status(size: Int?) = probes.last().second(Result.success(size))
    }
    @Test fun coredumpUsesSameReadOnlyBoundedFencedReaderButIsNotEnumeratedAsALog() {
        val r = Rig(); r.start(PrototypeLogFiles.COREDUMP_PATH)
        assertEquals(PrototypeLogFiles.COREDUMP_PATH, r.probes.single().first)
        r.status(3); r.downloads.single()(Result.success(byteArrayOf(1, 2, 3)))
        assertArrayEquals(byteArrayOf(1, 2, 3), r.results.single().getOrThrow().bytes)
        assertFalse(PrototypeLogFiles.COREDUMP_PATH in PrototypeLogFiles.paths)
        assertThrows(IllegalArgumentException::class.java) { Rig().start("/user/coredump.txt/../recordings/x") }
        val oversized = Rig(); oversized.start(PrototypeLogFiles.COREDUMP_PATH)
        oversized.status(PrototypeLogFiles.MAX_BYTES + 1)
        assertTrue(oversized.results.single().isFailure); assertTrue(oversized.downloads.isEmpty())
        val interrupted = Rig(); interrupted.start(PrototypeLogFiles.COREDUMP_PATH); interrupted.status(3)
        interrupted.generation++; interrupted.downloads.single()(Result.success(byteArrayOf(1, 2, 3)))
        assertTrue(interrupted.results.single().isFailure)
    }
    @Test fun fixedPathsAndSessionAreRequiredBeforeSdkAccess() {
        val r = Rig()
        for (path in listOf("/user/logs/log0008", "/user/logs/../recordings/a", "/user/logs/log0000/"))
            assertThrows(IllegalArgumentException::class.java) { r.start(path) }
        assertThrows(IllegalStateException::class.java) { r.operation.start(0, null) {} }
        assertTrue(r.probes.isEmpty()); assertFalse(r.operation.busy)
    }
    @Test fun missingFilesAreSkippedButTransportFailureIsNotAnEmptySuccess() {
        val r = Rig(); r.start(); r.status(7)
        repeat(7) { r.status(null) }
        assertEquals(PrototypeLogFiles.paths, r.probes.map { it.first })
        assertEquals(listOf(PrototypeLogFile(PrototypeLogFiles.paths.first(), 7)), r.results.single().getOrThrow().files)
        val failed = Rig(); failed.start(); failed.probes.single().second(Result.failure(IllegalStateException("offline")))
        assertTrue(failed.results.single().isFailure); assertEquals(1, failed.probes.size)
    }
    @Test fun duplicateStatusDoesNotAdvanceTheBatchTwice() {
        val r = Rig(); r.start(); val callback = r.probes.single().second
        callback(Result.success(3)); callback(Result.success(4))
        repeat(7) { r.status(null) }
        assertEquals(8, r.probes.size); assertEquals(3, r.results.single().getOrThrow().files.single().size)
        assertEquals(listOf(1L), r.releases)
    }
    @Test fun downloadsAreSizedBeforeAllocationAndMustMatchFinalLength() {
        val oversized = Rig(); oversized.start(PrototypeLogFiles.paths.first()); oversized.status(PrototypeLogFiles.MAX_BYTES + 1)
        assertTrue(oversized.results.single().isFailure); assertTrue(oversized.downloads.isEmpty())
        val r = Rig(); r.start(PrototypeLogFiles.paths.first()); r.status(2)
        r.downloads.single()(Result.success(byteArrayOf(1)))
        assertTrue(r.results.single().isFailure); assertFalse(r.operation.busy)
    }
    @Test fun successfulAndEmptyDownloadsReleaseExactlyOnce() {
        val r = Rig(); r.start(PrototypeLogFiles.paths.first()); r.status(2)
        r.downloads.single()(Result.success(byteArrayOf(1,2))); r.timers.single()()
        assertArrayEquals(byteArrayOf(1,2), r.results.single().getOrThrow().bytes)
        assertEquals(listOf(1L), r.releases)
        val empty = Rig(); empty.start(PrototypeLogFiles.paths.first()); empty.status(0)
        assertEquals(0, empty.results.single().getOrThrow().bytes!!.size); assertTrue(empty.downloads.isEmpty())
    }
    @Test fun stopReconnectAndLateCallbackCannotCompleteNewOperation() {
        val r = Rig(); r.start(PrototypeLogFiles.paths.first()); r.status(2)
        val old = r.downloads.single(); r.operation.close(); r.generation = 2
        r.start(); old(Result.success(byteArrayOf(1,2)))
        assertTrue(r.operation.busy); assertEquals(1, r.results.size)
        repeat(8) { r.status(null) }
        assertTrue(r.results.last().isSuccess); assertEquals(listOf(1L,2L), r.releases)
    }
    @Test fun deadlineAndLostGenerationRejectSuccessWithoutReplay() {
        val r = Rig(); r.start(); r.timers.single()(); r.status(3)
        assertTrue(r.results.single().isFailure); assertEquals(1, r.probes.size)
        val lost = Rig(); lost.start(); lost.generation = 2; lost.status(3)
        assertTrue(lost.results.single().isFailure); assertEquals(1, lost.probes.size)
    }
    @Test fun synchronousSdkCallbacksAndBusyRejectionRemainBounded() {
        val r = Rig(); r.start(); assertThrows(IllegalStateException::class.java) { r.start() }
        val results = mutableListOf<Result<PrototypeLogReply>>()
        val operation = PrototypeLogFiles({ true }, { _, _ -> }, { _, done -> done(Result.success(null)) },
            { _, _, _ -> error("unexpected") }, {})
        operation.start(1, null) { results.add(it) }
        assertTrue(results.single().isSuccess); assertFalse(operation.busy)
    }
}
