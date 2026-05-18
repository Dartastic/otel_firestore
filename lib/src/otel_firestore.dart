// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_firestore_suppression.dart';

const _tracerName = 'dartastic_otel_libs_firestore';
const _systemValue = 'firestore';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

/// Wraps a Firestore document operation (get/set/update/delete) in
/// a CLIENT span using OTel db.* semconv.
Future<T> tracedFirestoreDoc<T>({
  required String operation,
  required String collection,
  required String documentId,
  required Future<T> Function() invoke,
  String? project,
}) async {
  if (firestoreInstrumentationSuppressed()) {
    return invoke();
  }
  final m = <String, Object>{
    'db.system': _systemValue,
    'db.operation': operation,
    'db.collection.name': collection,
    'firestore.document.id': documentId,
  };
  if (project != null) m['gcp.project_id'] = project;

  final span = _tracer().startSpan(
    'firestore $operation $collection',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    return await invoke();
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}

/// Wraps a Firestore query (`Query.get` / `Query.where`) in a CLIENT
/// span, recording the returned document count on success.
Future<T> tracedFirestoreQuery<T>({
  required String collection,
  required Future<T> Function() invoke,
  String? project,
  int Function(T value)? documentCountOf,
}) async {
  if (firestoreInstrumentationSuppressed()) {
    return invoke();
  }
  final m = <String, Object>{
    'db.system': _systemValue,
    'db.operation': 'query',
    'db.collection.name': collection,
  };
  if (project != null) m['gcp.project_id'] = project;

  final span = _tracer().startSpan(
    'firestore query $collection',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final v = await invoke();
    if (documentCountOf != null) {
      span.addAttributes(OTel.attributes([
        OTel.attributeInt(
          'firestore.documents.count',
          documentCountOf(v),
        ),
      ]));
    }
    return v;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}

/// Wraps a Firestore transaction body in an INTERNAL span. Set
/// [retryCount] from your retry loop so each attempt is visible.
Future<T> tracedFirestoreTransaction<T>({
  required Future<T> Function() invoke,
  int? retryCount,
  String? project,
}) async {
  if (firestoreInstrumentationSuppressed()) {
    return invoke();
  }
  final m = <String, Object>{
    'db.system': _systemValue,
    'db.operation': 'transaction',
  };
  if (retryCount != null) m['firestore.transaction.retry_count'] = retryCount;
  if (project != null) m['gcp.project_id'] = project;

  final span = _tracer().startSpan(
    'firestore transaction',
    kind: SpanKind.internal,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    return await invoke();
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
