import 'package:flutter/material.dart';

import '../features/scanner/pages/scanner_home_page.dart';
import 'app_theme.dart';

class BHiveScannerApp extends StatelessWidget {
  const BHiveScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BHive Scanner',
      theme: AppTheme.lightTheme,
      home: const ScannerHomePage(),
    );
  }
}
