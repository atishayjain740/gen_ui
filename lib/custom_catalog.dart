import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:gen_ui/theme.dart';
import 'package:json_schema_builder/json_schema_builder.dart' as dsb;

Catalog createCustomCatalog() {
  return CoreCatalogItems.asCatalog().copyWith([
    _styledCard,
    _styledButton,
    _styledMultipleChoice,
    _styledSlider,
    _styledCheckBox,
    _styledTextField,
    _imageCard,
    _spacedColumn,
    _spacedRow,
    _progressIndicator,
    _emojiRating,
    _styledRangeSlider,
    _styledDateTimeInput,
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
                    minValue.toStringAsFixed(0),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  Text(
                    maxValue.toStringAsFixed(0),
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

// ---------------------------------------------------------------------------
// Column — with vertical spacing between children
// ---------------------------------------------------------------------------
final _spacedColumn = CatalogItem(
  name: 'Column',
  dataSchema: CoreCatalogItems.column.dataSchema,
  widgetBuilder: (itemContext) {
    return _buildSpacedLayout(itemContext: itemContext, axis: Axis.vertical);
  },
  exampleData: CoreCatalogItems.column.exampleData,
);

// ---------------------------------------------------------------------------
// Row — with horizontal spacing between children
// ---------------------------------------------------------------------------
final _spacedRow = CatalogItem(
  name: 'Row',
  dataSchema: CoreCatalogItems.row.dataSchema,
  widgetBuilder: (itemContext) {
    return _buildSpacedLayout(itemContext: itemContext, axis: Axis.horizontal);
  },
  exampleData: CoreCatalogItems.row.exampleData,
);

// ---------------------------------------------------------------------------
// ProgressIndicator — shows "Question X of Y" with a linear progress bar
// ---------------------------------------------------------------------------
final _progressIndicator = CatalogItem(
  name: 'ProgressIndicator',
  dataSchema: dsb.S.object(
    properties: {
      'current': dsb.S.integer(description: 'Current step number (1-based).'),
      'total': dsb.S.integer(description: 'Total number of steps.'),
      'label': dsb.S.string(
        description: 'Optional label, e.g. "Question 2 of 6".',
      ),
    },
    required: ['current', 'total'],
  ),
  widgetBuilder: (itemContext) {
    final data = itemContext.data as JsonMap;
    final current = (data['current'] as num?)?.toInt() ?? 1;
    final total = (data['total'] as num?)?.toInt() ?? 1;
    final label = data['label'] as String? ?? 'Question $current of $total';
    final progress = total > 0 ? current / total : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '$current/$total',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.primaryLight,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  },
  exampleData: [
    () => '''[
      {"id":"root","component":{"ProgressIndicator":{"current":2,"total":6}}}
    ]''',
  ],
);

// ---------------------------------------------------------------------------
// EmojiRating — row of emoji faces for mood/satisfaction rating
// ---------------------------------------------------------------------------
final _emojiRating = CatalogItem(
  name: 'EmojiRating',
  dataSchema: dsb.S.object(
    properties: {
      'value': dsb.S.object(
        description: 'Data-bound path for the selected rating value.',
        properties: {
          'path': dsb.S.string(
            description: 'Path in the data model to store the selection.',
          ),
          'literalNumber': dsb.S.number(),
        },
      ),
      'labels': dsb.S.list(
        description:
            'Optional labels for each emoji (e.g. ["Very Bad","Bad","Okay","Good","Great"]). '
            'Must have exactly 5 items if provided.',
        items: dsb.S.string(),
      ),
    },
    required: ['value'],
  ),
  widgetBuilder: (itemContext) {
    final data = itemContext.data as JsonMap;
    final valueRef = data['value'] as JsonMap;
    final labels = (data['labels'] as List?)?.cast<String>() ??
        const ['Very Bad', 'Bad', 'Okay', 'Good', 'Great'];
    const emojis = ['😢', '😟', '😐', '🙂', '😄'];

    final valueNotifier = itemContext.dataContext.subscribeToValue<num>(
      valueRef,
      'literalNumber',
    );

    return ValueListenableBuilder<num?>(
      valueListenable: valueNotifier,
      builder: (context, value, _) {
        final selected = value?.toInt();

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(emojis.length, (index) {
              final isSelected = selected == index + 1;
              return GestureDetector(
                onTap: () {
                  final path = valueRef['path'] as String?;
                  if (path != null) {
                    itemContext.dataContext.update(
                      DataPath(path),
                      index + 1,
                    );
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryLight
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          isSelected ? AppColors.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        emojis[index],
                        style: TextStyle(
                          fontSize: isSelected ? 36 : 28,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        labels.length > index ? labels[index] : '',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  },
  exampleData: [
    () => '''[
      {"id":"root","component":{"Column":{"children":{"explicitList":["q","rating","btn"]}}}},
      {"id":"q","component":{"Text":{"text":{"literalString":"How are you feeling right now?"},"usageHint":"h4"}}},
      {"id":"rating","component":{"EmojiRating":{"value":{"path":"/mood","literalNumber":3}}}},
      {"id":"btn","component":{"Button":{"child":"btnTxt","primary":true,"action":{"name":"submit","context":[{"key":"mood","value":{"path":"/mood"}}]}}}},
      {"id":"btnTxt","component":{"Text":{"text":{"literalString":"Continue"}}}}
    ]''',
  ],
);

// ---------------------------------------------------------------------------
// RangeSlider — two-thumb slider for selecting a min/max range
// ---------------------------------------------------------------------------
final _styledRangeSlider = CatalogItem(
  name: 'RangeSlider',
  dataSchema: dsb.S.object(
    properties: {
      'lowValue': dsb.S.object(
        description: 'Data-bound path for the low end of the range.',
        properties: {
          'path': dsb.S.string(),
          'literalNumber': dsb.S.number(),
        },
      ),
      'highValue': dsb.S.object(
        description: 'Data-bound path for the high end of the range.',
        properties: {
          'path': dsb.S.string(),
          'literalNumber': dsb.S.number(),
        },
      ),
      'minValue': dsb.S.number(description: 'Minimum possible value.'),
      'maxValue': dsb.S.number(description: 'Maximum possible value.'),
      'unit': dsb.S.string(
        description: 'Optional unit label, e.g. "\$", "km", "hrs".',
      ),
    },
    required: ['lowValue', 'highValue'],
  ),
  widgetBuilder: (itemContext) {
    final data = itemContext.data as JsonMap;
    final lowRef = data['lowValue'] as JsonMap;
    final highRef = data['highValue'] as JsonMap;
    final minValue = (data['minValue'] as num?)?.toDouble() ?? 0.0;
    final maxValue = (data['maxValue'] as num?)?.toDouble() ?? 100.0;
    final unit = data['unit'] as String? ?? '';

    final lowNotifier = itemContext.dataContext.subscribeToValue<num>(
      lowRef,
      'literalNumber',
    );
    final highNotifier = itemContext.dataContext.subscribeToValue<num>(
      highRef,
      'literalNumber',
    );

    return ValueListenableBuilder<num?>(
      valueListenable: lowNotifier,
      builder: (context, lowVal, _) {
        return ValueListenableBuilder<num?>(
          valueListenable: highNotifier,
          builder: (context, highVal, _) {
            final theme = Theme.of(context);
            final low = (lowVal ?? minValue).toDouble();
            final high = (highVal ?? maxValue).toDouble();
            final divisions = (maxValue - minValue).toInt();

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '$unit${low.toStringAsFixed(0)}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      'to',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '$unit${high.toStringAsFixed(0)}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 6,
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: AppColors.primaryLight,
                    thumbColor: AppColors.primary,
                    overlayColor: AppColors.primary.withValues(alpha: 0.12),
                    rangeThumbShape: const RoundRangeSliderThumbShape(
                      enabledThumbRadius: 12,
                    ),
                  ),
                  child: RangeSlider(
                    values: RangeValues(low, high),
                    min: minValue,
                    max: maxValue,
                    divisions: divisions > 0 ? divisions : null,
                    onChanged: (values) {
                      final lowPath = lowRef['path'] as String?;
                      final highPath = highRef['path'] as String?;
                      if (lowPath != null) {
                        itemContext.dataContext.update(
                          DataPath(lowPath),
                          values.start,
                        );
                      }
                      if (highPath != null) {
                        itemContext.dataContext.update(
                          DataPath(highPath),
                          values.end,
                        );
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
                        '$unit${minValue.toStringAsFixed(0)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        '$unit${maxValue.toStringAsFixed(0)}',
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
    );
  },
  exampleData: [
    () => '''[
      {"id":"root","component":{"Column":{"children":{"explicitList":["q","range","btn"]}}}},
      {"id":"q","component":{"Text":{"text":{"literalString":"What is your budget range per person?"},"usageHint":"h4"}}},
      {"id":"range","component":{"RangeSlider":{"lowValue":{"path":"/budgetLow","literalNumber":500},"highValue":{"path":"/budgetHigh","literalNumber":2000},"minValue":100,"maxValue":5000,"unit":"\$"}}},
      {"id":"btn","component":{"Button":{"child":"btnTxt","primary":true,"action":{"name":"submit","context":[{"key":"budgetLow","value":{"path":"/budgetLow"}},{"key":"budgetHigh","value":{"path":"/budgetHigh"}}]}}}},
      {"id":"btnTxt","component":{"Text":{"text":{"literalString":"Continue"}}}}
    ]''',
  ],
);

// ---------------------------------------------------------------------------
// DateTimeInput — styled version of core DateTimeInput
// ---------------------------------------------------------------------------
final _styledDateTimeInput = CatalogItem(
  name: 'DateTimeInput',
  dataSchema: CoreCatalogItems.dateTimeInput.dataSchema,
  widgetBuilder: (itemContext) {
    final data = itemContext.data as JsonMap;
    final valueRef = data['value'] as JsonMap;
    final enableDate = (data['enableDate'] as bool?) ?? true;
    final enableTime = (data['enableTime'] as bool?) ?? true;

    final valueNotifier = itemContext.dataContext.subscribeToString(valueRef);

    return ValueListenableBuilder<String?>(
      valueListenable: valueNotifier,
      builder: (context, value, _) {
        final theme = Theme.of(context);
        String displayText;
        if (value != null && value.isNotEmpty) {
          final date = DateTime.tryParse(value);
          if (date != null) {
            final parts = <String>[];
            if (enableDate) {
              parts.add(
                MaterialLocalizations.of(context).formatMediumDate(date),
              );
            }
            if (enableTime) {
              parts.add(
                MaterialLocalizations.of(context).formatTimeOfDay(
                  TimeOfDay.fromDateTime(date),
                ),
              );
            }
            displayText = parts.join(' at ');
          } else {
            displayText = value;
          }
        } else {
          if (enableDate && !enableTime) {
            displayText = 'Tap to select a date';
          } else if (!enableDate && enableTime) {
            displayText = 'Tap to select a time';
          } else {
            displayText = 'Tap to select date & time';
          }
        }

        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () async {
            final path = valueRef['path'] as String?;
            if (path == null) return;

            final now = DateTime.now();
            DateTime resultDate = DateTime.tryParse(value ?? '') ?? now;
            TimeOfDay resultTime = TimeOfDay.fromDateTime(resultDate);

            if (enableDate) {
              final firstDateStr = data['firstDate'] as String?;
              final lastDateStr = data['lastDate'] as String?;
              final picked = await showDatePicker(
                context: context,
                initialDate: resultDate,
                firstDate:
                    DateTime.tryParse(firstDateStr ?? '') ?? DateTime(2020),
                lastDate:
                    DateTime.tryParse(lastDateStr ?? '') ?? DateTime(2030),
              );
              if (picked == null || !context.mounted) return;
              resultDate = picked;
            }

            if (enableTime) {
              final picked = await showTimePicker(
                context: context,
                initialTime: resultTime,
              );
              if (picked == null) return;
              resultTime = picked;
            }

            final finalDt = DateTime(
              resultDate.year,
              resultDate.month,
              resultDate.day,
              enableTime ? resultTime.hour : 0,
              enableTime ? resultTime.minute : 0,
            );

            String formatted;
            if (enableDate && !enableTime) {
              formatted = finalDt.toIso8601String().split('T').first;
            } else if (!enableDate && enableTime) {
              formatted =
                  '${finalDt.hour.toString().padLeft(2, '0')}:'
                  '${finalDt.minute.toString().padLeft(2, '0')}:00';
            } else {
              formatted = finalDt.toIso8601String();
            }
            itemContext.dataContext.update(DataPath(path), formatted);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    displayText,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: (value != null && value.isNotEmpty)
                          ? AppColors.primary
                          : AppColors.textMuted,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_drop_down,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        );
      },
    );
  },
  exampleData: [
    () => '''[
      {"id":"root","component":{"Column":{"children":{"explicitList":["q","picker","btn"]}}}},
      {"id":"q","component":{"Text":{"text":{"literalString":"When are you planning to travel?"},"usageHint":"h4"}}},
      {"id":"picker","component":{"DateTimeInput":{"value":{"path":"/travelDate"},"enableTime":false}}},
      {"id":"btn","component":{"Button":{"child":"btnTxt","primary":true,"action":{"name":"submit","context":[{"key":"travelDate","value":{"path":"/travelDate"}}]}}}},
      {"id":"btnTxt","component":{"Text":{"text":{"literalString":"Continue"}}}}
    ]''',
  ],
);

MainAxisAlignment _mainAxisAlignment(String? value) {
  return switch (value) {
    'center' => MainAxisAlignment.center,
    'end' => MainAxisAlignment.end,
    'spaceBetween' => MainAxisAlignment.spaceBetween,
    'spaceAround' => MainAxisAlignment.spaceAround,
    'spaceEvenly' => MainAxisAlignment.spaceEvenly,
    _ => MainAxisAlignment.start,
  };
}

CrossAxisAlignment _crossAxisAlignment(String? value) {
  return switch (value) {
    'center' => CrossAxisAlignment.center,
    'end' => CrossAxisAlignment.end,
    'stretch' => CrossAxisAlignment.stretch,
    'baseline' => CrossAxisAlignment.baseline,
    _ => CrossAxisAlignment.start,
  };
}

Widget _buildSpacedLayout({
  required CatalogItemContext itemContext,
  required Axis axis,
}) {
  const verticalSpacing = 12.0;
  const horizontalSpacing = 8.0;
  final spacing = axis == Axis.vertical ? verticalSpacing : horizontalSpacing;
  final spacer = axis == Axis.vertical
      ? SizedBox(height: spacing)
      : SizedBox(width: spacing);

  final data = itemContext.data as JsonMap;
  final childrenData = data['children'];
  final distribution = data['distribution'] as String?;
  final alignment = data['alignment'] as String?;

  final List<String>? explicitList = (childrenData is List)
      ? childrenData.cast<String>()
      : ((childrenData as JsonMap?)?['explicitList'] as List?)?.cast<String>();

  if (explicitList != null) {
    final children = <Widget>[];
    for (var i = 0; i < explicitList.length; i++) {
      if (i > 0) children.add(spacer);
      final id = explicitList[i];
      final weight = itemContext.getComponent(id)?.weight;
      Widget child = itemContext.buildChild(id);
      if (weight != null) {
        child = Flexible(flex: weight, child: child);
      }
      children.add(child);
    }
    return axis == Axis.vertical
        ? Column(
            mainAxisAlignment: _mainAxisAlignment(distribution),
            crossAxisAlignment: _crossAxisAlignment(alignment),
            mainAxisSize: MainAxisSize.min,
            children: children,
          )
        : Row(
            mainAxisAlignment: _mainAxisAlignment(distribution),
            crossAxisAlignment: _crossAxisAlignment(alignment),
            mainAxisSize: MainAxisSize.min,
            children: children,
          );
  }

  if (childrenData is JsonMap) {
    final template = childrenData['template'] as JsonMap?;
    if (template != null) {
      final dataBinding = template['dataBinding'] as String;
      final componentId = template['componentId'] as String;
      final dataNotifier = itemContext.dataContext
          .subscribe<Map<String, Object?>>(DataPath(dataBinding));
      return ValueListenableBuilder<Map<String, Object?>?>(
        valueListenable: dataNotifier,
        builder: (context, mapData, _) {
          if (mapData == null) return const SizedBox.shrink();
          final keys = mapData.keys.toList();
          final children = <Widget>[];
          for (var i = 0; i < keys.length; i++) {
            if (i > 0) children.add(spacer);
            final weight = itemContext.getComponent(componentId)?.weight;
            Widget child = itemContext.buildChild(
              componentId,
              itemContext.dataContext.nested(
                DataPath('$dataBinding/${keys[i]}'),
              ),
            );
            if (weight != null) {
              child = Flexible(flex: weight, child: child);
            }
            children.add(child);
          }
          return axis == Axis.vertical
              ? Column(
                  mainAxisAlignment: _mainAxisAlignment(distribution),
                  crossAxisAlignment: _crossAxisAlignment(alignment),
                  mainAxisSize: MainAxisSize.min,
                  children: children,
                )
              : Row(
                  mainAxisAlignment: _mainAxisAlignment(distribution),
                  crossAxisAlignment: _crossAxisAlignment(alignment),
                  mainAxisSize: MainAxisSize.min,
                  children: children,
                );
        },
      );
    }
  }

  return const SizedBox.shrink();
}

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
