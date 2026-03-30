import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mockondo/core/colors.dart';
import 'package:mockondo/features/home/presentation/controllers/home_controller.dart';
import 'package:re_editor/re_editor.dart';

// ── Prompt with optional closing brace ────────────────────────────────────────

class _InterpPrompt extends CodePrompt {
  const _InterpPrompt({
    required super.word,
    this.description = '',
    this.closeBrace = false,
  });

  final String description;
  final bool closeBrace;

  @override
  CodeAutocompleteResult get autocomplete {
    final text = closeBrace ? '$word}' : word;
    return CodeAutocompleteResult(
      input: '',
      word: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  @override
  bool match(String input) => word.startsWith(input) && word != input;
}

// ── Prompts builder ────────────────────────────────────────────────────────────

class InterpolationPromptsBuilder implements CodeAutocompletePromptsBuilder {
  @override
  CodeAutocompleteEditingValue? build(
    BuildContext context,
    CodeLine codeLine,
    CodeLineSelection selection,
  ) {
    final text = codeLine.text;
    final cursor = selection.extentOffset;
    final before = text.substring(0, cursor);

    final triggerIdx = before.lastIndexOf('\${');
    if (triggerIdx == -1) return null;

    final inside = before.substring(triggerIdx + 2);
    if (inside.contains('}')) return null;

    final parts = inside.split('.');
    final depth = parts.length;
    final input = parts.last;

    final prompts = _buildPrompts(parts, depth, input);
    if (prompts.isEmpty) return null;

    return CodeAutocompleteEditingValue(
      input: input,
      prompts: prompts,
      index: 0,
    );
  }

  List<CodePrompt> _buildPrompts(List<String> parts, int depth, String input) {
    switch (depth) {
      case 1:
        return _filter(input, [
          const _InterpPrompt(word: 'random', description: 'Random values'),
          const _InterpPrompt(word: 'request', description: 'Incoming request data'),
          const _InterpPrompt(word: 'customdata', description: 'Custom data store'),
          const _InterpPrompt(word: 'pagination', description: 'Pagination context'),
          const _InterpPrompt(word: 'math', description: 'Math expression'),
        ]);

      case 2:
        final cat = parts[0];
        if (cat == 'random') {
          return _filter(input, [
            const _InterpPrompt(word: 'uuid', description: 'Random UUID v4', closeBrace: false),
            const _InterpPrompt(word: 'name', description: 'Random full name', closeBrace: false),
            const _InterpPrompt(word: 'username', description: 'Random username', closeBrace: false),
            const _InterpPrompt(word: 'email', description: 'Random email', closeBrace: false),
            const _InterpPrompt(word: 'url', description: 'Random HTTP URL', closeBrace: false),
            const _InterpPrompt(word: 'phone', description: 'Random phone number', closeBrace: false),
            const _InterpPrompt(word: 'lorem', description: 'Lorem ipsum sentence', closeBrace: false),
            const _InterpPrompt(word: 'jwt', description: 'Random JWT token', closeBrace: false),
            const _InterpPrompt(word: 'date', description: 'Current UTC ISO date', closeBrace: false),
            const _InterpPrompt(word: 'integer', description: 'Random int (default max 100)'),
            const _InterpPrompt(word: 'double', description: 'Random double (default max 1.0)'),
            const _InterpPrompt(word: 'string', description: 'Random string (default len 20)'),
            const _InterpPrompt(word: 'image', description: 'Placeholder image URL'),
          ]);
        }
        if (cat == 'request') {
          return _filter(input, [
            const _InterpPrompt(word: 'url', description: 'Request URL data'),
            const _InterpPrompt(word: 'header', description: 'Request header value'),
            const _InterpPrompt(word: 'body', description: 'Request body field'),
          ]);
        }
        if (cat == 'customdata') {
          final keys = _customDataKeys();
          return _filter(input, [
            const _InterpPrompt(word: 'random', description: 'Random value from key'),
            ...keys.map((k) => _InterpPrompt(word: k, description: 'First value', closeBrace: false)),
          ]);
        }
        if (cat == 'pagination') {
          return _filter(input, [
            const _InterpPrompt(word: 'data', description: 'Paginated data', closeBrace: false),
            const _InterpPrompt(word: 'request', description: 'Request context'),
          ]);
        }
        return [];

      case 3:
        final cat2 = '${parts[0]}.${parts[1]}';
        if (cat2 == 'random.integer') {
          return input.isEmpty ? [const _InterpPrompt(word: '100', description: 'Max value', closeBrace: false)] : [];
        }
        if (cat2 == 'random.double') {
          return input.isEmpty ? [const _InterpPrompt(word: '1.0', description: 'Max value', closeBrace: false)] : [];
        }
        if (cat2 == 'random.string') {
          return input.isEmpty ? [const _InterpPrompt(word: '20', description: 'Length', closeBrace: false)] : [];
        }
        if (cat2 == 'random.image') {
          return input.isEmpty
              ? [const _InterpPrompt(word: '600x400', description: 'Width x Height', closeBrace: false)]
              : [];
        }
        if (cat2 == 'request.url') {
          return _filter(input, [
            const _InterpPrompt(word: 'query', description: 'Query param by name'),
            const _InterpPrompt(word: 'path', description: 'Path segment by index'),
          ]);
        }
        if (cat2 == 'request.header') {
          return input.isEmpty
              ? [const _InterpPrompt(word: 'authorization', description: 'Header name', closeBrace: false)]
              : [];
        }
        if (cat2 == 'request.body') {
          return input.isEmpty
              ? [const _InterpPrompt(word: 'field', description: 'Body field name', closeBrace: false)]
              : [];
        }
        if (cat2 == 'customdata.random') {
          final keys = _customDataKeys();
          return _filter(input, keys.map((k) => _InterpPrompt(word: k, closeBrace: false)).toList());
        }
        if (parts[0] == 'customdata' && parts[1] != 'random') {
          final values = _customDataValues(parts[1]);
          return _filter(input, values.map((v) => _InterpPrompt(word: v, description: 'value', closeBrace: false)).toList());
        }
        if (cat2 == 'pagination.request') {
          return _filter(input, [const _InterpPrompt(word: 'url')]);
        }
        return [];

      case 4:
        final cat3 = '${parts[0]}.${parts[1]}.${parts[2]}';
        if (cat3 == 'request.url.query' || cat3 == 'request.url.path') {
          return input.isEmpty
              ? [_InterpPrompt(word: cat3 == 'request.url.query' ? 'page' : '0', description: cat3.endsWith('query') ? 'Param name' : 'Segment index', closeBrace: false)]
              : [];
        }
        if (cat3 == 'pagination.request.url') {
          return _filter(input, [const _InterpPrompt(word: 'query')]);
        }
        return [];

      case 5:
        if (parts.take(4).join('.') == 'pagination.request.url.query') {
          return input.isEmpty
              ? [const _InterpPrompt(word: 'page', description: 'Param name', closeBrace: false)]
              : [];
        }
        return [];

      default:
        return [];
    }
  }

  List<CodePrompt> _filter(String input, List<_InterpPrompt> all) {
    if (input.isEmpty) return all;
    return all.where((p) => p.match(input)).toList();
  }

  List<String> _customDataKeys() {
    try {
      final ctrl = Get.find<HomeController>();
      return ctrl.customData.keys.map((k) => k.trim()).where((k) => k.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  List<String> _customDataValues(String key) {
    try {
      final ctrl = Get.find<HomeController>();
      final trimmedKey = ctrl.customData.keys.firstWhere(
        (k) => k.trim() == key.trim(),
        orElse: () => key,
      );
      return ctrl.customData[trimmedKey]?.map((v) => v.trim()).where((v) => v.isNotEmpty).toList() ?? [];
    } catch (_) {
      return [];
    }
  }
}

// ── Autocomplete dropdown view ─────────────────────────────────────────────────

PreferredSizeWidget buildInterpolationAutocompleteView(
  BuildContext context,
  ValueNotifier<CodeAutocompleteEditingValue> notifier,
  ValueChanged<CodeAutocompleteResult> onSelected,
) {
  return _InterpolationAutocompleteView(
    notifier: notifier,
    onSelected: onSelected,
  );
}

class _InterpolationAutocompleteView extends StatelessWidget
    implements PreferredSizeWidget {
  const _InterpolationAutocompleteView({
    required this.notifier,
    required this.onSelected,
  });

  final ValueNotifier<CodeAutocompleteEditingValue> notifier;
  final ValueChanged<CodeAutocompleteResult> onSelected;

  static const _itemHeight = 30.0;
  static const _maxVisible = 7;

  @override
  Size get preferredSize => const Size(280, _itemHeight * _maxVisible);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CodeAutocompleteEditingValue>(
      valueListenable: notifier,
      builder: (_, value, __) {
        final prompts = value.prompts;
        final visibleCount = prompts.length.clamp(1, _maxVisible);
        return Container(
          width: 280,
          height: visibleCount * _itemHeight,
          decoration: BoxDecoration(
            color: AppColors.backgroundD,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.textD.withValues(alpha: 0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: prompts.length,
            itemExtent: _itemHeight,
            itemBuilder: (_, i) {
              final p = prompts[i] as _InterpPrompt;
              final isSelected = i == value.index;
              return InkWell(
                onTap: () => onSelected(value.copyWith(index: i).autocomplete),
                child: Container(
                  color: isSelected
                      ? AppColors.secondaryD.withValues(alpha: 0.2)
                      : Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
                  child: Row(
                    children: [
                      Icon(
                        Icons.data_object_rounded,
                        size: 12,
                        color: AppColors.secondaryD.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: AppSpacing.s),
                      Text(
                        p.word,
                        style: TextStyle(
                          color: AppColors.textD,
                          fontSize: AppTextSize.small,
                          fontFamily: 'monospace',
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      if (p.description.isNotEmpty) ...[
                        const SizedBox(width: AppSpacing.m),
                        Expanded(
                          child: Text(
                            p.description,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textD.withValues(alpha: 0.4),
                              fontSize: AppTextSize.badge,
                            ),
                          ),
                        ),
                      ],
                      if (p.closeBrace)
                        Text(
                          '}',
                          style: TextStyle(
                            color: AppColors.secondaryD.withValues(alpha: 0.5),
                            fontSize: AppTextSize.badge,
                            fontFamily: 'monospace',
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
