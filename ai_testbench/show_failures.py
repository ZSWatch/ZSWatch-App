import json
with open('benchmark_results/results.json') as f:
    data = json.load(f)
for c in data['results'][0]['cases']:
    if not c['passed']:
        fails = c.get('itemFailures', [])
        out = c.get('outputPreview','')[:200]
        print(f"FAIL: {c['caseName']}")
        print(f"  output: {out}")
        for f2 in fails:
            print(f"  - {f2}")
        print()
