# FFmpegKit's JNI loader resolves Java classes/members by their original names.
# Its Flutter library declares these rules as proguardFiles rather than consumer
# rules, so the application must retain the JNI surface in the final R8 pass.
-keep class com.antonkarpenko.ffmpegkit.** { *; }
