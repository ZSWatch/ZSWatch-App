#!/usr/bin/env python3
import json
import os

script_dir = os.path.dirname(os.path.abspath(__file__))
results_path = os.path.join(script_dir, 'benchmark_results', 'results.json')

with open(results_path) as f:
    data = json.load(f)

for model in data['results']:
    print('Model: ' + model['modelName'])
    print('Passed: ' + str(model['passedCases']) + '/' + str(model['totalCases']))
    print('')
    for c in model['cases']:
        s = 'PASS' if c['passed'] else 'FAIL'
        checks = []
        if not c.get('validJson'):
            checks.append('json')
        if not c.get('intentMatch'):
            checks.append('intent')
        if not c.get('timePresenceMatch'):
            checks.append('timePres')
        if not c.get('titleLanguageMatch'):
            checks.append('titleLang')
        if not c.get('timeResolutionCorrect'):
            checks.append('timeRes')
        if not c.get('countMatch'):
            checks.append('count')
        fails = ''
        if checks:
            fails = ' FAILED:' + ','.join(checks)
        cnt = str(c.get('extractedCount', 1)) + '/' + str(c.get('expectedCount', 1))
        print('[' + s + '] ' + c['caseName'] + ' cnt=' + cnt + fails)
        for item_f in c.get('itemFailures', []):
            print('    ! ' + item_f)
        if not c['passed']:
            preview = c.get('outputPreview', '')[:300]
            print('    output: ' + preview)
    print('')
