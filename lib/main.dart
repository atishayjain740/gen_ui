import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:genui/genui.dart';
import 'package:genui_google_generative_ai/genui_google_generative_ai.dart';
import 'package:gen_ui/system_instruction.dart';

Future<void> main() async {
  await dotenv.load();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GenUI Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'GenUI Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late final A2uiMessageProcessor _a2uiMessageProcessor;
  late final GenUiConversation _genUiConversation;

  @override
  void initState() {
    super.initState();

    final catalog = CoreCatalogItems.asCatalog();
    _a2uiMessageProcessor = A2uiMessageProcessor(catalogs: [catalog]);

    final contentGenerator = GoogleGenerativeAiContentGenerator(
      catalog: catalog,
      systemInstruction: systemInstruction,
      modelName: 'models/gemini-2.5-flash',
      apiKey: dotenv.env['GEMINI_API_KEY']!,
    );

    _genUiConversation = GenUiConversation(
      contentGenerator: contentGenerator,
      a2uiMessageProcessor: _a2uiMessageProcessor,
      onSurfaceAdded: (_) => setState(() {}),
      onSurfaceDeleted: (_) => setState(() {}),
      onError: _handleGenUiError,
    );
  }

  void _handleGenUiError(ContentGeneratorError error) {
    if (!mounted) return;
    final msg = error.error.toString().toLowerCase();
    final isRateLimit =
        msg.contains('too many requests') ||
        msg.contains('429') ||
        msg.contains('resource exhausted') ||
        msg.contains('quota') ||
        msg.contains('rate limit');
    final text = isRateLimit
        ? 'Too many requests. Please wait a minute and try again.'
        : 'Something went wrong. Please try again.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 5)),
    );
  }

  @override
  void dispose() {
    _genUiConversation.dispose();
    _a2uiMessageProcessor.dispose();
    super.dispose();
  }

  void _onGetStarted() {
    _genUiConversation.sendRequest(UserMessage.text("Let's get started"));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: _genUiConversation.isProcessing,
            builder: (context, isProcessing, _) {
              if (!isProcessing) return const SizedBox.shrink();
              return const LinearProgressIndicator();
            },
          ),
          Expanded(
            child: ValueListenableBuilder<List<ChatMessage>>(
              valueListenable: _genUiConversation.conversation,
              builder: (context, messages, _) {
                if (messages.isEmpty) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: _genUiConversation.isProcessing,
                    builder: (context, isProcessing, _) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: FilledButton(
                            onPressed: isProcessing ? null : _onGetStarted,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                              child: Text(
                                isProcessing ? 'Please wait…' : 'Get started',
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }

                // Find the latest AiUiMessage
                final AiUiMessage? latestUiMessage = messages.reversed
                    .whereType<AiUiMessage>()
                    .firstOrNull;

                if (latestUiMessage == null) {
                  return const SizedBox.shrink();
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: 1, // Only display the latest UI message
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      child: GenUiSurface(
                        host: _genUiConversation.host,
                        surfaceId: latestUiMessage.surfaceId,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
