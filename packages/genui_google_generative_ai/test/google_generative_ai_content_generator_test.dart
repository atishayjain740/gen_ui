// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart' as genui;
import 'package:genui_google_generative_ai/genui_google_generative_ai.dart';
import 'package:json_schema_builder/json_schema_builder.dart' as dsb;
import 'package:openai_dart/openai_dart.dart' as openai;

void main() {
  group('OpenAiContentGenerator', () {
    test('constructor creates instance with required parameters', () {
      final catalog = const genui.Catalog(<genui.CatalogItem>[]);

      final generator = OpenAiContentGenerator(
        catalog: catalog,
        apiKey: 'test-api-key',
      );

      expect(generator, isNotNull);
      expect(generator.catalog, catalog);
      expect(generator.modelName, 'gpt-4o');
      expect(generator.outputToolName, 'provideFinalOutput');
    });

    test('constructor accepts custom model name', () {
      final catalog = const genui.Catalog(<genui.CatalogItem>[]);

      final generator = OpenAiContentGenerator(
        catalog: catalog,
        modelName: 'gpt-4.1',
        apiKey: 'test-api-key',
      );

      expect(generator.modelName, 'gpt-4.1');
    });

    test('constructor accepts custom output tool name', () {
      final catalog = const genui.Catalog(<genui.CatalogItem>[]);

      final generator = OpenAiContentGenerator(
        catalog: catalog,
        outputToolName: 'customOutput',
        apiKey: 'test-api-key',
      );

      expect(generator.outputToolName, 'customOutput');
    });

    test('constructor accepts system instruction', () {
      final catalog = const genui.Catalog(<genui.CatalogItem>[]);

      final generator = OpenAiContentGenerator(
        catalog: catalog,
        systemInstruction: 'You are a helpful assistant',
        apiKey: 'test-api-key',
      );

      expect(generator.systemInstruction, 'You are a helpful assistant');
    });

    test('constructor accepts additional tools', () {
      final catalog = const genui.Catalog(<genui.CatalogItem>[]);
      final tool = genui.DynamicAiTool<Map<String, Object?>>(
        name: 'testTool',
        description: 'A test tool',
        invokeFunction: (args) async => {},
      );

      final generator = OpenAiContentGenerator(
        catalog: catalog,
        additionalTools: [tool],
        apiKey: 'test-api-key',
      );

      expect(generator.additionalTools, hasLength(1));
      expect(generator.additionalTools.first.name, 'testTool');
    });

    test('streams are accessible', () {
      final catalog = const genui.Catalog(<genui.CatalogItem>[]);

      final generator = OpenAiContentGenerator(
        catalog: catalog,
        apiKey: 'test-api-key',
      );

      expect(generator.a2uiMessageStream, isNotNull);
      expect(generator.textResponseStream, isNotNull);
      expect(generator.errorStream, isNotNull);
      expect(generator.isProcessing, isNotNull);
    });

    test('isProcessing starts as false', () {
      final catalog = const genui.Catalog(<genui.CatalogItem>[]);

      final generator = OpenAiContentGenerator(
        catalog: catalog,
        apiKey: 'test-api-key',
      );

      expect(generator.isProcessing.value, isFalse);
    });

    test('dispose closes all streams', () {
      final catalog = const genui.Catalog(<genui.CatalogItem>[]);

      final generator = OpenAiContentGenerator(
        catalog: catalog,
        apiKey: 'test-api-key',
      );

      expect(generator.dispose, returnsNormally);
    });

    test('token usage starts at zero', () {
      final catalog = const genui.Catalog(<genui.CatalogItem>[]);

      final generator = OpenAiContentGenerator(
        catalog: catalog,
        apiKey: 'test-api-key',
      );

      expect(generator.inputTokenUsage, 0);
      expect(generator.outputTokenUsage, 0);
    });

    test('isProcessing is true during request', () async {
      final generator = OpenAiContentGenerator(
        catalog: const genui.Catalog({}),
        serviceFactory: ({required configuration}) {
          return FakeOpenAiService([
            _buildToolCallResponse(
              toolCallId: '1',
              functionName: 'provideFinalOutput',
              arguments: {'output': {'response': 'Hello'}},
            ),
          ]);
        },
      );

      expect(generator.isProcessing.value, isFalse);
      final future = generator.sendRequest(
        genui.UserMessage([const genui.TextPart('Hi')]),
      );
      expect(generator.isProcessing.value, isTrue);
      await future;
      expect(generator.isProcessing.value, isFalse);
    });

    test('can call a tool and return a result', () async {
      final generator = OpenAiContentGenerator(
        catalog: const genui.Catalog({}),
        additionalTools: [
          genui.DynamicAiTool<Map<String, Object?>>(
            name: 'testTool',
            description: 'A test tool',
            parameters: dsb.Schema.object(),
            invokeFunction: (args) async => {'result': 'tool result'},
          ),
        ],
        serviceFactory: ({required configuration}) {
          return FakeOpenAiService([
            _buildToolCallResponse(
              toolCallId: '1',
              functionName: 'testTool',
              arguments: <String, dynamic>{},
            ),
            _buildToolCallResponse(
              toolCallId: '2',
              functionName: 'provideFinalOutput',
              arguments: {'output': {'response': 'Tool called'}},
            ),
          ]);
        },
      );

      final hi = genui.UserMessage([const genui.TextPart('Hi')]);
      final completer = Completer<String>();
      unawaited(generator.textResponseStream.first.then(completer.complete));
      await generator.sendRequest(hi);
      final response = await completer.future;
      expect(response, 'Tool called');
    });

    test('returns a simple text response', () async {
      final generator = OpenAiContentGenerator(
        catalog: const genui.Catalog({}),
        serviceFactory: ({required configuration}) {
          return FakeOpenAiService([
            _buildToolCallResponse(
              toolCallId: '1',
              functionName: 'provideFinalOutput',
              arguments: {'output': {'response': 'Hello'}},
            ),
          ]);
        },
      );

      final hi = genui.UserMessage([const genui.TextPart('Hi')]);
      final completer = Completer<String>();
      unawaited(generator.textResponseStream.first.then(completer.complete));
      await generator.sendRequest(hi);
      final response = await completer.future;
      expect(response, 'Hello');
    });
  });
}

openai.ChatCompletion _buildToolCallResponse({
  required String toolCallId,
  required String functionName,
  required Map<String, dynamic> arguments,
}) {
  return openai.ChatCompletion(
    object: 'chat.completion',
    model: 'gpt-4o',
    choices: [
      openai.ChatChoice(
        message: openai.AssistantMessage(
          content: null,
          toolCalls: [
            openai.ToolCall(
              id: toolCallId,
              type: 'function',
              function: openai.FunctionCall(
                name: functionName,
                arguments: jsonEncode(arguments),
              ),
            ),
          ],
        ),
        finishReason: openai.FinishReason.toolCalls,
      ),
    ],
    usage: openai.Usage(
      promptTokens: 10,
      completionTokens: 5,
      totalTokens: 15,
    ),
  );
}

class FakeOpenAiService implements OpenAiServiceInterface {
  FakeOpenAiService(this.responses);

  final List<openai.ChatCompletion> responses;
  int callCount = 0;

  @override
  Future<openai.ChatCompletion> createChatCompletion(
    openai.ChatCompletionCreateRequest request,
  ) {
    return Future.delayed(Duration.zero, () => responses[callCount++]);
  }

  @override
  void close() {}
}
