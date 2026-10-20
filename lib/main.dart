import 'dart:async';

import 'package:flutter/widgets.dart';

import 'app/app_controller.dart';
import 'ui/worthhit_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController();
  runApp(WorthhitApp(controller: controller));
  unawaited(controller.initialize());
}
