import '../../data/models/companion_shell_result.dart';

/// Executes shell commands through the native companion owner.
class ShellService {
  final Future<CompanionShellResult> Function(String) _execute;
  bool _disposed = false;
  ShellService({
    required Future<CompanionShellResult> Function(String) nativeExecute,
  }) : _execute = nativeExecute;

  Future<CompanionShellResult> execute(String command) async {
    if (_disposed) throw StateError('Shell service disposed');
    return _execute(command);
  }

  void dispose() {
    _disposed = true;
  }
}
