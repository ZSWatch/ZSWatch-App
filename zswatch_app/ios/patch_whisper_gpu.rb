# frozen_string_literal: true

# Build-time patch for whisper_ggml_plus: adds dynamic GPU/CPU switching.
#
# iOS kills Metal GPU command buffers when the app is backgrounded
# (kIOGPUCommandBufferCallbackErrorBackgroundExecutionNotPermitted), which
# crashes the entire process. This patch adds a `forceCpu` command so the
# Dart side can switch to CPU-only before running transcription in background
# and back to GPU when the app is foregrounded.
#
# Called from the Podfile post_install hook.

def patch_whisper_gpu_control(installer)
  # Find the whisper_flutter_plus.cpp source.
  # Flutter plugin sources live under ios/.symlinks/plugins/ (symlinked to
  # pub cache), not in the Pods root itself. Search both locations.
  pods_root = installer.sandbox.root
  podfile_dir = File.dirname(pods_root) # ios/ directory

  search_paths = [
    File.join(pods_root, '**', 'whisper_flutter_plus.cpp'),
    File.join(podfile_dir, '.symlinks', 'plugins', 'whisper_ggml_plus', '**', 'whisper_flutter_plus.cpp'),
  ]

  matches = search_paths.flat_map { |p| Dir.glob(p) }.uniq

  if matches.empty?
    Pod::UI.warn '[ZSWatch] whisper_flutter_plus.cpp not found — GPU patch skipped'
    return
  end

  matches.each do |cpp_path|
    src = File.read(cpp_path)

    # Guard: don't patch twice
    if src.include?('g_force_cpu')
      Pod::UI.message '[ZSWatch] whisper_flutter_plus.cpp already patched — skipping'
      next
    end

    # 1. Add g_force_cpu global + g_ctx_gpu_mode tracker after existing globals
    src.sub!(
      'static std::atomic<bool> g_should_abort(false);',
      <<~CPP.chomp
        static std::atomic<bool> g_should_abort(false);

        // --- ZSWatch GPU/CPU toggle for background safety ---
        // When true, Metal GPU is disabled and whisper runs on CPU only.
        // Controlled via {"@type": "forceCpu", "value": true/false} from Dart.
        static std::atomic<bool> g_force_cpu(false);
        // Tracks whether the cached context was created with GPU enabled.
        static bool g_ctx_gpu_mode = true;
      CPP
    )

    # 2. Replace hardcoded use_gpu=true with dynamic check, and recreate
    #    context when GPU mode changes.
    src.sub!(
      /if \(g_ctx == nullptr \|\| g_model_path != params\.model\)\s*\{[^}]*?cparams\.use_gpu = true;[^}]*?cparams\.flash_attn = true;[^}]*?g_ctx = whisper_init_from_file_with_params\(params\.model\.c_str\(\), cparams\);/m,
      <<~CPP.chomp
        const bool want_gpu = !g_force_cpu.load();
        if (g_ctx == nullptr || g_model_path != params.model || g_ctx_gpu_mode != want_gpu) {
            if (g_ctx_gpu_mode != want_gpu) {
                fprintf(stderr, "[ZSWatch] GPU mode changed (%s -> %s), recreating whisper context\\n",
                        g_ctx_gpu_mode ? "GPU" : "CPU", want_gpu ? "GPU" : "CPU");
            }
            dispose_context_locked();

            whisper_context_params cparams = whisper_context_default_params();
            cparams.use_gpu = want_gpu;
            cparams.flash_attn = want_gpu;  // flash_attn requires Metal
            g_ctx_gpu_mode = want_gpu;

            g_ctx = whisper_init_from_file_with_params(params.model.c_str(), cparams);
      CPP
    )

    # 3. Add handler for the forceCpu command in the request() function,
    #    right before the existing "abort" handler.
    src.sub!(
      'if (jsonBody["@type"] == "abort")',
      <<~CPP.chomp
        if (jsonBody["@type"] == "forceCpu") {
                    bool value = jsonBody.value("value", false);
                    g_force_cpu.store(value);
                    fprintf(stderr, "[ZSWatch] Whisper force_cpu set to %s\\n", value ? "true" : "false");
                    // Dispose context so next transcription recreates with correct mode
                    {
                        std::lock_guard<std::mutex> lock(g_mutex);
                        dispose_context_locked();
                    }
                    return jsonToChar({{"@type", "forceCpu"}, {"value", value}});
                }
                if (jsonBody["@type"] == "abort")
      CPP
    )

    File.write(cpp_path, src)
    Pod::UI.message "[ZSWatch] Patched whisper_flutter_plus.cpp: added dynamic GPU/CPU control"
  end
end
