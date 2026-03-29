# AI Testbench

Standalone Flutter app for benchmarking and evaluating on-device LLM models used by the ZSWatch companion app. It tests structured JSON extraction (intent classification, time extraction, correction) against local GGUF models via [fllama](https://pub.dev/packages/fllama), producing pass/fail results and tokens-per-second metrics.

## Purpose

The ZSWatch companion app uses on-device LLMs to process voice memos — classifying intents (reminder, event, note), extracting time expressions, and correcting transcription errors. This testbench:

- **Evaluates candidate GGUF models** for accuracy and speed before shipping them in the app.
- **Benchmarks structured extraction** — verifies the model outputs valid JSON matching the `chrono_ai_flow` schema.
- **Tests time expression resolution** — end-to-end from transcript → LLM extraction → `chrono_dart` parsing → resolved `DateTime`.
- **Tests transcript correction** — verifies the model can fix common STT errors (homophones, filler words, punctuation).

## Directory Structure

```
ai_testbench/
├── lib/
│   ├── main.dart                  # Entry point (GUI + headless modes)
│   ├── benchmark_main.dart        # Model benchmark runner (structured extraction)
│   ├── correction_main.dart       # Correction benchmark runner
│   ├── time_extraction_main.dart  # Time extraction benchmark runner
│   ├── prompts/                   # Prompt templates (shared via chrono_ai_flow)
│   ├── screens/                   # Flutter UI screens for interactive testing
│   └── services/
│       ├── llm_service.dart                     # fllama wrapper for inference
│       ├── model_benchmark_service.dart         # Structured extraction benchmark logic
│       ├── correction_benchmark_service.dart    # Correction benchmark logic
│       ├── time_extraction_benchmark_service.dart # Time extraction benchmark logic
│       └── time_expression_resolver.dart        # chrono_dart time resolution
├── bin/
│   └── test_time_extraction.dart  # CLI test runner (uses llama_cpp_dart directly)
├── models/                        # GGUF model files (gitignored, download separately)
├── native_libs/                   # Native shared libraries (gitignored, build separately)
├── benchmark_results/             # Saved benchmark summaries
└── test/
```

## Prerequisites

- Flutter SDK (channel stable)
- GGUF model files placed in `models/` (not committed — download from HuggingFace or equivalent)
- Linux desktop support enabled (`flutter config --enable-linux-desktop`)

## Setup

```bash
cd ai_testbench
flutter pub get
```

Place one or more `.gguf` model files in the `models/` directory. Recommended starting model: `Qwen3.5-2B-Q4_K_M.gguf`.

## Usage

### Interactive GUI

```bash
flutter run -d linux
```

Opens a desktop window with screens for running benchmarks interactively.

### Headless Benchmarks

Run from a compiled release build for consistent timing:

```bash
flutter build linux --release
```

**Structured extraction benchmark** (all models in `models/`):
```bash
./build/linux/x64/release/bundle/ai_testbench --headless --output results.json
```

**Time extraction benchmark** (single model):
```bash
./build/linux/x64/release/bundle/ai_testbench --headless-time --model Qwen3.5-2B-Q4_K_M.gguf
```

**Correction benchmark**:
```bash
./build/linux/x64/release/bundle/ai_testbench --headless-correction --model-dir models/ --output correction.json
```

**Timer/alarm benchmark** (uses extended 5-intent prompt with timer/alarm cases):
```bash
./build/linux/x64/release/bundle/ai_testbench --headless-timer --model Qwen3.5-2B-Q4_K_M.gguf
```

### CLI Options

| Flag | Description |
|------|-------------|
| `--headless` | Run structured extraction benchmark (all models) |
| `--headless-time` | Run time extraction benchmark |
| `--headless-timer` | Run timer/alarm benchmark (5-intent prompt, timer/alarm cases only) |
| `--prompt-timer` | Use the 5-intent prompt (with `--headless` to run all cases for regression testing) |
| `--headless-correction` | Run correction benchmark |
| `--model <name>` | Filter to a specific model filename |
| `--model-dir <path>` | Path to directory containing `.gguf` files (default: `models/`) |
| `--output <path>` | Write JSON results to file |
| `--language-hint` | Include language hint in time extraction prompts |
| `--retry-invalid` | Retry on invalid JSON output |
| `--prompt-variant <full\|medium\|short>` | Select prompt template variant |

## Key Dependencies

- **[fllama](https://pub.dev/packages/fllama)** — Flutter bindings for llama.cpp (model inference)
- **chrono_ai_flow** — Shared prompt templates and JSON schema for voice memo classification (local package in `../packages/chrono_ai_flow`)
- **chrono_dart** — Natural language time expression parsing

## Adding New Test Cases

Benchmark cases are defined directly in the service files:
- `lib/services/model_benchmark_service.dart` — structured extraction cases
- `lib/services/correction_benchmark_service.dart` — correction cases
- `lib/services/time_extraction_benchmark_service.dart` — time extraction cases

Each case specifies input transcript, expected intent, expected outputs, and validation criteria.
