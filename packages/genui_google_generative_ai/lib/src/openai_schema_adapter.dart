// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:json_schema_builder/json_schema_builder.dart' as dsb;

/// An error that occurred during schema adaptation.
class OpenAiSchemaAdapterError {
  /// Creates an [OpenAiSchemaAdapterError].
  OpenAiSchemaAdapterError(this.message, {required this.path});

  /// A message describing the error.
  final String message;

  /// The path to the location in the schema where the error occurred.
  final List<String> path;

  @override
  String toString() => 'Error at path "${path.join('/')}": $message';
}

/// The result of a schema adaptation.
class OpenAiSchemaAdapterResult {
  /// Creates an [OpenAiSchemaAdapterResult].
  OpenAiSchemaAdapterResult(this.schema, this.errors);

  /// The adapted JSON schema as a map, suitable for OpenAI tool parameters.
  final Map<String, dynamic>? schema;

  /// A list of errors that occurred during adaptation.
  final List<OpenAiSchemaAdapterError> errors;
}

/// An adapter to convert a [dsb.Schema] from the `json_schema_builder` package
/// to a [Map<String, dynamic>] suitable for OpenAI tool parameters.
///
/// OpenAI accepts standard JSON Schema, so this adapter is largely a
/// pass-through. It validates the schema structure and reports any issues
/// that could cause problems with the OpenAI API.
class OpenAiSchemaAdapter {
  final List<OpenAiSchemaAdapterError> _errors = [];

  /// Adapts the given [schema] from `json_schema_builder` to a JSON schema map.
  OpenAiSchemaAdapterResult adapt(dsb.Schema schema) {
    _errors.clear();
    final jsonSchema = _adapt(schema, ['#']);
    return OpenAiSchemaAdapterResult(jsonSchema, List.unmodifiable(_errors));
  }

  Map<String, dynamic>? _adapt(dsb.Schema schema, List<String> path) {
    final value = schema.value;
    if (value.isEmpty) {
      _errors.add(
        OpenAiSchemaAdapterError('Schema is empty.', path: path),
      );
      return null;
    }

    final type = schema.type;
    String? typeName;
    if (type is String) {
      typeName = type;
    } else if (type is List) {
      if (type.isEmpty) {
        _errors.add(
          OpenAiSchemaAdapterError(
            'Schema has an empty "type" array.',
            path: path,
          ),
        );
        return null;
      }
      typeName = type.first as String;
    } else if (value.containsKey('properties')) {
      typeName = 'object';
    } else if (value.containsKey('items')) {
      typeName = 'array';
    }

    if (typeName == null) {
      _errors.add(
        OpenAiSchemaAdapterError(
          'Schema must have a "type" or be implicitly typed with "properties" '
          'or "items".',
          path: path,
        ),
      );
      return null;
    }

    // OpenAI uses standard JSON Schema — pass through the value map directly,
    // recursively converting nested schemas.
    return Map<String, dynamic>.from(value);
  }
}
