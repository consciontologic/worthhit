import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('valuation policy stays neutral and uses observable safeguards', () {
    final prompt = File('assets/appraisal_system_v1.txt').readAsStringSync();
    expect(
      prompt,
      contains('regardless of whether the person is buying or selling'),
    );
    expect(prompt, contains('Do not infer or assign a buyer or seller role'));
    expect(prompt, contains('Do not apply a sentimental premium'));
    expect(prompt, contains('inspection'));
    expect(prompt, contains('disclosure'));
    expect(prompt, contains('payment protection'));
    expect(prompt, isNot(contains('selected buy/sell goal')));
    expect(prompt, isNot(contains('For a buyer,')));
    expect(prompt, isNot(contains('For a seller,')));
  });

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
