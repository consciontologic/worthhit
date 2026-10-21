import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('v2 requests essentials, honest optional estimates and automatic research', () {
    final prompt = File('assets/appraisal_system_v2.txt').readAsStringSync();
    for (final requirement in [
      'worthit.v2',
      'Only the product, currency and condition are required',
      'Do not require an evidence form',
      'Never ask users to collect evidence',
      'model-based estimate',
      'reference_amount',
      'condition_adjustment_percent',
      'uncertainty_percent',
      'not a statistical confidence',
      'untrusted',
      'Never invent URLs, observed prices',
      'never evidence',
      'two significant digits',
      'Never turn uncertainty about a broken product into a certain zero price',
      'Do not infer or assign a buyer or seller role',
    ]) {
      expect(prompt, contains(requirement), reason: requirement);
    }
  });

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
