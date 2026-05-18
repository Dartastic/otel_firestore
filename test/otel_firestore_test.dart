// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_firestore/otel_firestore.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_firestore-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('doc get records CLIENT span with db.* attrs', () async {
    await tracedFirestoreDoc<String>(
      operation: 'get',
      collection: 'users',
      documentId: 'u-1',
      project: 'my-proj',
      invoke: () async => 'ok',
    );
    final span = spans.findSpanByName('firestore get users');
    expect(span, isNotNull);
    expect(span!.kind, SpanKind.client);
    final a = attrsOf(span);
    expect(a['db.system'], 'firestore');
    expect(a['db.operation'], 'get');
    expect(a['db.collection.name'], 'users');
    expect(a['firestore.document.id'], 'u-1');
    expect(a['gcp.project_id'], 'my-proj');
  });

  test('query records documents.count', () async {
    await tracedFirestoreQuery<List<String>>(
      collection: 'orders',
      invoke: () async => ['o-1', 'o-2', 'o-3'],
      documentCountOf: (v) => v.length,
    );
    final a = attrsOf(spans.findSpanByName('firestore query orders')!);
    expect(a['db.operation'], 'query');
    expect(a['firestore.documents.count'], 3);
  });

  test('transaction records INTERNAL span with retry count', () async {
    await tracedFirestoreTransaction<String>(
      retryCount: 2,
      invoke: () async => 'done',
    );
    final span = spans.findSpanByName('firestore transaction');
    expect(span, isNotNull);
    expect(span!.kind, SpanKind.internal);
    final a = attrsOf(span);
    expect(a['db.operation'], 'transaction');
    expect(a['firestore.transaction.retry_count'], 2);
  });

  test('records exception', () async {
    await expectLater(
      tracedFirestoreDoc<String>(
        operation: 'get',
        collection: 'c',
        documentId: 'd',
        invoke: () async => throw StateError('boom'),
      ),
      throwsA(isA<StateError>()),
    );
    expect(
      spans.findSpanByName('firestore get c')!.status,
      SpanStatusCode.Error,
    );
  });

  test('suppression skips spans', () async {
    await runWithoutFirestoreInstrumentationAsync(() async {
      await tracedFirestoreDoc<String>(
        operation: 'get',
        collection: 'c',
        documentId: 'd',
        invoke: () async => 'ok',
      );
    });
    expect(spans.findSpansStartingWith('firestore '), isEmpty);
  });
}
