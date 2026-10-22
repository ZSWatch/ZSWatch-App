package dev.zswatch.app.companion

/** Captures the user's selected local configuration when a new recording arrives. */
object PrototypeVoicePolicy {
    private val CLOUD_MODEL = Regex("openrouter:[A-Za-z0-9._:/-]{1,200}")
    fun isCloud(model: String) = model.startsWith("openrouter:")
    fun configuration(stt: String, llm: String, correct: Boolean, analyze: Boolean = true): Map<String, Any> {
        require((stt.matches(Regex("[a-zA-Z0-9_]+")) && stt.length <= 128) || stt.matches(CLOUD_MODEL))
        require(llm.isNotBlank() && llm.length <= 256 && !llm.contains('|'))
        return mapOf("transcription_model" to stt, "analysis_model" to llm, "correct_transcription" to correct,
            "analysis_enabled" to analyze)
    }

    /** The watch's Chat questions are always answered, even with memo processing off. */
    fun isQuestion(filename: String) = filename.startsWith("chat_") || filename.startsWith("chatr_")

    fun recordingRequest(policy: Any?, watchId: String, filename: String = ""): Map<String, Any>? {
        val value = policy as? Map<*, *> ?: return null
        val question = isQuestion(filename)
        // Questions use the last saved models, also ones saved for another watch.
        if (!question && (value["enabled"] != true || value["watch_id"] != watchId)) return null
        return configuration(value["transcription_model"] as String, value["analysis_model"] as String,
            value["correct_transcription"] as Boolean, question || value["analysis_enabled"] != false)
    }

    fun model(request: Map<*, *>): String {
        val value = configuration(request["transcription_model"] as String, request["analysis_model"] as String,
            request["correct_transcription"] as Boolean)
        return "${value["transcription_model"]}|${value["analysis_model"]}|${value["correct_transcription"]}"
    }
}
