#!/usr/bin/env python3
import json

with open('/Users/jakkra/Documents/ZSWatch-App/ai_testbench/benchmark_results/results.json') as f:
    data = json.load(f)

for model in data['results']:
    print(f"Model: {model['modelName']}")
    print(f"  Passed: {model['passedCases']}/{model['totalCases']}")
    print(f"  Avg tok/s: {model['avgTokensPerSecond']:.1f}")
    print(f"  Total time: {model['totalElapsedMs']/1000:.1f}s")
    print()
    for c in model['cases']:
        status = 'PASS' if c['passed'] else 'FAIL'
        extracted = c.get('extractedCount', 1)
        expected = c.get('expectedCount', 1)
        checks = []
        if not c.get('validJson'): checks.append('json')
        if not c.get('intentMatch'): checks.append('intent')
        if not c.get('timePresenceMatch'): checks.append('timePresence')
        if not c.get('titleLanguageMatch'): checks.append('titleLang')
        if not c.get('timeResolutionCorrect'): checks.append('timeResolve')
        if not c.get('countMatch'): checks.append('count')
        fail_str = ' FAILED:[' + ','.join(checks) + ']' if checks else ''
        print(f'  [{status}] {c["caseName"]}: intent={c.get("intent","?")} count={extracted}/{expected} ({c["elapsedMs"]/1000:.1f}s {c.get("tokensPerSecond",0):.1f}tok/s){fail_str}')
        for f in c.get('itemFailures', []):
            print(f'         ! {f}')
        if not c['passed']:
            preview = c.get('outputPreview', '')[:250]
            print(f'         output: {preview}')
