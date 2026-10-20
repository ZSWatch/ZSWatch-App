# FFmpegKit's JNI loader resolves Java classes/members by their original names.
# Its Flutter library declares these rules as proguardFiles rather than consumer
# rules, so the application must retain the JNI surface in the final R8 pass.
-keep class com.antonkarpenko.ffmpegkit.** { *; }

# LiteRT-LM's JNI reads SamplerConfig and other Kotlin classes by member name.
-keep class com.google.ai.edge.litertlm.** { *; }
