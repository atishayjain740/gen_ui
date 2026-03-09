// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart' as dsb;
import 'package:openai_dart/openai_dart.dart' as openai;

import 'openai_content_converter.dart';
import 'openai_schema_adapter.dart';
import 'openai_service_interface.dart';

/// A factory for creating an [OpenAiServiceInterface].
///
/// This is used to allow for custom service creation, for example, for testing.
typedef OpenAiServiceFactory =
    OpenAiServiceInterface Function({
      required OpenAiContentGenerator configuration,
    });

/// A [ContentGenerator] that uses the OpenAI Chat Completions API to
/// generate content.
class OpenAiContentGenerator implements ContentGenerator {
  /// Creates an [OpenAiContentGenerator] instance with specified
  /// configurations.
  OpenAiContentGenerator({
    required this.catalog,
    this.systemInstruction,
    this.outputToolName = 'provideFinalOutput',
    this.serviceFactory = defaultServiceFactory,
    this.additionalTools = const [],
    this.modelName = 'gpt-4o',
    this.apiKey,
    this.temperature,
  });

  /// The catalog of UI components available to the AI.
  final Catalog catalog;

  /// The system instruction to use for the AI model.
  final String? systemInstruction;

  /// The name of an internal pseudo-tool used to retrieve the final structured
  /// output from the AI.
  ///
  /// This only needs to be provided in case of name collision with another
  /// tool.
  ///
  /// Defaults to 'provideFinalOutput'.
  final String outputToolName;

  /// A function to use for creating the service itself.
  ///
  /// This factory function is responsible for instantiating the
  /// [OpenAiServiceInterface] used for AI interactions. It allows for
  /// customization of the service setup, or for providing mock services during
  /// testing. The factory receives this [OpenAiContentGenerator]
  /// instance as configuration.
  ///
  /// Defaults to [defaultServiceFactory].
  final OpenAiServiceFactory serviceFactory;

  /// Additional tools to make available to the AI model.
  final List<AiTool> additionalTools;

  /// The model name to use (e.g., 'gpt-4o', 'gpt-4.1').
  final String modelName;

  /// The API key to use for authentication.
  final String? apiKey;

  /// The sampling temperature for the model (0.0 to 2.0).
  ///
  /// Higher values (e.g. 1.0) make output more creative and varied,
  /// while lower values (e.g. 0.2) make it more focused and deterministic.
  /// When null, the API uses its default.
  final double? temperature;

  /// The total number of input tokens used by this client.
  int inputTokenUsage = 0;

  /// The total number of output tokens used by this client.
  int outputTokenUsage = 0;

  final _a2uiMessageController = StreamController<A2uiMessage>.broadcast();
  final _textResponseController = StreamController<String>.broadcast();
  final _errorController = StreamController<ContentGeneratorError>.broadcast();
  final _isProcessing = ValueNotifier<bool>(false);

  @override
  Stream<A2uiMessage> get a2uiMessageStream => _a2uiMessageController.stream;

  @override
  Stream<String> get textResponseStream => _textResponseController.stream;

  @override
  Stream<ContentGeneratorError> get errorStream => _errorController.stream;

  @override
  ValueListenable<bool> get isProcessing => _isProcessing;

  @override
  void dispose() {
    _a2uiMessageController.close();
    _textResponseController.close();
    _errorController.close();
    _isProcessing.dispose();
  }

  @override
  Future<void> sendRequest(
    ChatMessage message, {
    Iterable<ChatMessage>? history,
    A2UiClientCapabilities? clientCapabilities,
  }) async {
    _isProcessing.value = true;
    try {
      final messages = [...?history, message];
      final response = await _generate(
        messages: messages,
        outputSchema: dsb.S.object(properties: {'response': dsb.S.string()}),
      );
      if (response is Map && response.containsKey('response')) {
        final responseValue = response['response'];
        final text = responseValue is String
            ? responseValue
            : (responseValue is Map
                ? (responseValue['literalString'] as String? ?? '$responseValue')
                : '$responseValue');
        _textResponseController.add(text);
      }
    } catch (e, st) {
      genUiLogger.severe('Error generating content', e, st);
      _errorController.add(ContentGeneratorError(e, st));
    } finally {
      _isProcessing.value = false;
    }
  }

  /// The default factory function for creating an [OpenAiServiceInterface].
  static OpenAiServiceInterface defaultServiceFactory({
    required OpenAiContentGenerator configuration,
  }) {
    return OpenAiServiceWrapper(
      openai.OpenAIClient(
        config: openai.OpenAIConfig(
          authProvider: openai.ApiKeyProvider(configuration.apiKey ?? ''),
        ),
      ),
    );
  }

