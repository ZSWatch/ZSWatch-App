class CompanionShellResult {
  final String output;
  final int returnCode;
  const CompanionShellResult({required this.output, required this.returnCode});

  factory CompanionShellResult.decode(Object? value, int generation) {
    if (value is! Map ||
        value['version'] != 1 ||
        value['generation'] != generation ||
        value['generation'] is! int ||
        value['output'] is! String ||
        (value['output'] as String).length > 65536 ||
        value['return_code'] is! int ||
        (value['return_code'] as int) < -2147483648 ||
        (value['return_code'] as int) > 2147483647) {
      throw const FormatException('Unsupported native shell response');
    }
    return CompanionShellResult(
      output: value['output'] as String,
      returnCode: value['return_code'] as int,
    );
  }
}
