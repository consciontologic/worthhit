import 'dart:async';

import 'package:flutter/widgets.dart';

import 'app/app_controller.dart';
import 'ui/worthit_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController();
  runApp(WorthitApp(controller: controller));
  unawaited(controller.initialize());
}