  List<openai.Tool> _setupTools({
    required bool isForcedToolCalling,
    required List<AiTool> availableTools,
    required OpenAiSchemaAdapter adapter,
    required dsb.Schema? outputSchema,
  }) {
    genUiLogger.fine(
      'Setting up tools'
      '${isForcedToolCalling ? ' with forced tool calling' : ''}',
    );

    final finalOutputAiTool = isForcedToolCalling
        ? DynamicAiTool<Map<String, Object?>>(
            name: outputToolName,
            description:
                '''Returns the final output. Call this function when you are done with the current turn of the conversation. Do not call this if you need to use other tools first. You MUST call this tool when you are done.''',
            parameters: dsb.S.object(properties: {'output': outputSchema!}),
            invokeFunction: (args) async => args,
          )
        : null;

    final allTools = isForcedToolCalling
        ? [...availableTools, finalOutputAiTool!]
        : availableTools;
    genUiLogger.fine(
      'Available tools: ${allTools.map((t) => t.name).join(', ')}',
    );

    final uniqueAiToolsByName = <String, AiTool>{};
    for (final tool in allTools) {
      if (uniqueAiToolsByName.containsKey(tool.name)) {
        throw Exception('Duplicate tool ${tool.name} registered.');
      }
      uniqueAiToolsByName[tool.name] = tool;
    }

    final openaiTools = <openai.Tool>[];
    for (final tool in uniqueAiToolsByName.values) {
      Map<String, dynamic>? adaptedParameters;
      if (tool.parameters != null) {
        final result = adapter.adapt(tool.parameters!);
        if (result.errors.isNotEmpty) {
          genUiLogger.warning(
            'Errors adapting parameters for tool ${tool.name}: '
            '${result.errors.join('\n')}',
          );
        }
        adaptedParameters = result.schema;
      }
      openaiTools.add(
        openai.Tool.function(
          name: tool.name,
          description: tool.description,
          parameters: adaptedParameters,
        ),
      );
      if (tool.name != tool.fullName) {
        openaiTools.add(
          openai.Tool.function(
            name: tool.fullName,
            description: tool.description,
            parameters: adaptedParameters,
          ),
        );
      }
    }
    genUiLogger.fine(
      'Adapted tools: ${openaiTools.map((t) => t.function.name).join(', ')}',
    );

    return openaiTools;
  }

  Future<({List<openai.ChatMessage> toolMessages, Object? capturedResult})>
  _processFunctionCalls({
    required List<openai.ToolCall> toolCalls,
    required bool isForcedToolCalling,
    required List<AiTool> availableTools,
    Object? capturedResult,
  }) async {
    genUiLogger.fine(
      'Processing ${toolCalls.length} tool calls from model.',
    );
    final toolMessages = <openai.ChatMessage>[];
    for (final call in toolCalls) {
      final functionName = call.function.name;
      final argsJson = call.function.arguments;
      genUiLogger.fine(
        'Processing tool call: $functionName with args: $argsJson',
      );

      if (isForcedToolCalling && functionName == outputToolName) {
        try {
          final argsMap =
              jsonDecode(argsJson) as Map<String, Object?>;
          capturedResult = argsMap['output'];
          genUiLogger.fine(
            'Captured final output from tool "$outputToolName".',
          );
        } catch (exception, stack) {
          genUiLogger.severe(
            'Unable to read output: $functionName [$argsJson]',
            exception,
            stack,
          );
        }
        genUiLogger.info(
          '****** Gen UI Output ******.\n'
          '${const JsonEncoder.withIndent('  ').convert(capturedResult)}',
        );
        break;
      }

      final aiTool = availableTools.firstWhere(
        (t) => t.name == functionName || t.fullName == functionName,
        orElse: () => throw Exception('Unknown tool $functionName called.'),
      );

      Map<String, Object?> toolResult;
      try {
        genUiLogger.fine('Invoking tool: ${aiTool.name}');
        final argsMap =
            jsonDecode(argsJson) as Map<String, Object?>? ?? {};
        toolResult = await aiTool.invoke(argsMap);
        genUiLogger.info(
          'Invoked tool ${aiTool.name} with args $argsMap. '
          'Result: $toolResult',
        );
      } catch (exception, stack) {
        genUiLogger.severe(
          'Error invoking tool ${aiTool.name} with args $argsJson: ',
          exception,
          stack,
        );
        toolResult = {
          'error': 'Tool ${aiTool.name} failed to execute: $exception',
        };
      }
      toolMessages.add(
        openai.ChatMessage.tool(
          toolCallId: call.id,
          content: jsonEncode(toolResult),
        ),
      );
    }
    genUiLogger.fine(
      'Finished processing tool calls. Returning '
      '${toolMessages.length} responses.',
    );
    return (toolMessages: toolMessages, capturedResult: capturedResult);
  }

