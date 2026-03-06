import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:gen_ui/theme.dart';

Catalog createCustomCatalog() {
  return CoreCatalogItems.asCatalog().copyWith([
    _styledCard,
    _styledButton,
    _styledMultipleChoice,
    _styledSlider,
    _styledCheckBox,
    _styledTextField,
    _imageCard,
  ]);
}

// ---------------------------------------------------------------------------
// Card
// ---------------------------------------------------------------------------
final _styledCard = CatalogItem(
  name: 'Card',
  dataSchema: CoreCatalogItems.card.dataSchema,
  widgetBuilder: (itemContext) {
    final data = itemContext.data as JsonMap;
    final childId = data['child'] as String;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: itemContext.buildChild(childId),
      ),
    );
  },
  exampleData: [
    () => '''[
      {"id":"root","component":{"Card":{"child":"content"}}},
      {"id":"content","component":{"Column":{"children":{"explicitList":["title","body"]}}}},
      {"id":"title","component":{"Text":{"text":{"literalString":"Session Summary"},"usageHint":"h4"}}},
      {"id":"body","component":{"Text":{"text":{"literalString":"Your responses have been recorded. Here is a quick overview of your session."}}}}
    ]''',
  ],
);

// ---------------------------------------------------------------------------
// Button
// ---------------------------------------------------------------------------
final _styledButton = CatalogItem(
  name: 'Button',
  dataSchema: CoreCatalogItems.button.dataSchema,
  widgetBuilder: (itemContext) {
    final data = itemContext.data as JsonMap;
    final childId = data['child'] as String;
    final actionData = data['action'] as JsonMap;
    final actionName = actionData['name'] as String;
    final contextDefinition =
        (actionData['context'] as List<Object?>?) ?? <Object?>[];
    final primary = (data['primary'] as bool?) ?? false;
    final theme = Theme.of(itemContext.buildContext);

    void onPressed() {
      final resolved = resolveContext(
        itemContext.dataContext,
        contextDefinition,
      );
      itemContext.dispatchEvent(
        UserActionEvent(
          name: actionName,
          sourceComponentId: itemContext.id,
          context: resolved,
        ),
      );
    }

    final child = itemContext.buildChild(childId);

    if (primary) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          child: child,
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          side: const BorderSide(color: AppColors.primary),
          textStyle: theme.textTheme.titleMedium,
        ),
        child: child,
      ),
    );
  },
  exampleData: [
    () => '''[
      {"id":"root","component":{"Column":{"children":{"explicitList":["primary","secondary"]}}}},
      {"id":"primary","component":{"Button":{"child":"pText","primary":true,"action":{"name":"submit"}}}},
      {"id":"pText","component":{"Text":{"text":{"literalString":"Continue"}}}},
      {"id":"secondary","component":{"Button":{"child":"sText","action":{"name":"skip"}}}},
      {"id":"sText","component":{"Text":{"text":{"literalString":"Skip"}}}}
    ]''',
  ],
);

// ---------------------------------------------------------------------------
// MultipleChoice — ChoiceChip (single) / FilterChip (multi)
// ---------------------------------------------------------------------------
final _styledMultipleChoice = CatalogItem(
  name: 'MultipleChoice',
  dataSchema: CoreCatalogItems.multipleChoice.dataSchema,
  widgetBuilder: (itemContext) {
    final data = itemContext.data as JsonMap;
    final selections = data['selections'] as JsonMap;
    final options = (data['options'] as List).cast<JsonMap>();
    final maxAllowed = (data['maxAllowedSelections'] as num?)?.toInt();

    final selectionsNotifier = itemContext.dataContext.subscribeToObjectArray(
      selections,
    );

    return ValueListenableBuilder<List<Object?>?>(
      valueListenable: selectionsNotifier,
      builder: (context, currentSelections, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((option) {
              final labelNotifier = itemContext.dataContext.subscribeToString(
                option['label'] as JsonMap,
              );
              final value = option['value'] as String;

              return ValueListenableBuilder<String?>(
                valueListenable: labelNotifier,
                builder: (context, label, _) {
                  final isSelected =
                      currentSelections?.contains(value) ?? false;

                  if (maxAllowed == 1) {
                    return ChoiceChip(
                      label: Text(label ?? ''),
                      selected: isSelected,
                      onSelected: (selected) {
                        final path = selections['path'] as String?;
                        if (path == null) return;
                        itemContext.dataContext.update(
                          DataPath(path),
                          selected ? [value] : [],
                        );
                      },
                      selectedColor: AppColors.primaryLight,
                      backgroundColor: AppColors.background,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.primary,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    );
                  }

                  return FilterChip(
                    label: Text(label ?? ''),
                    selected: isSelected,
                    onSelected: (selected) {
                      final path = selections['path'] as String?;
                      if (path == null) return;
                      final newSelections =
                          currentSelections
                              ?.map((e) => e.toString())
                              .toList() ??
                          <String>[];
                      if (selected) {
                        if (maxAllowed == null ||
                            newSelections.length < maxAllowed) {
                          newSelections.add(value);
                        }
                      } else {
                        newSelections.remove(value);
                      }
                      itemContext.dataContext.update(
                        DataPath(path),
                        newSelections,
                      );
                    },
                    selectedColor: AppColors.primaryLight,
                    backgroundColor: AppColors.background,
                    checkmarkColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  );
                },
              );
            }).toList(),
          ),
        );
      },
    );
  },
  exampleData: [
    () => '''[
      {"id":"root","component":{"Column":{"children":{"explicitList":["q","choices","btn"]}}}},
      {"id":"q","component":{"Text":{"text":{"literalString":"What kind of travel do you prefer?"},"usageHint":"h4"}}},
      {"id":"choices","component":{"MultipleChoice":{"selections":{"path":"/travel"},"maxAllowedSelections":1,"options":[
        {"label":{"literalString":"Beach & Relaxation"},"value":"beach"},
        {"label":{"literalString":"Adventure & Trekking"},"value":"adventure"},
        {"label":{"literalString":"Cultural & Heritage"},"value":"cultural"},
        {"label":{"literalString":"City & Nightlife"},"value":"city"},
        {"label":{"literalString":"Food & Culinary Tour"},"value":"food"}
      ]}}},
      {"id":"btn","component":{"Button":{"child":"btnTxt","primary":true,"action":{"name":"submit","context":[{"key":"travelStyle","value":{"path":"/travel"}}]}}}},
      {"id":"btnTxt","component":{"Text":{"text":{"literalString":"Continue"}}}}
    ]''',
  ],
);

