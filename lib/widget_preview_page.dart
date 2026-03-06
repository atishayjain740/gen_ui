import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:gen_ui/custom_catalog.dart';
import 'package:gen_ui/theme.dart';

class WidgetPreviewPage extends StatelessWidget {
  const WidgetPreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primary,
        elevation: 0,
        title: const Text('Widget Preview'),
      ),
      body: DebugCatalogView(
        catalog: createCustomCatalog(),
        onSubmit: (message) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Action: ${message.text}'),
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }
}