  Future<Object?> _generate({
    required Iterable<ChatMessage> messages,
    dsb.Schema? outputSchema,
  }) async {
    final isForcedToolCalling = outputSchema != null;
    final converter = OpenAiContentConverter();
    final adapter = OpenAiSchemaAdapter();

    final service = serviceFactory(configuration: this);

    try {
      final availableTools = [
        SurfaceUpdateTool(
          handleMessage: _a2uiMessageController.add,
          catalog: catalog,
        ),
        BeginRenderingTool(
          handleMessage: _a2uiMessageController.add,
          catalogId: catalog.catalogId,
        ),
        DeleteSurfaceTool(handleMessage: _a2uiMessageController.add),
        ...additionalTools,
      ];

      final openaiMessages = converter.toOpenAiMessages(messages);

      final tools = _setupTools(
        isForcedToolCalling: isForcedToolCalling,
        availableTools: availableTools,
        adapter: adapter,
        outputSchema: outputSchema,
      );

      var toolUsageCycle = 0;
      const maxToolUsageCycles = 40;
      Object? capturedResult;

      while (toolUsageCycle < maxToolUsageCycles) {
        genUiLogger.fine('Starting tool usage cycle ${toolUsageCycle + 1}.');
        if (isForcedToolCalling && capturedResult != null) {
          genUiLogger.fine('Captured result found, exiting tool usage loop.');
          break;
        }
        toolUsageCycle++;

        genUiLogger.info(
          '****** Performing Inference ******\n'
          'Messages: ${openaiMessages.length}\n'
          'Tools: ${tools.map((t) => t.function.name).join(', ')}',
        );
        final inferenceStartTime = DateTime.now();

        openai.ChatCompletion response;
        try {
          final request = openai.ChatCompletionCreateRequest(
            model: modelName,
            temperature: temperature,
            messages: [
              if (systemInstruction != null)
                openai.ChatMessage.system(systemInstruction!),
              ...openaiMessages,
            ],
            tools: tools.isNotEmpty ? tools : null,
            toolChoice: tools.isNotEmpty
                ? (isForcedToolCalling
                    ? openai.ToolChoice.required()
                    : openai.ToolChoice.auto())
                : null,
          );
          response = await service.createChatCompletion(request);
        } catch (e, st) {
          genUiLogger.severe('Error from service.createChatCompletion', e, st);
          _errorController.add(ContentGeneratorError(e, st));
          rethrow;
        }
        final elapsed = DateTime.now().difference(inferenceStartTime);

        if (response.usage != null) {
          inputTokenUsage += response.usage!.promptTokens;
          outputTokenUsage += response.usage!.completionTokens ?? 0;
        }
        genUiLogger.info(
          '****** Completed Inference ******\n'
          'Latency = ${elapsed.inMilliseconds}ms\n'
          'Output tokens = ${response.usage?.completionTokens ?? 0}\n'
          'Prompt tokens = ${response.usage?.promptTokens ?? 0}',
        );

        if (response.choices.isEmpty) {
          genUiLogger.warning('Response has no choices.');
          return isForcedToolCalling ? null : '';
        }

        final choice = response.choices.first;
        final hasToolCalls = response.hasToolCalls;

        if (!hasToolCalls) {
          genUiLogger.fine('Model response contained no tool calls.');
          final text = response.text ?? '';

          if (isForcedToolCalling) {
            genUiLogger.warning(
              'Model did not call any function. FinishReason: '
              '${choice.finishReason}.',
            );
            if (text.trim().isNotEmpty) {
              genUiLogger.warning(
                'Model returned direct text instead of a tool call.',
              );
            }
            return null;
          } else {
            openaiMessages.add(
              openai.ChatMessage.assistant(content: text),
            );
            genUiLogger.fine('Returning text response: "$text"');
            _textResponseController.add(text);
            return text;
          }
        }

        genUiLogger.fine(
          'Model response contained ${response.allToolCalls.length} '
          'tool calls.',
        );

        // Add the assistant message (with tool calls) to the conversation
        openaiMessages.add(
          openai.ChatMessage.assistant(
            content: response.text,
            toolCalls: response.allToolCalls,
          ),
        );

        final result = await _processFunctionCalls(
          toolCalls: response.allToolCalls,
          isForcedToolCalling: isForcedToolCalling,
          availableTools: availableTools,
          capturedResult: capturedResult,
        );
        capturedResult = result.capturedResult;
        final toolMessages = result.toolMessages;

        if (toolMessages.isNotEmpty) {
          openaiMessages.addAll(toolMessages);
          genUiLogger.fine(
            'Added ${toolMessages.length} tool response messages '
            'to conversation.',
          );
        }

        // If not forced and the model also returned text, treat as final.
        if (!isForcedToolCalling) {
          final text = response.text;
          if (text != null && text.trim().isNotEmpty) {
            genUiLogger.fine(
              'Model returned text response "$text". Exiting tool loop.',
            );
            _textResponseController.add(text);
            return text;
          }
        }
      }

      if (isForcedToolCalling) {
        if (toolUsageCycle >= maxToolUsageCycles) {
          genUiLogger.severe(
            'Error: Tool usage cycle exceeded maximum of $maxToolUsageCycles.',
            'No final output was produced.',
            StackTrace.current,
          );
        }
        genUiLogger.fine('Exited tool usage loop. Returning captured result.');
        return capturedResult;
      } else {
        genUiLogger.severe(
          'Error: Tool usage cycle exceeded maximum of $maxToolUsageCycles.',
          'No final output was produced.',
          StackTrace.current,
        );
        return '';
      }
    } finally {
      service.close();
    }
  }
}
