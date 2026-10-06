package dev.zswatch.app.companion

import org.json.JSONObject

/** The firmware's existing `coredump summary` shell response. */
internal object PrototypeCoredumpSummary {
    fun packet(output: String, returnCode: Long = 0): JSONObject {
        require(output.length <= 8192) { "Coredump summary is too large" }
        // Current firmware propagates fs_open's -ENOENT when the file is absent,
        // including immediately after its existing erase command.
        if (returnCode == -2L && output.trim() == "Failed to read summary (-2)")
            return JSONObject().put("t", "coredump").put("available", false)
        require(returnCode == 0L) { "Coredump summary command failed" }
        if (output.trim() == "No stored coredumps")
            return JSONObject().put("t", "coredump").put("available", false)
        fun field(name: String): String {
            val matches = Regex("^\\s*${Regex.escape(name)}: (.+?)\\s*$", RegexOption.MULTILINE)
                .findAll(output).toList()
            require(matches.size == 1) { "Invalid coredump $name" }
            return matches.single().groupValues[1].trim()
        }
        require(field("Stored coredumps").toIntOrNull() in 1..32) { "Invalid coredump count" }
        val line = field("Line").toIntOrNull()
        require(line != null && line >= 0) { "Invalid coredump line" }
        val file = field("File"); val time = field("Timestamp")
        require(file.toByteArray(Charsets.UTF_8).size in 1..512 && time.length in 1..80)
        return JSONObject().put("t", "coredump").put("available", true)
            .put("file", file).put("line", line).put("time", time)
    }
}
