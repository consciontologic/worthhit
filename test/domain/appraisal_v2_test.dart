import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:worthhit/domain/appraisal.dart';

Map<String, dynamic> estimatedResponse({String status = 'estimated'}) => {
  'version': 'worthit.v2',
  'status': status,
  'reason': 'Approximate value from general product knowledge.',
  'currency': 'USD',
  'item_summary': 'Test camera in good condition.',
  'comparables': <Object>[],
  'factors': ['Condition is an assumption.'],
  'cautions': <String>[],
  'questions': <String>[],
  'estimate': {
    'reference_amount': 200,
    'condition_adjustment_percent': -20,
    'uncertainty_percent': 25,
    'rationale': 'A model estimate for a comparable working unit, without verified recent sales.',
  },
};

void main() {
  final input = AppraisalInput(
    product: 'Test camera',
    currency: 'USD',
    condition: 'Good',
    details: 'A gift; no packaging.',
    asOf: DateTime.utc(2026, 10, 21),
  );
  AppraisalResult parse(Map<String, dynamic> response) =>
      parseAppraisal(jsonEncode(response), input: input);

  test('three essential fields are sufficient and optional notes survive', () {
    expect(input.validate(), isNull);
    expect(input.location, isEmpty);
    expect(input.evidence, isEmpty);
    expect(
      AppraisalInput.fromJson(input.toJson()).details,
      'A gift; no packaging.',
    );
    expect(buildUserPrompt(input), contains('worthit.v2'));
  });

  test(
    'v2 model estimate computes bounded arithmetic without fabricated evidence',
    () {
      final result = parse(estimatedResponse());
      expect(result.status, AppraisalStatus.estimated);
      expect(result.isEstimate, isTrue);
      expect(result.low, 120);
      expect(result.median, 160);
      expect(result.high, 200);
      expect(result.comparables, isEmpty);
      expect(result.estimate?.referenceAmount, 200);
      expect(
        result.cautions,
        contains(
          'This is a model-based estimate, not verified against current sales.',
        ),
      );
      expect(result.questions, isEmpty);
    },
  );

  test('model estimates round to two significant digits instead of false precision', () {
    final value = estimatedResponse();
    value['estimate']['reference_amount'] = 173.41;
    value['estimate']['condition_adjustment_percent'] = -13;
    final result = parse(value);
    expect(result.median, 150);
    expect(result.low, 110);
    expect(result.high, 190);
  });

  test(
    'estimated report round-trips with recomputed arithmetic and provenance',
    () {
      final result = parse(estimatedResponse());
      final saved = result.toJson();
      expect(saved['version'], 'worthit.v2');
      expect(AppraisalResult.fromJson(saved).toJson(), saved);
      expect(
        () => AppraisalResult.fromJson({...saved, 'median': 161}),
        throwsFormatException,
      );
      expect(
        () => AppraisalResult.fromJson({...saved, 'status': 'ready'}),
        throwsFormatException,
      );
    },
  );

  test('estimate arithmetic rejects underflow and overflow', () {
    for (final assumptions in [
      {'reference_amount': 5e-324, 'condition_adjustment_percent': -99},
      {'reference_amount': 1e12, 'condition_adjustment_percent': 100},
    ]) {
      final value = estimatedResponse();
      value['estimate'] = {
        ...value['estimate'] as Map<String, dynamic>,
        ...assumptions,
      };
      expect(() => parse(value), throwsFormatException);
    }
    final nearLimit = estimatedResponse();
    nearLimit['estimate']['reference_amount'] = 9.99e11;
    final result = parse(nearLimit);
    expect(result.high, lessThanOrEqualTo(1e12));
    expect(result.low, greaterThan(0));
  });

  test(
    'all model estimate fields are strict, finite and realistically uncertain',
    () {
      for (final invalid in <Map<String, dynamic>>[
        {'reference_amount': -1},
        {'reference_amount': 1e13},
        {'condition_adjustment_percent': -101},
        {'condition_adjustment_percent': -100},
        {'condition_adjustment_percent': 101},
        {'uncertainty_percent': 0},
        {'uncertainty_percent': 19},
        {'uncertainty_percent': 81},
        {'extra_price': 100},
      ]) {
        final value = estimatedResponse();
        value['estimate'] = {
          ...value['estimate'] as Map<String, dynamic>,
          ...invalid,
        };
        expect(() => parse(value), throwsFormatException, reason: '$invalid');
      }
      for (final value in [
        {...estimatedResponse(), 'estimate': null},
        {...estimatedResponse(), 'currency': null},
        {...estimatedResponse(), 'currency': 'EUR'},
        {...estimatedResponse(), 'low': 50},
        {...estimatedResponse()}..remove('estimate'),
      ]) {
        expect(() => parse(value), throwsFormatException);
      }
    },
  );

  test(
    'no defensible estimate abstains without requesting manual evidence',
    () {
      final result = parse({
        ...estimatedResponse(status: 'insufficient_evidence'),
        'estimate': null,
      });
      expect(result.status, AppraisalStatus.insufficientEvidence);
      expect(result.low, isNull);
      expect(result.median, isNull);
      expect(result.high, isNull);
      expect(result.questions, isEmpty);
    },
  );

  test('blocked and needs-details cannot smuggle a numeric estimate', () {
    for (final status in [
      'blocked',
      'needs_details',
      'insufficient_evidence',
    ]) {
      expect(
        () => parse(estimatedResponse(status: status)),
        throwsFormatException,
      );
    }
    final blocked = parseAppraisal(
      jsonEncode(estimatedResponse()),
      input: input.copyWith(product: 'stolen camera'),
    );
    expect(blocked.status, AppraisalStatus.blocked);
    expect(blocked.median, isNull);
  });

  test('v1 cannot opt into estimate fields or new estimated status', () {
    expect(
      () => parse({...estimatedResponse(), 'version': 'worthit.v1'}),
      throwsFormatException,
    );
    expect(
      () => parse(
        {...estimatedResponse(), 'version': 'worthit.v1'}..remove('estimate'),
      ),
      throwsFormatException,
    );
  });

  test('verified sale excerpts override the estimate; missing excerpts do not', () {
    final rows = [
      for (final price in [100, 120, 140])
        {
          'url': 'https://example.com/sold/$price',
          'title': 'Test camera',
          'kind': 'sold',
          'amount': price,
          'currency': 'USD',
          'event_date': '2026-10-01',
          'condition': 'Good',
          'match': 'exact',
          'price_basis': 'item_only',
          'support_quote':
              'Test camera, Good condition. Sold for USD $price on 2026-10-01.',
        },
    ];
    final response = jsonEncode({
      ...estimatedResponse(status: 'ready'),
      'comparables': rows,
    });
    final sources = {
      for (final row in rows)
        row['url'] as String: row['support_quote'] as String,
    };
    final grounded = parseAppraisal(response, input: input, citations: sources);
    expect(grounded.status, AppraisalStatus.ready);
    expect(grounded.estimate, isNull);
    expect([grounded.low, grounded.median, grounded.high], [100, 120, 140]);
    expect(
      AppraisalResult.fromJson(grounded.toJson()).toJson(),
      grounded.toJson(),
    );

    final urlOnly = parseAppraisal(
      response,
      input: input,
      citedUrls: sources.keys.toSet(),
    );
    expect(urlOnly.status, AppraisalStatus.estimated);
    expect(urlOnly.comparables, isEmpty);
    expect(urlOnly.median, 160);
    expect(urlOnly.rejectedReasons, hasLength(3));

    final snippets = sources.entries
        .map((entry) => '${entry.key}\n${entry.value}')
        .join('\n\n');
    final hiddenLegacy = parseAppraisal(
      response,
      input: input.copyWith(evidence: snippets),
    );
    expect(hiddenLegacy.status, AppraisalStatus.estimated);
    expect(hiddenLegacy.comparables, isEmpty);
    final visibleNotes = parseAppraisal(
      response,
      input: input.copyWith(details: snippets),
    );
    expect(visibleNotes.status, AppraisalStatus.ready);
    expect(visibleNotes.cautions.join(' '), contains('user-supplied evidence'));
  });

  test(
    'v2 output schema declares every estimate field and no direct range',
    () {
      final schema = appraisalSchema();
      final properties = schema['properties'] as Map<String, dynamic>;
      expect(properties['version']['enum'], ['worthit.v2']);
      expect(properties['status']['enum'], contains('estimated'));
      expect(properties.keys, isNot(contains('low')));
      final estimate = properties['estimate'] as Map<String, dynamic>;
      expect(estimate['additionalProperties'], isFalse);
      expect(
        estimate['required'].toSet(),
        (estimate['properties'] as Map).keys.toSet(),
      );
    },
  );
}
