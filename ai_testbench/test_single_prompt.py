#!/usr/bin/env python3
"""Quick test: run a single transcript through the model and print the raw output."""
import subprocess, os, sys, json

APP = os.path.join(os.path.dirname(os.path.abspath(__file__)),
    "build/macos/Build/Products/Release/ai_testbench.app/Contents/MacOS/ai_testbench")

# The transcript to test - pass as arg or use default
transcript = sys.argv[1] if len(sys.argv) > 1 else \
    "Vi ska cleana upp klockans kod för voice memons sen ska vi testa att det går avbryta en calender tilläggning genom att klicka cancel på popup på klockan"

MODEL = os.path.join(os.path.dirname(os.path.abspath(__file__)), "models/Qwen3.5-2B-Q4_K_M.gguf")
OUTPUT = "/tmp/single_test_result.json"

cmd = [APP, "--headless", "--model-dir", os.path.dirname(MODEL), "--output", OUTPUT]
print(f"Transcript: {transcript}")
print(f"Running benchmark (all cases)...")
print("(We'll grep the output for our specific case)")
print("-" * 60)

proc = subprocess.run(cmd, capture_output=True, text=True, timeout=1200)

# Read results
if os.path.exists(OUTPUT):
    with open(OUTPUT) as f:
        data = json.load(f)
    # Print summary for all cases
    for model in data.get('results', []):
        print(f"Model: {model['modelName']} — {model['passedCases']}/{model['totalCases']} passed")
        for c in model['cases']:
            s = 'PASS' if c['passed'] else 'FAIL'
            cnt = f"{c.get('extractedCount',1)}/{c.get('expectedCount',1)}"
            fails = []
            for f_item in c.get('itemFailures', []):
                fails.append(f_item)
            fail_str = f"  [{', '.join(fails)}]" if fails else ""
            print(f"  [{s}] {c['caseName']} cnt={cnt}{fail_str}")
            if 'swenglish' in c['caseName'] or 'casual_planning' in c['caseName'] or 'swenglish_long' in c['caseName']:
                print(f"       OUTPUT: {c.get('outputPreview','')}")
else:
    print("No output file found")
    print("STDOUT:", proc.stdout[-2000:] if proc.stdout else "")
    print("STDERR:", proc.stderr[-2000:] if proc.stderr else "")
