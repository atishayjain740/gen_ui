// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:genui_google_generative_ai/genui_google_generative_ai.dart';
import 'package:openai_dart/openai_dart.dart' as openai;

void main() {
  group('OpenAiContentConverter', () {
    late OpenAiContentConverter converter;

    setUp(() {
      converter = OpenAiContentConverter();
    });

    test('toOpenAiMessages converts UserMessage with TextPart', () {
      final messages = [UserMessage.text('Hello')];
      final result = converter.toOpenAiMessages(messages);

      expect(result, hasLength(1));
      // User message with content parts
      expect(result.first, isA<openai.ChatMessage>());
    });

    test('toOpenAiMessages converts AiTextMessage with TextPart', () {
      final messages = [AiTextMessage.text('Hi there')];
      final result = converter.toOpenAiMessages(messages);

      expect(result, hasLength(1));
      expect(result.first, isA<openai.ChatMessage>());
    });

    test('toOpenAiMessages converts AiUiMessage', () {
      final definition = UiDefinition(surfaceId: 'testSurface');
      final messages = [AiUiMessage(definition: definition)];
      final result = converter.toOpenAiMessages(messages);
      expect(result, hasLength(1));
      expect(result.first, isA<openai.ChatMessage>());
    });

    test('toOpenAiMessages skips InternalMessage', () {
      final messages = [
        UserMessage.text('Hello'),
        const InternalMessage('Internal note'),
        AiTextMessage.text('Response'),
      ];
      final result = converter.toOpenAiMessages(messages);

      expect(result, hasLength(2));
    });

    test('toOpenAiMessages converts ImagePart with bytes to data URI', () {
      final imageBytes = Uint8List.fromList([1, 2, 3, 4]);
      final messages = [
        UserMessage([ImagePart.fromBytes(imageBytes, mimeType: 'image/png')]),
      ];
      final result = converter.toOpenAiMessages(messages);

      expect(result, hasLength(1));
      expect(result.first, isA<openai.ChatMessage>());
    });

    test('toOpenAiMessages converts ImagePart with URL', () {
      final messages = [
        UserMessage([
          ImagePart.fromUrl(
            Uri.parse('https://example.com/image.png'),
            mimeType: 'image/png',
          ),
        ]),
      ];
      final result = converter.toOpenAiMessages(messages);

      expect(result, hasLength(1));
      expect(result.first, isA<openai.ChatMessage>());
    });

    test('toOpenAiMessages converts ToolCallPart in assistant message', () {
      final messages = [
        AiTextMessage([
          const ToolCallPart(
            id: 'call-1',
            toolName: 'calculator',
            arguments: {'operation': 'add', 'a': 1, 'b': 2},
          ),
        ]),
      ];
      final result = converter.toOpenAiMessages(messages);

      expect(result, hasLength(1));
      expect(result.first, isA<openai.ChatMessage>());
    });

    test('toOpenAiMessages converts ToolResponseMessage', () {
      final messages = [
        ToolResponseMessage([
          ToolResultPart(
            callId: 'call-1',
            result: jsonEncode({'sum': 3}),
          ),
        ]),
      ];
      final result = converter.toOpenAiMessages(messages);

      expect(result, hasLength(1));
      expect(result.first, isA<openai.ChatMessage>());
    });
  });
}
