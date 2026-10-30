package dev.zswatch.app.companion

import io.runtime.mcumgr.McuMgrErrorCode
import io.runtime.mcumgr.exception.McuMgrException
import io.runtime.mcumgr.exception.McuMgrErrorException
import io.runtime.mcumgr.response.fs.McuMgrFsStatusResponse
import java.io.IOException

/** Nordic can deliver missing-file status as a response or an error callback. */
internal object PrototypeLogStatus {
    fun response(value: McuMgrFsStatusResponse): Result<Int?> = runCatching {
        when {
            value.isSuccess -> value.len.also { check(it >= 0) { "Invalid log size" } }
            else -> throw McuMgrErrorException(value)
        }
    }.recoverCatching { error ->
        if (missing(error)) null else throw error
    }
    fun failure(error: McuMgrException): Result<Int?> =
        if (missing(error)) Result.success(null)
        else Result.failure(IllegalStateException(
            "Watch file status failed: ${failureMessage(error)}", error))

    /** Decoder IOExceptions can quote file contents; keep those out of logs and UI errors. */
    fun failureMessage(error: McuMgrException): String =
        if (generateSequence<Throwable>(error) { it.cause }.any { it is IOException })
            "Invalid file response from watch"
        else error.message ?: "No response from watch"

    private fun missing(error: Throwable): Boolean {
        if (error !is McuMgrErrorException) return false
        val group = error.groupCode
        // Existing Zephyr fs group=8, FILE_NOT_FOUND=3; SMP v1 NO_ENTRY.
        return if (group != null) group.group == 8 && group.rc == 3
               else error.code == McuMgrErrorCode.NO_ENTRY
    }
}
