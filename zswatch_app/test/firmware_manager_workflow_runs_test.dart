import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zswatch_app/services/dfu/firmware_manager.dart';

Map<String, dynamic> workflow(
  int id,
  String branch, {
  String? conclusion = 'success',
}) => {
  'id': id,
  'head_branch': branch,
  'conclusion': conclusion,
  'status': conclusion == null ? 'in_progress' : 'completed',
  'actor': {'login': 'builder'},
  'head_sha': 'commit-$id',
  'head_commit': {'message': 'Firmware change $id'},
  'created_at': '2026-10-26T12:00:00Z',
};

Map<String, dynamic> artifact(
  int id, {
  String name = 'watchdk@1_nrf5340_cpuapp_debug',
  bool expired = false,
}) => {
  'id': id,
  'name': name,
  'size_in_bytes': 1024,
  'created_at': '2026-10-26T12:00:00Z',
  'expired': expired,
};

void main() {
  late FirmwareManager manager;
  late List<int> artifactRequests;

  setUp(() {
    manager = FirmwareManager();
    artifactRequests = [];
  });

  tearDown(() async {
    await manager.dispose();
  });

  Future<List<WorkflowRun>> fetch({
    required List<Map<String, dynamic>> runs,
    required Map<int, List<Map<String, dynamic>>> artifacts,
    List<Map<String, dynamic>> mainRuns = const [],
    int mainStatus = 200,
    int runsStatus = 200,
    int limit = 10,
    Map<int, int> artifactStatuses = const {},
    Map<String, String> workflowHeaders = const {},
    Map<int, Map<String, String>> artifactHeaders = const {},
  }) => http.runWithClient(
    () => manager.fetchWorkflowRuns(numRuns: limit),
    () => MockClient((request) async {
      final uri = request.url;
      if (uri.path.contains('/actions/workflows/')) {
        expect(
          uri.queryParameters['status'],
          uri.queryParameters['branch'] == 'main' ? 'success' : 'completed',
        );
        expect(uri.path, endsWith('/runs'));
        expect(
          uri.path,
          contains(
            uri.queryParameters['branch'] == 'main'
                ? '/workflows/build-main.yml/'
                : '/workflows/ci.yml/',
          ),
        );
        expect(
          uri.queryParameters['per_page'],
          uri.queryParameters['branch'] == 'main' ? '10' : '50',
        );
        if (uri.queryParameters['branch'] == 'main') {
          return http.Response(
            mainStatus == 200
                ? jsonEncode({'workflow_runs': mainRuns})
                : 'Service unavailable',
            mainStatus,
            headers: workflowHeaders,
          );
        }
        return http.Response(
          jsonEncode({'workflow_runs': runs}),
          runsStatus,
          headers: workflowHeaders,
        );
      }
      final match = RegExp(
        r'/actions/runs/(\d+)/artifacts$',
      ).firstMatch(uri.path);
      if (match == null) throw StateError('Unexpected request: $uri');
      final id = int.parse(match.group(1)!);
      artifactRequests.add(id);
      expect(uri.queryParameters['per_page'], '100');
      return http.Response(
        jsonEncode({'artifacts': artifacts[id] ?? []}),
        artifactStatuses[id] ?? 200,
        headers: artifactHeaders[id] ?? const {},
      );
    }),
  );

  test(
    'excludes unfinished workflows, keeps failed and cancelled ones',
    () async {
      final runs = await fetch(
        runs: [
          workflow(3, 'feature/failed-tests', conclusion: 'failure'),
          workflow(2, 'feature/running-tests', conclusion: null),
          workflow(1, 'feature/cancelled-tests', conclusion: 'cancelled'),
          workflow(4, 'feature/success'),
        ],
        artifacts: {
          4: [artifact(40)],
          3: [artifact(30)],
          2: [artifact(20)],
          1: [artifact(10)],
        },
      );

      expect(runs.map((run) => run.id), [3, 1, 4]);
      expect(artifactRequests, [3, 1, 4]);
      expect(runs.last.commitMessage, 'Firmware change 4');
      expect(runs.last.commitSha, 'commit-4');
    },
  );

  test(
    'a newer non-firmware run does not hide firmware on its branch',
    () async {
      final runs = await fetch(
        runs: [
          workflow(4, 'feature/watch'),
          workflow(3, 'feature/watch'),
          workflow(2, 'feature/watch'),
          workflow(1, 'feature/watch'),
        ],
        artifacts: {
          4: [artifact(40, name: 'test-reports')],
          3: [artifact(30, expired: true)],
          2: [artifact(20)],
          1: [artifact(10)],
        },
      );

      expect(runs.map((run) => run.id), [2]);
      expect(artifactRequests, [4, 3, 2]);
    },
  );

  test('only branches with firmware count toward the limit', () async {
    final runs = await fetch(
      runs: [
        workflow(5, 'documentation'),
        workflow(4, 'security'),
        workflow(3, 'feature/one'),
        workflow(2, 'feature/two'),
        workflow(1, 'feature/three'),
      ],
      artifacts: {
        3: [artifact(30)],
        2: [artifact(20)],
        1: [artifact(10)],
      },
      limit: 2,
    );

    expect(runs.map((run) => run.id), [3, 2]);
    expect(artifactRequests, [5, 4, 3, 2]);
  });

  test('prioritizes main and avoids fetching the same run twice', () async {
    final main = workflow(2, 'main');
    final runs = await fetch(
      runs: [workflow(3, 'feature/watch'), main, workflow(1, 'main')],
      mainRuns: [main],
      artifacts: {
        3: [artifact(30)],
        2: [artifact(20)],
        1: [artifact(10)],
      },
    );

    expect(runs.map((run) => run.id), [2, 3]);
    expect(artifactRequests, [2, 3]);
  });

  test(
    'does not request a duplicate main run without firmware twice',
    () async {
      final main = workflow(2, 'main');
      final runs = await fetch(
        runs: [main, workflow(1, 'main')],
        mainRuns: [main],
        artifacts: {
          1: [artifact(10)],
        },
      );

      expect(runs.map((run) => run.id), [1]);
      expect(artifactRequests, [2, 1]);
    },
  );

  test(
    'reports errors from the main workflow request like the website',
    () async {
      await expectLater(
        fetch(runs: [], artifacts: {}, mainStatus: 503),
        throwsA(isA<FirmwareDownloadException>()),
      );
    },
  );

  test(
    'falls back through the main build history before feature branches',
    () async {
      final runs = await fetch(
        runs: [workflow(3, 'feature/watch')],
        mainRuns: [workflow(5, 'main'), workflow(4, 'main')],
        artifacts: {
          5: [artifact(50, expired: true)],
          4: [artifact(40)],
          3: [artifact(30)],
        },
      );
      expect(runs.map((run) => run.id), [4, 3]);
      expect(artifactRequests, [5, 4, 3]);
    },
  );

  test('excludes gh-pages and expired or unrelated artifacts', () async {
    final runs = await fetch(
      runs: [workflow(3, 'gh-pages'), workflow(2, 'feature/watch')],
      artifacts: {
        3: [artifact(30)],
        2: [
          artifact(20, expired: true),
          artifact(21, name: 'sbom'),
          artifact(23, name: 'watchdk@1_debug.zip.sha256'),
          artifact(24, name: 'WATCHDK@1_release'),
          artifact(22, name: 'zswatch@1_nrf5340_cpuapp_release'),
        ],
      },
    );

    expect(runs.single.artifacts.map((item) => item.id), [24, 22]);
    expect(artifactRequests, [2]);
  });

  test('reports errors from the primary workflow request', () async {
    await expectLater(
      fetch(runs: [], artifacts: {}, runsStatus: 403),
      throwsA(isA<FirmwareDownloadException>()),
    );
  });

  test('keeps earlier firmware when a later artifact request fails', () async {
    final runs = await fetch(
      runs: [workflow(3, 'main'), workflow(2, 'feature/one')],
      artifacts: {
        3: [artifact(30)],
      },
      artifactStatuses: {2: 503},
    );
    expect(runs.map((run) => run.id), [3]);
    expect(artifactRequests, [3, 2]);
  });

  test('reports artifact failures when no firmware was collected', () async {
    await expectLater(
      fetch(
        runs: [workflow(1, 'main')],
        artifacts: {},
        artifactStatuses: {1: 403},
      ),
      throwsA(isA<FirmwareDownloadException>()),
    );
  });

  test('stops at the reported quota and keeps collected firmware', () async {
    final runs = await fetch(
      runs: [workflow(2, 'main'), workflow(1, 'feature/one')],
      artifacts: {
        2: [artifact(20)],
        1: [artifact(10)],
      },
      workflowHeaders: {'x-ratelimit-remaining': '1'},
      artifactHeaders: {
        2: {'x-ratelimit-remaining': '0'},
      },
    );
    expect(runs.map((run) => run.id), [2]);
    expect(artifactRequests, [2]);
  });

  test('reports exhausted quota without issuing artifact requests', () async {
    await expectLater(
      fetch(
        runs: [workflow(1, 'main')],
        artifacts: {},
        workflowHeaders: {'x-ratelimit-remaining': '0'},
      ),
      throwsA(isA<FirmwareDownloadException>()),
    );
    expect(artifactRequests, isEmpty);
  });

  test(
    'does not cap candidates before reaching firmware-bearing runs',
    () async {
      final runs = await fetch(
        runs: [for (var id = 20; id >= 1; id--) workflow(id, 'branch/$id')],
        artifacts: {
          1: [artifact(10)],
        },
        limit: 1,
      );
      expect(runs.single.id, 1);
      expect(artifactRequests.length, 20);
    },
  );

  test('refresh reuses artifact lookups even with exhausted quota', () async {
    final source = [workflow(2, 'main'), workflow(1, 'feature/one')];
    final artifacts = {
      2: [artifact(20)],
      1: [artifact(10)],
    };
    await fetch(runs: source, artifacts: artifacts);
    artifactRequests.clear();
    final refreshed = await fetch(
      runs: source,
      artifacts: artifacts,
      workflowHeaders: {'x-ratelimit-remaining': '0'},
    );
    expect(refreshed.map((run) => run.id), [2, 1]);
    expect(artifactRequests, isEmpty);
  });
}
