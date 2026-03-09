// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:genui_google_generative_ai/genui_google_generative_ai.dart';
import 'package:json_schema_builder/json_schema_builder.dart' as dsb;

void main() {
  group('OpenAiSchemaAdapter', () {
    late OpenAiSchemaAdapter adapter;

    setUp(() {
      adapter = OpenAiSchemaAdapter();
    });

    test('adapt converts string schema', () {
      final schema = dsb.S.string();
      final result = adapter.adapt(schema);

      expect(result.schema, isNotNull);
      expect(result.schema!['type'], 'string');
      expect(result.errors, isEmpty);
    });

    test('adapt converts number schema', () {
      final schema = dsb.S.number();
      final result = adapter.adapt(schema);

      expect(result.schema, isNotNull);
      expect(result.schema!['type'], 'number');
      expect(result.errors, isEmpty);
    });

    test('adapt converts integer schema', () {
      final schema = dsb.S.integer();
      final result = adapter.adapt(schema);

      expect(result.schema, isNotNull);
      expect(result.schema!['type'], 'integer');
      expect(result.errors, isEmpty);
    });

    test('adapt converts boolean schema', () {
      final schema = dsb.S.boolean();
      final result = adapter.adapt(schema);

      expect(result.schema, isNotNull);
      expect(result.schema!['type'], 'boolean');
      expect(result.errors, isEmpty);
    });

    test('adapt converts object schema with properties', () {
      final schema = dsb.S.object(
        properties: {'name': dsb.S.string(), 'age': dsb.S.integer()},
        required: ['name'],
      );
      final result = adapter.adapt(schema);

      expect(result.schema, isNotNull);
      expect(result.schema!['type'], 'object');
      expect(result.schema!['properties'], isNotNull);
      final properties =
          result.schema!['properties'] as Map<String, dynamic>;
      expect(properties, hasLength(2));
      expect(result.schema!['required'], contains('name'));
      expect(result.errors, isEmpty);
    });

    test('adapt converts array schema', () {
      final schema = dsb.S.list(items: dsb.S.string());
      final result = adapter.adapt(schema);

      expect(result.schema, isNotNull);
      expect(result.schema!['type'], 'array');
      expect(result.schema!['items'], isNotNull);
      expect(result.errors, isEmpty);
    });

    test('adapt converts nested object schema', () {
      final schema = dsb.S.object(
        properties: {
          'user': dsb.S.object(
            properties: {'name': dsb.S.string(), 'email': dsb.S.string()},
          ),
        },
      );
      final result = adapter.adapt(schema);

      expect(result.schema, isNotNull);
      expect(result.schema!['type'], 'object');
      expect(result.errors, isEmpty);
    });

    test('adapt handles string with enum values', () {
      final schema = dsb.S.string(enumValues: ['red', 'green', 'blue']);
      final result = adapter.adapt(schema);

      expect(result.schema, isNotNull);
      expect(result.schema!['type'], 'string');
      expect(result.schema!['enum'], isNotNull);
      expect(result.schema!['enum'], hasLength(3));
      expect(result.schema!['enum'], containsAll(['red', 'green', 'blue']));
    });

    test('adapt handles schema with description', () {
      final schema = dsb.S.string(description: 'A test string');
      final result = adapter.adapt(schema);

      expect(result.schema, isNotNull);
      expect(result.schema!['description'], 'A test string');
    });

    test('adapt handles schema without type returns error', () {
      final schema = dsb.Schema.fromMap({'description': 'No type'});
      final result = adapter.adapt(schema);

      expect(result.schema, isNull);
      expect(result.errors, isNotEmpty);
    });

    test('adapt handles empty schema returns error', () {
      final schema = dsb.Schema.fromMap(<String, Object?>{});
      final result = adapter.adapt(schema);

      expect(result.schema, isNull);
      expect(result.errors, isNotEmpty);
    });
  });
}
