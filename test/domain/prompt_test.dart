import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('versioned instructions preserve safety and evidence boundaries', () {
    final prompt = File('assets/appraisal_system_v1.txt').readAsStringSync();
    for (final requirement in [
      'worthit.v1',
      'untrusted',
      'pornography',
      'confidential',
      'insufficient_evidence',
      'asking',
      'inflation',
      'exchange',
      'sentimental',
      'urgency',
      'nationality',
      'Never invent',
      'JSON',
    ]) {
      expect(prompt, contains(requirement), reason: requirement);
    }
  });
}
