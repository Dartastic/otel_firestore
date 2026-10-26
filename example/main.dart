// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_firestore/otel_firestore.dart';

/// Traces Firestore calls with OpenTelemetry.
///
/// `otel_firestore` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Firestore call in
/// [tracedFirestoreDoc]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'firestore-example');

  // Wraps a Firestore document operation (get/set/update/delete) in a CLIENT span using OTel db.* semconv.
  final firestoreDocId = await tracedFirestoreDoc<String>(
    operation: 'create',
    collection: 'orders',
    documentId: 'document_8f3a2c',
    project: 'example',
    invoke: () async {
      // Make the Firestore call here, then report what it returned.
      return 'firestore_8f3a2c';
    },
  );
  OTelLog.info('tracedFirestoreDoc create returned $firestoreDocId');

  // Wraps a Firestore query (Query.get / Query.where) in a CLIENT span, recording the returned document count on success.
  final firestoreQueryId = await tracedFirestoreQuery<String>(
    collection: 'orders',
    project: 'example',
    invoke: () async {
      // Make the Firestore call here, then report what it returned.
      return 'firestore_8f3a2c';
    },
  );
  OTelLog.info('tracedFirestoreQuery returned $firestoreQueryId');

  // Wraps a Firestore transaction body in an INTERNAL span.
  final firestoreTransactionId = await tracedFirestoreTransaction<String>(
    retryCount: 3,
    project: 'example',
    invoke: () async {
      // Make the Firestore call here, then report what it returned.
      return 'firestore_8f3a2c';
    },
  );
  OTelLog.info('tracedFirestoreTransaction returned $firestoreTransactionId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutFirestoreInstrumentationAsync.
  await runWithoutFirestoreInstrumentationAsync(
    () => tracedFirestoreDoc<String>(
      operation: 'create',
      collection: 'orders',
      documentId: 'document_8f3a2c',
      project: 'example',
      invoke: () async {
        return 'firestore_8f3a2c';
      },
    ),
  );

  await OTel.shutdown();
}
