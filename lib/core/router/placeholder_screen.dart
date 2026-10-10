/// Temporary screen used while a feature is being built. Feature agents
/// replace every `PlaceholderScreen` in their `<feature>_routes.dart`.
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_theme.dart';

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen(this.title, {this.detail, super.key});

  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: context.ff.canvas,
      appBar: canPop ? AppBar(title: Text(title)) : null,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: context.text.largeTitle),
              if (detail != null) ...[
                const SizedBox(height: 8),
                Text(detail!, style: context.text.meta),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
