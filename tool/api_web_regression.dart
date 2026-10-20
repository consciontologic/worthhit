// Compile with dart2js and run with Node through tool/test_api_web.py.
// This imports the production parser: a rewritten copy could conceal runtime
// differences between the Dart VM's int/double types and JavaScript numbers.
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:worthhit/api/open_router_client.dart';

const successMarker = 'PASS: production API pricing on Dart JavaScript';

Future<void> main() async {
  final rejected = [
    '1e-999',
    '0',
    '0.0',
    '-0',
    '-0.0',
    '-1e-999',
    '0e999',
    '1',
    '0.00000000000000001',
    '"1e-999"',
    'null',
    'false',
  ];
  for (final literal in rejected) {
    final client = OpenRouterClient();
    try {
      client.seedCatalog(_cache(_model(literal)));
      throw StateError('Unsafe pricing admitted by cached catalogue: $literal');
    } on ApiFailure catch (failure) {
      _check(failure.kind == ApiFailureKind.schema, 'Unexpected cache failure');
      _check(client.snapshot == null, 'Rejected cache changed client state');
    } finally {
      client.dispose();
    }
  }
  for (final literal in ['"0"', '"0.000"', '"0e-999"']) {
    final client = OpenRouterClient();
    try {
      client.seedCatalog(_cache(_model(literal)));
      _check(client.snapshot?.models.length == 1, 'Exact zero string rejected');
      _check(
        client.snapshot!.isStale,
        'Cache incorrectly authorizes inference',
      );
    } finally {
      client.dispose();
    }
  }

  // Mixed catalogue verifies quarantine rather than whole-refresh failure.
  // Each numeric record has a unique ID to avoid duplicate filtering masking
  // the pricing bug. The one admitted control uses provider-style strings.
  final rows = [
    _model('"0"', id: 'vendor/control'),
    for (var index = 0; index < rejected.length; index++)
      _model(rejected[index], id: 'vendor/rejected-$index'),
  ];
  final client = OpenRouterClient(
    clientFactory: () => MockClient(
      (_) async => http.Response('{"data":[${rows.join(',')}]}', 200),
    ),
  );
  try {
    final snapshot = await client.refreshCatalog();
    _check(
      snapshot.models.length == 1,
      'Numeric price admitted during refresh',
    );
    _check(
      snapshot.models.single.id == 'vendor/control',
      'Wrong model admitted',
    );
    _check(!snapshot.isStale, 'Valid fresh control was marked stale');
  } finally {
    client.dispose();
  }

  // Future fee fields are equally strict: numeric zero must not permit
  // underflow to bypass unknown-fee admission.
  final futureFee = OpenRouterClient();
  try {
    final row = _model(
      '"0"',
    ).replaceFirst('"completion":"0"', '"completion":"0","future_fee":1e-999');
    futureFee.seedCatalog(_cache(row));
    throw StateError('Numeric underflow in future fee admitted');
  } on ApiFailure catch (failure) {
    _check(failure.kind == ApiFailureKind.schema, 'Unexpected fee failure');
  } finally {
    futureFee.dispose();
  }
  // CLI test completion marker; this file is not shipped in the application.
  // ignore: avoid_print
  print(successMarker);
}

void _check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

String _cache(String row) =>
    jsonEncode({'version': 1, 'fetchedAt': '2026-01-01T00:00:00Z'})
        .replaceFirst('}', ',"data":[$row]}');

String _model(String price, {String id = 'vendor/probe'}) =>
    '{"id":"$id","name":"Regression fixture","context_length":8192,'
    '"architecture":{"input_modalities":["text"],"output_modalities":["text"]},'
    '"pricing":{"prompt":$price,"completion":"0"}}';
