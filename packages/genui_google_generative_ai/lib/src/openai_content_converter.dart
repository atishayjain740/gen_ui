// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:genui/genui.dart';
import 'package:openai_dart/openai_dart.dart' as openai;

/// An exception thrown by this package.
class OpenAiClientException implements Exception {
  /// Creates an [OpenAiClientException] with the given [message].
  OpenAiClientException(this.message);

  /// The message associated with the exception.
  final String message;

  @override
  String toString() => '$OpenAiClientException: $message';
}

/// Converts between genui [ChatMessage] and OpenAI message types.
///
/// This class translates the abstract [ChatMessage] representation into
/// the concrete [openai.ChatMessage] representation required by the
/// `openai_dart` package.
class OpenAiContentConverter {
  /// Converts a list of genui [ChatMessage] objects to a list of
  /// OpenAI [openai.ChatMessage] objects.
  List<openai.ChatMessage> toOpenAiMessages(Iterable<ChatMessage> messages) {
    final result = <openai.ChatMessage>[];
    for (final message in messages) {
      switch (message) {
        case UserMessage():
          result.add(_convertUserMessage(message.parts));
        case UserUiInteractionMessage():
          result.add(_convertUserMessage(message.parts));
        case AiTextMessage():
          result.add(_convertAssistantMessage(message.parts));
        case AiUiMessage():
          result.add(_convertAssistantMessage(message.parts));
        case ToolResponseMessage():
          result.addAll(_convertToolResponseMessages(message.results));
        case InternalMessage():
          break;
      }
    }
    return result;
  }

  openai.ChatMessage _convertUserMessage(List<MessagePart> parts) {
    final contentParts = <openai.ContentPart>[];
    for (final part in parts) {
      switch (part) {
        case TextPart():
          contentParts.add(openai.ContentPart.text(part.text));
        case ImagePart():
          contentParts.add(_convertImagePart(part));
        case ThinkingPart():
          contentParts.add(openai.ContentPart.text('Thinking: ${part.text}'));
        case ToolCallPart():
          contentParts.add(
            openai.ContentPart.text('[Tool call: ${part.toolName}]'),
          );
        case ToolResultPart():
          contentParts.add(openai.ContentPart.text(part.result));
        case DataPart():
          throw OpenAiClientException(
            'DataPart is not supported for OpenAI conversion.',
          );
      }
    }
    return openai.ChatMessage.user(contentParts);
  }

  openai.ContentPart _convertImagePart(ImagePart part) {
    if (part.bytes != null) {
      final base64Data = base64Encode(part.bytes!);
      return openai.ContentPart.imageUrl(
        'data:${part.mimeType};base64,$base64Data',
      );
    } else if (part.base64 != null) {
      return openai.ContentPart.imageUrl(
        'data:${part.mimeType};base64,${part.base64}',
      );
    } else if (part.url != null) {
      return openai.ContentPart.imageUrl(part.url.toString());
    } else {
      throw OpenAiClientException('ImagePart has no data.');
    }
  }

  openai.ChatMessage _convertAssistantMessage(List<MessagePart> parts) {
    final textParts = <String>[];
    final toolCalls = <openai.ToolCall>[];

    for (final part in parts) {
      switch (part) {
        case TextPart():
          textParts.add(part.text);
        case ThinkingPart():
          textParts.add('Thinking: ${part.text}');
        case ToolCallPart():
          toolCalls.add(
            openai.ToolCall(
              id: part.id,
              type: 'function',
              function: openai.FunctionCall(
                name: part.toolName,
                arguments: jsonEncode(part.arguments),
              ),
            ),
          );
        case ImagePart():
        case ToolResultPart():
        case DataPart():
          break;
      }
    }

    final text = textParts.isNotEmpty ? textParts.join('') : null;
    return openai.ChatMessage.assistant(
      content: text,
      toolCalls: toolCalls.isNotEmpty ? toolCalls : null,
    );
  }

  List<openai.ChatMessage> _convertToolResponseMessages(
    List<MessagePart> parts,
  ) {
    final result = <openai.ChatMessage>[];
    for (final part in parts) {
      if (part is ToolResultPart) {
        result.add(
          openai.ChatMessage.tool(
            toolCallId: part.callId,
            content: part.result,
          ),
        );
      }
    }
    return result;
  }
}
