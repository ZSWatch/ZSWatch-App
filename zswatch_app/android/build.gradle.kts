allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// Fix whisper_ggml_plus v1.3.5 Android bugs (see https://github.com/DDULDDUCK/whisper_ggml_plus/issues/15):
// Bug 1: Missing GGML_USE_CPU define → CPU backend never registered → SIGABRT on model load
// Bug 2: Missing arch-specific sources (ARM NEON quants) → linker errors after Bug 1 fix
// Bug 3: Missing -llog link → undefined __android_log_print
// Bug 4: -fvisibility=hidden hides FFI "request" symbol → Failed to lookup symbol
// Plus: main.cpp hardcodes use_gpu=true and flash_attn=true (no GPU backend on Android)
subprojects {
    if (project.name == "whisper_ggml_plus") {
        project.afterEvaluate {
            // Fix Bug 4: Remove -fvisibility=hidden from Gradle-level flags
            extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)?.apply {
                defaultConfig.externalNativeBuild.cmake.apply {
                    val fixedC = cFlags.map {
                        it.replace("-fvisibility=hidden", "")
                          .replace("-fvisibility-inlines-hidden", "")
                    }
                    cFlags.clear()
                    cFlags.addAll(fixedC)

                    val fixedCpp = cppFlags.map {
                        it.replace("-fvisibility=hidden", "")
                          .replace("-fvisibility-inlines-hidden", "")
                    }
                    cppFlags.clear()
                    cppFlags.addAll(fixedCpp)
                }
            }

            // Fix Bugs 1-3: Patch CMakeLists.txt to add GGML_USE_CPU, arch sources, and -llog
            val cmakeLists = project.file("src/whisper/CMakeLists.txt")
            if (cmakeLists.exists()) {
                var cmake = cmakeLists.readText()
                var modified = false

                // Bug 1+2: Add GGML_USE_CPU=1 define and architecture-specific source files
                if (!cmake.contains("GGML_USE_CPU")) {
                    val archSources = """
# Architecture-specific source files (ARM NEON / x86 SSE-AVX)
if (ANDROID_ABI STREQUAL "arm64-v8a" OR ANDROID_ABI STREQUAL "armeabi-v7a")
    file(GLOB GGML_CPU_ARCH_SRC
        "${'$'}{GGML_CPU_SRC_DIR}/arch/arm/*.cpp"
        "${'$'}{GGML_CPU_SRC_DIR}/arch/arm/*.c"
    )
elseif (ANDROID_ABI STREQUAL "x86" OR ANDROID_ABI STREQUAL "x86_64")
    file(GLOB GGML_CPU_ARCH_SRC
        "${'$'}{GGML_CPU_SRC_DIR}/arch/x86/*.cpp"
        "${'$'}{GGML_CPU_SRC_DIR}/arch/x86/*.c"
    )
endif()

"""
                    cmake = cmake.replace(
                        "add_library(whisper \${WHISPER_SRC})",
                        archSources + "add_library(whisper \${WHISPER_SRC} \${GGML_CPU_ARCH_SRC})\ntarget_compile_definitions(whisper PRIVATE GGML_USE_CPU=1)"
                    )
                    modified = true
                }

                // Bug 3: Add log library to linker
                if (cmake.contains("target_link_libraries(whisper_flutter PRIVATE whisper)") &&
                    !cmake.contains("whisper log)")) {
                    cmake = cmake.replace(
                        "target_link_libraries(whisper_flutter PRIVATE whisper)",
                        "target_link_libraries(whisper_flutter PRIVATE whisper log)"
                    )
                    modified = true
                }

                if (modified) {
                    cmakeLists.writeText(cmake)
                    logger.lifecycle("[ZSWatch] Patched whisper_ggml_plus CMakeLists.txt: added GGML_USE_CPU=1, arch sources, -llog")
                }
            }

            // Patch main.cpp: disable flash_attn and use_gpu (no GPU backend on Android)
            val mainCpp = project.file("src/whisper/main.cpp")
            if (mainCpp.exists()) {
                var src = mainCpp.readText()
                val patched = src
                    .replace("cparams.flash_attn = true;", "cparams.flash_attn = false;")
                    .replace("cparams.use_gpu = true;", "cparams.use_gpu = false;")
                if (patched != src) {
                    mainCpp.writeText(patched)
                    logger.lifecycle("[ZSWatch] Patched whisper_ggml_plus main.cpp: disabled flash_attn and use_gpu")
                }
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
