import 'package:flutter/material.dart';
import 'companion_scan_view.dart';

/// Discovery and connection use the platform companion.
class ScanScreen extends StatelessWidget {
  const ScanScreen({super.key});
  @override
  Widget build(BuildContext context) => const CompanionScanView();
}
