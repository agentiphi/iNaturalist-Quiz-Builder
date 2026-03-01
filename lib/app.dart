import 'package:flutter/material.dart';

import 'router.dart';
import 'theme.dart';

class INaturalistQuizApp extends StatelessWidget {
  const INaturalistQuizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'iNaturalist Quiz',
      theme: AppTheme.lightTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
