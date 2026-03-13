#!/usr/bin/env python3
"""Python wrapper to run ai_testbench headless benchmark and capture output."""

import subprocess
import sys
import json
import os

APP_PATH = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "build", "macos", "Build", "Products", "Release",
    "ai_testbench.app", "Contents", "MacOS", "ai_testbench",
)

MODEL_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "models")
OUTPUT_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "benchmark_results", "results.json")


def main():
    os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)

    cmd = [
        APP_PATH,
        "--headless",
        "--model-dir", MODEL_DIR,
        "--output", OUTPUT_FILE,
    ]

    print(f"Running: {' '.join(cmd)}")
    print(f"Model dir: {MODEL_DIR}")
    print(f"Output: {OUTPUT_FILE}")
    print("-" * 60)

    proc = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    )

    full_output = []
    for line in proc.stdout:
        line = line.rstrip("\n")
        full_output.append(line)
        print(line)

    proc.wait()
    print("-" * 60)
    print(f"Exit code: {proc.returncode}")

    # Try to load and pretty-print results
    if os.path.exists(OUTPUT_FILE):
        with open(OUTPUT_FILE) as f:
            results = json.load(f)

        print("\n" + "=" * 60)
        print("BENCHMARK RESULTS SUMMARY")
        print("=" * 60)

        for model_result in results.get("results", []):
            model_name = model_result.get("modelName", "unknown")
            passed = model_result.get("passedCases", 0)
            total = model_result.get("totalCases", 0)
            avg_tok = model_result.get("avgTokensPerSecond", 0)
            total_ms = model_result.get("totalElapsedMs", 0)

            print(f"\nModel: {model_name}")
            print(f"  Passed: {passed}/{total}")
            print(f"  Avg tok/s: {avg_tok:.1f}")
            print(f"  Total time: {total_ms / 1000:.1f}s")
            print()

            for case in model_result.get("cases", []):
                status = "PASS" if case.get("passed") else "FAIL"
                name = case.get("caseName", "?")
                intent = case.get("intent", "?")
                extracted = case.get("extractedCount", 1)
                expected = case.get("expectedCount", 1)
                elapsed_s = case.get("elapsedMs", 0) / 1000

                checks = []
                if not case.get("validJson"): checks.append("json")
                if not case.get("intentMatch"): checks.append("intent")
                if not case.get("timePresenceMatch"): checks.append("time")
                if not case.get("titleLanguageMatch"): checks.append("lang")
                if not case.get("timeResolutionCorrect"): checks.append("resolve")
                if not case.get("countMatch"): checks.append("count")

                failures = case.get("itemFailures", [])
                fail_str = f" [{', '.join(checks)}]" if checks else ""

                print(f"  [{status}] {name}: intent={intent} "
                      f"count={extracted}/{expected} "
                      f"({elapsed_s:.1f}s){fail_str}")

                for f in failures:
                    print(f"         ⚠ {f}")

                if case.get("error"):
                    print(f"         ERROR: {case['error']}")
    else:
        print(f"No output file found at {OUTPUT_FILE}")

    return proc.returncode


if __name__ == "__main__":
    sys.exit(main())
