// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:openai_dart/openai_dart.dart' as openai;

/// An interface for the OpenAI service, allowing for mock implementations.
///
/// This interface abstracts the underlying OpenAI client, allowing for
/// different implementations to be used, for example, in testing.
abstract class OpenAiServiceInterface {
  /// Creates a chat completion from the given [request].
  Future<openai.ChatCompletion> createChatCompletion(
    openai.ChatCompletionCreateRequest request,
  );

  /// Closes the service and releases any resources.
  void close();
}

/// A wrapper for the [openai.OpenAIClient] that implements the
/// [OpenAiServiceInterface].
///
/// This class wraps the OpenAI client so that it can be used interchangeably
/// with other implementations of the [OpenAiServiceInterface].
class OpenAiServiceWrapper implements OpenAiServiceInterface {
  /// Creates a new [OpenAiServiceWrapper] that wraps the given [_client].
  OpenAiServiceWrapper(this._client);

  final openai.OpenAIClient _client;

  @override
  Future<openai.ChatCompletion> createChatCompletion(
    openai.ChatCompletionCreateRequest request,
  ) => _client.chat.completions.create(request);

  @override
  void close() => _client.close();
}
