/// Result of a coredump analysis from the backend server.
class CoredumpAnalysis {
  final bool success;
  final String? backtrace;
  final String? registers;
  final String rawOutput;
  final String? error;
  final bool elfAvailable;
  final String? elfHash;

  const CoredumpAnalysis({
    required this.success,
    this.backtrace,
    this.registers,
    this.rawOutput = '',
    this.error,
    this.elfAvailable = false,
    this.elfHash,
  });

  factory CoredumpAnalysis.fromJson(Map<String, dynamic> json) {
    return CoredumpAnalysis(
      success: json['success'] as bool? ?? false,
      backtrace: json['backtrace'] as String?,
      registers: json['registers'] as String?,
      rawOutput: json['raw_output'] as String? ?? '',
      error: json['error'] as String?,
      elfAvailable: json['elf_available'] as bool? ?? false,
      elfHash: json['elf_hash'] as String?,
    );
  }
}
