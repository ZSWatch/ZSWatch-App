import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../data/models/coredump_analysis.dart';
import '../../data/models/crash_summary.dart';

/// Service for communicating with the ZSWatch backend coredump API.
///
/// Endpoints:
/// - POST /api/coredump/analyze  — analyze a coredump.txt with the matching ELF
class CoredumpApiService {
  static const String _defaultBaseUrl =
      'https://zswatch-production.up.railway.app';
  static const Duration _analyzeTimeout = Duration(seconds: 60);

  final String baseUrl;

  CoredumpApiService({this.baseUrl = _defaultBaseUrl});

  /// Analyze a coredump by uploading its text content to the backend.
  ///
  /// [coredumpTxt] — raw contents of /user/coredump.txt from the watch
  /// [summary] — crash summary with FW version, commit SHA, etc.
  Future<CoredumpAnalysis> analyze({
    required String coredumpTxt,
    required CrashSummary summary,
    String? elfHash,
    bool useLatestElf = false,
  }) async {
    final uri = Uri.parse('$baseUrl/api/coredump/analyze');

    final body = jsonEncode({
      'coredump_txt': coredumpTxt,
      'fw_commit_sha': summary.fwCommitSha,
      if (elfHash != null) 'elf_hash': elfHash,
      'use_latest_elf': useLatestElf,
      'fw_version': summary.fwVersion,
      'board': summary.board,
      'build_type': summary.buildType,
      'crash_file': summary.file,
      'crash_line': summary.line,
      'crash_time': summary.time,
    });

    debugPrint('[CoredumpApiService] POST $uri');
    debugPrint(
      '[CoredumpApiService] commit=${summary.fwCommitSha}, '
      'version=${summary.fwVersion}, elfHash=$elfHash, '
      'useLatest=$useLatestElf, coredump=${coredumpTxt.length} chars',
    );

    final stopwatch = Stopwatch()..start();
    final http.Response response;
    try {
      response = await http
          .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(_analyzeTimeout);
    } on TimeoutException {
      debugPrint(
        '[CoredumpApiService] TIMEOUT after ${stopwatch.elapsedMilliseconds}ms',
      );
      return const CoredumpAnalysis(
        success: false,
        error:
            'Server did not respond within 60s. '
            'It may be trying to fetch the ELF from GitHub releases.',
      );
    } on SocketException catch (e) {
      debugPrint('[CoredumpApiService] SocketException: $e');
      return CoredumpAnalysis(
        success: false,
        error: 'Could not reach coredump server at $baseUrl',
      );
    } on Exception catch (e) {
      debugPrint('[CoredumpApiService] Exception: $e');
      return CoredumpAnalysis(
        success: false,
        error: 'Connection failed: ${e.runtimeType}: $e',
      );
    }

    debugPrint(
      '[CoredumpApiService] Response ${response.statusCode} '
      'in ${stopwatch.elapsedMilliseconds}ms',
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final result = CoredumpAnalysis.fromJson(json);
      debugPrint(
        '[CoredumpApiService] success=${result.success}, '
        'elfAvailable=${result.elfAvailable}, elfHash=${result.elfHash}',
      );
      return result;
    } else {
      debugPrint(
        '[CoredumpApiService] Error ${response.statusCode}: ${response.body}',
      );
      return CoredumpAnalysis(
        success: false,
        error: 'Server error ${response.statusCode}: ${response.reasonPhrase}',
      );
    }
  }
}