// ---------------------------------------------------------------------------
// Slider — themed with prominent value badge
// ---------------------------------------------------------------------------
final _styledSlider = CatalogItem(
  name: 'Slider',
  dataSchema: CoreCatalogItems.slider.dataSchema,
  widgetBuilder: (itemContext) {
    final data = itemContext.data as JsonMap;
    final valueRef = data['value'] as JsonMap;
    final minValue = (data['minValue'] as num?)?.toDouble() ?? 0.0;
    final maxValue = (data['maxValue'] as num?)?.toDouble() ?? 1.0;

    final valueNotifier = itemContext.dataContext.subscribeToValue<num>(
      valueRef,
      'literalNumber',
    );

    return ValueListenableBuilder<num?>(
      valueListenable: valueNotifier,
      builder: (context, value, _) {
        final theme = Theme.of(context);
        final currentValue = (value ?? minValue).toDouble();

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                currentValue.toStringAsFixed(0),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 6,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 22),
                activeTrackColor: AppColors.primary,
                inactiveTrackColor: AppColors.primaryLight,
                thumbColor: AppColors.primary,
                overlayColor: AppColors.primary,
              ),
              child: Slider(
                value: currentValue,
                min: minValue,
                max: maxValue,
                divisions: (maxValue - minValue).toInt(),
                onChanged: (newValue) {
                  final path = valueRef['path'] as String?;
                  if (path != null) {
                    itemContext.dataContext.update(DataPath(path), newValue);
                  }
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${minValue.toStringAsFixed(0)} day',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  Text(
                    '${maxValue.toStringAsFixed(0)} days',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  },
  exampleData: [
    () => '''[
      {"id":"root","component":{"Column":{"children":{"explicitList":["q","slider","btn"]}}}},
      {"id":"q","component":{"Text":{"text":{"literalString":"How many days do you have?"},"usageHint":"h4"}}},
      {"id":"slider","component":{"Slider":{"minValue":1,"maxValue":14,"value":{"path":"/days","literalNumber":7}}}},
      {"id":"btn","component":{"Button":{"child":"btnTxt","primary":true,"action":{"name":"submit","context":[{"key":"days","value":{"path":"/days"}}]}}}},
      {"id":"btnTxt","component":{"Text":{"text":{"literalString":"Continue"}}}}
    ]''',
  ],
);

// ---------------------------------------------------------------------------
// CheckBox — modern switch style
// ---------------------------------------------------------------------------
final _styledCheckBox = CatalogItem(
  name: 'CheckBox',
  dataSchema: CoreCatalogItems.checkBox.dataSchema,
  widgetBuilder: (itemContext) {
    final data = itemContext.data as JsonMap;
    final labelRef = data['label'] as JsonMap;
    final valueRef = data['value'] as JsonMap;

    final labelNotifier = itemContext.dataContext.subscribeToString(labelRef);
    final valueNotifier = itemContext.dataContext.subscribeToBool(valueRef);

    return ValueListenableBuilder<String?>(
      valueListenable: labelNotifier,
      builder: (context, label, _) {
        return ValueListenableBuilder<bool?>(
          valueListenable: valueNotifier,
          builder: (context, value, _) {
            return SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: Text(
                label ?? '',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.primary),
              ),
              value: value ?? false,
              activeThumbColor: AppColors.primary,
              onChanged: (newValue) {
                final path = valueRef['path'] as String?;
                if (path != null) {
                  itemContext.dataContext.update(DataPath(path), newValue);
                }
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            );
          },
        );
      },
    );
  },
  exampleData: [
    () => '''[
      {"id":"root","component":{"CheckBox":{"label":{"literalString":"I have been feeling stressed lately"},"value":{"path":"/stressed","literalBoolean":false}}}}
    ]''',
  ],
);

// ---------------------------------------------------------------------------
// TextField — outlined with rounded borders
// ---------------------------------------------------------------------------
final _styledTextField = CatalogItem(
  name: 'TextField',
  dataSchema: CoreCatalogItems.textField.dataSchema,
  widgetBuilder: (itemContext) {
    final data = itemContext.data as JsonMap;
    final valueRef = data['text'] as JsonMap?;
    final path = valueRef?['path'] as String?;
    final labelRef = data['label'] as JsonMap?;
    final textFieldType = data['textFieldType'] as String?;
    final onSubmittedAction = data['onSubmittedAction'] as JsonMap?;

    final notifier = itemContext.dataContext.subscribeToString(valueRef);
    final labelNotifier = itemContext.dataContext.subscribeToString(labelRef);

    return ValueListenableBuilder<String?>(
      valueListenable: notifier,
      builder: (context, currentValue, _) {
        return ValueListenableBuilder<String?>(
          valueListenable: labelNotifier,
          builder: (context, label, _) {
            return _StyledTextField(
              initialValue: currentValue ?? '',
              label: label,
              textFieldType: textFieldType,
              onChanged: (newValue) {
                if (path != null) {
                  itemContext.dataContext.update(DataPath(path), newValue);
                }
              },
              onSubmitted: (newValue) {
                if (onSubmittedAction == null) return;
                final actionName = onSubmittedAction['name'] as String;
                final contextDef =
                    (onSubmittedAction['context'] as List<Object?>?) ??
                    <Object?>[];
                final resolved = resolveContext(
                  itemContext.dataContext,
                  contextDef,
                );
                itemContext.dispatchEvent(
                  UserActionEvent(
                    name: actionName,
                    sourceComponentId: itemContext.id,
                    context: resolved,
                  ),
                );
              },
            );
          },
        );
      },
    );
  },
  exampleData: [
    () => '''[
      {"id":"root","component":{"Column":{"children":{"explicitList":["q","input"]}}}},
      {"id":"q","component":{"Text":{"text":{"literalString":"Tell us more about how you're feeling"},"usageHint":"h4"}}},
      {"id":"input","component":{"TextField":{"text":{"path":"/feeling","literalString":""},"label":{"literalString":"Your thoughts..."}}}}
    ]''',
  ],
);

// ---------------------------------------------------------------------------
// ImageCard — card wrapper optimized for displaying images
// ---------------------------------------------------------------------------
final _imageCard = CatalogItem(
  name: 'ImageCard',
  dataSchema: CoreCatalogItems.card.dataSchema,
  widgetBuilder: (itemContext) {
    final data = itemContext.data as JsonMap;
    final childId = data['child'] as String;

    return Card(
      elevation: 0,
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: itemContext.buildChild(childId),
    );
  },
  exampleData: [
    () => '''[
      {"id":"root","component":{"ImageCard":{"child":"content"}}},
      {"id":"content","component":{"Column":{"children":{"explicitList":["img","caption"]}}}},
      {"id":"img","component":{"Image":{"url":{"literalString":"https://storage.googleapis.com/cms-storage-bucket/lockup_flutter_horizontal.c823e53b3a1a7b0d36a9.png"},"usageHint":"header"}}},
      {"id":"caption","component":{"Text":{"text":{"literalString":"The Flutter framework logo"}}}}
    ]''',
  ],
);

class _StyledTextField extends StatefulWidget {
  const _StyledTextField({
    required this.initialValue,
    this.label,
    this.textFieldType,
    required this.onChanged,
    required this.onSubmitted,
  });

  final String initialValue;
  final String? label;
  final String? textFieldType;
  final void Function(String) onChanged;
  final void Function(String) onSubmitted;

  @override
  State<_StyledTextField> createState() => _StyledTextFieldState();
}

class _StyledTextFieldState extends State<_StyledTextField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(_StyledTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      style: const TextStyle(color: AppColors.primary),
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: const TextStyle(color: AppColors.textMuted),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      obscureText: widget.textFieldType == 'obscured',
      keyboardType: switch (widget.textFieldType) {
        'number' => TextInputType.number,
        'longText' => TextInputType.multiline,
        'date' => TextInputType.datetime,
        _ => TextInputType.text,
      },
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
    );
  }
}
