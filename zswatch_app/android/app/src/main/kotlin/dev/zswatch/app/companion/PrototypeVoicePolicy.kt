package dev.zswatch.app.companion

/** Captures the user's selected local configuration when a new recording arrives. */
object PrototypeVoicePolicy {
    fun configuration(stt: String, llm: String, correct: Boolean): Map<String, Any> {
        require(stt.matches(Regex("[a-zA-Z0-9_]+")) && stt.length <= 128)
        require(llm.isNotBlank() && llm.length <= 256 && !llm.contains('|'))
        return mapOf("transcription_model" to stt, "analysis_model" to llm, "correct_transcription" to correct)
    }

    fun recordingRequest(policy: Any?, watchId: String): Map<String, Any>? {
        val value = policy as? Map<*, *> ?: return null
        if (value["enabled"] != true || value["watch_id"] != watchId) return null
        return configuration(value["transcription_model"] as String, value["analysis_model"] as String,
            value["correct_transcription"] as Boolean)
    }

    fun model(request: Map<*, *>): String {
        val value = configuration(request["transcription_model"] as String, request["analysis_model"] as String,
            request["correct_transcription"] as Boolean)
        return "${value["transcription_model"]}|${value["analysis_model"]}|${value["correct_transcription"]}"
    }
}
