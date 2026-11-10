import 'package:flutter/material.dart';

import 'package:disaster/app.dart';
import 'package:disaster/presentation/providers/app_dependencies.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final deps = await AppDependencies.bootstrap();
  runApp(DisasterApp(deps: deps));
}
