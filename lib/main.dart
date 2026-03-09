import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:genui/genui.dart';
import 'package:genui_google_generative_ai/genui_google_generative_ai.dart';
import 'package:gen_ui/custom_catalog.dart';
import 'package:gen_ui/system_instruction.dart';
import 'package:gen_ui/theme.dart';
import 'package:gen_ui/widget_preview_page.dart';

Future<void> main() async {
  await dotenv.load();
  runApp(const MyApp());
}

class AgentConfig {
  const AgentConfig({
    required this.label,
    required this.subtitle,
    required this.icon,
    required String Function() instructionBuilder,
    this.questionCount = 6,
  }) : _instructionBuilder = instructionBuilder;

  final String label;
  final String subtitle;
  final IconData icon;
  final int questionCount;
  final String Function() _instructionBuilder;

  String get instruction => _instructionBuilder();

  static final builtIn = [
    AgentConfig(
      label: 'Mental Health',
      subtitle: 'Wellness check-in & personalized action plan',
      icon: Icons.psychology,
      instructionBuilder: () => mentalHealthInstruction(questionCount: 6),
    ),
    AgentConfig(
      label: 'Travel Itinerary',
      subtitle: 'Plan your dream trip with a day-by-day guide',
      icon: Icons.flight_takeoff,
      instructionBuilder: () => travelItineraryInstruction(questionCount: 6),
    ),
    AgentConfig(
      label: 'Fitness & Nutrition',
      subtitle: 'Custom workout plan & nutrition guidelines',
      icon: Icons.fitness_center,
      instructionBuilder: () => fitnessNutritionInstruction(questionCount: 6),
    ),
    AgentConfig(
      label: 'Career Development',
      subtitle: 'Strategic career plan with actionable steps',
      icon: Icons.trending_up,
      instructionBuilder: () => careerDevelopmentInstruction(questionCount: 6),
    ),
  ];

  factory AgentConfig.custom({
    required String name,
    required IconData icon,
    required String systemPrompt,
    int questionCount = 6,
  }) {
    return AgentConfig(
      label: name,
      subtitle: systemPrompt,
      icon: icon,
      questionCount: questionCount,
      instructionBuilder: () => customAgentInstruction(
        agentPrompt: systemPrompt,
        questionCount: questionCount,
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GenUI Demo',
      theme: appTheme,
      home: const TopicSelectionPage(),
    );
  }
}

class TopicSelectionPage extends StatefulWidget {
  const TopicSelectionPage({super.key});

  @override
  State<TopicSelectionPage> createState() => _TopicSelectionPageState();
}

class _TopicSelectionPageState extends State<TopicSelectionPage> {
  final List<AgentConfig> _customAgents = [];

  void _showAddAgentDialog() {
    final nameController = TextEditingController();
    final promptController = TextEditingController();
    IconData selectedIcon = _availableIcons.first;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('New Custom Agent'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Agent Name',
                        hintText: 'e.g. Recipe Planner',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Icon'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableIcons.map((icon) {
                        final isSelected = icon == selectedIcon;
                        return GestureDetector(
                          onTap: () =>
                              setDialogState(() => selectedIcon = icon),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primaryLight
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.border,
                              ),
                            ),
                            child: Icon(
                              icon,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textMuted,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: promptController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'System Prompt',
                        hintText: 'Describe the agent role and behavior...',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final prompt = promptController.text.trim();
                    if (name.isEmpty || prompt.isEmpty) return;
                    setState(() {
                      _customAgents.add(AgentConfig.custom(
                        name: name,
                        icon: selectedIcon,
                        systemPrompt: prompt,
                      ));
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddAgentDialog,
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 56,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'What would you like\nto explore?',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose a topic to get started',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
                for (final agent in AgentConfig.builtIn) ...[
                  _AgentCard(agent: agent),
                  const SizedBox(height: 12),
                ],
                if (_customAgents.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Custom Agents',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final agent in _customAgents) ...[
                    _AgentCard(agent: agent),
                    const SizedBox(height: 12),
                  ],
                ],
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const WidgetPreviewPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.palette_outlined),
                  label: const Text('Widget Preview'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const _availableIcons = [
  Icons.smart_toy,
  Icons.restaurant,
  Icons.school,
  Icons.brush,
  Icons.music_note,
  Icons.code,
  Icons.science,
  Icons.pets,
  Icons.sports_esports,
  Icons.auto_stories,
  Icons.lightbulb,
  Icons.rocket_launch,
];

class _AgentCard extends StatelessWidget {
  const _AgentCard({required this.agent});
  final AgentConfig agent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ChatPage(agent: agent),
            ));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              children: [
                Icon(agent.icon, size: 32, color: theme.colorScheme.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(agent.label, style: theme.textTheme.titleLarge),
                      const SizedBox(height: 2),
                      Text(
                        agent.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.agent});

  final AgentConfig agent;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late final A2uiMessageProcessor _a2uiMessageProcessor;
  late final GenUiConversation _genUiConversation;

  @override
  void initState() {
    super.initState();

    final catalog = createCustomCatalog();
    _a2uiMessageProcessor = A2uiMessageProcessor(catalogs: [catalog]);

    final contentGenerator = GoogleGenerativeAiContentGenerator(
      catalog: catalog,
      systemInstruction: widget.agent.instruction,
      modelName: 'models/gemini-3-flash-preview',
      apiKey: dotenv.env['GEMINI_API_KEY']!,
    );

    _genUiConversation = GenUiConversation(
      contentGenerator: contentGenerator,
      a2uiMessageProcessor: _a2uiMessageProcessor,
      onSurfaceAdded: (_) {
        if (mounted) setState(() {});
      },
      onSurfaceDeleted: (_) {
        if (mounted) setState(() {});
      },
      onError: _handleGenUiError,
    );

    _onGetStarted();
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
    super.dispose();
  }

  void _onGetStarted() {
    _genUiConversation.sendRequest(UserMessage.text("Let's get started"));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primary,
        elevation: 0,
        title: Text(widget.agent.label),
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
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

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
                  itemCount: 1,
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
