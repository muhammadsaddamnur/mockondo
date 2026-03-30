import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mockondo/core/colors.dart';
import 'package:mockondo/features/home/presentation/controllers/home_controller.dart';

class _Suggestion {
  const _Suggestion(this.word, this.description, {this.closeBrace = false});
  final String word;
  final String description;
  final bool closeBrace;
}

/// A [TextField] that shows interpolation suggestions when the user types `${`.
class InterpolationTextField extends StatefulWidget {
  const InterpolationTextField({
    super.key,
    required this.controller,
    this.hintText,
    this.textSize = 12,
    this.onChanged,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final String? hintText;
  final double textSize;
  final ValueChanged<String>? onChanged;
  final bool readOnly;

  @override
  State<InterpolationTextField> createState() => _InterpolationTextFieldState();
}

class _InterpolationTextFieldState extends State<InterpolationTextField> {
  final _focusNode = FocusNode();
  OverlayEntry? _overlay;
  int _hoverIndex = 0;
  List<_Suggestion> _suggestions = [];
  int _savedCursor = -1; // cursor position when suggestions were last computed

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _removeOverlay();
    widget.controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) _removeOverlay();
  }

  void _onTextChanged() {
    if (widget.readOnly) return;
    final ctrl = widget.controller;
    final cursor = ctrl.selection.extentOffset;
    if (cursor < 0 || cursor > ctrl.text.length) {
      _removeOverlay();
      return;
    }

    final before = ctrl.text.substring(0, cursor);
    final triggerIdx = before.lastIndexOf('\${');
    if (triggerIdx == -1) { _removeOverlay(); return; }

    final inside = before.substring(triggerIdx + 2);
    if (inside.contains('}')) { _removeOverlay(); return; }

    final parts = inside.split('.');
    final suggestions = _buildSuggestions(parts);
    if (suggestions.isEmpty) { _removeOverlay(); return; }

    _suggestions = suggestions;
    _hoverIndex = 0;
    _savedCursor = cursor;
    _showOverlay();
  }

  void _accept(_Suggestion s) {
    final ctrl = widget.controller;
    // Use saved cursor when focus was lost before accept fires
    final cursor = ctrl.selection.extentOffset >= 0
        ? ctrl.selection.extentOffset
        : _savedCursor;
    if (cursor < 0 || cursor > ctrl.text.length) return;
    final before = ctrl.text.substring(0, cursor);
    final triggerIdx = before.lastIndexOf('\${');
    if (triggerIdx == -1) return;

    final inside = before.substring(triggerIdx + 2);
    final parts = inside.split('.');
    final partialLen = parts.last.length;

    final suffix = s.closeBrace ? '}' : '.';
    final newText = ctrl.text.substring(0, cursor - partialLen) +
        s.word +
        suffix +
        ctrl.text.substring(cursor);
    final newCursor = cursor - partialLen + s.word.length + 1;

    ctrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
    widget.onChanged?.call(newText);
    _removeOverlay();
    _focusNode.requestFocus();
  }

  void _showOverlay() {
    _removeOverlay();
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final offset = renderBox.localToGlobal(Offset.zero);
    final height = renderBox.size.height;

    _overlay = OverlayEntry(builder: (_) {
      const itemH = 28.0;
      const maxVisible = 7;
      final count = _suggestions.length.clamp(1, maxVisible);
      return Positioned(
        left: offset.dx,
        top: offset.dy + height + 2,
        width: 260,
        child: TextFieldTapRegion(
          child: Material(
            color: Colors.transparent,
            child: _SuggestionList(
              suggestions: _suggestions,
              hoverIndex: _hoverIndex,
              itemHeight: itemH,
              visibleCount: count,
              onHover: (i) {
                _hoverIndex = i;
                _overlay?.markNeedsBuild();
              },
              onSelect: (i) {
                _hoverIndex = i;
                _accept(_suggestions[i]);
              },
            ),
          ),
        ),
      );
    });
    Overlay.of(context).insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      readOnly: widget.readOnly,
      style: TextStyle(fontSize: widget.textSize, color: AppColors.textD),
      cursorHeight: widget.textSize,
      onChanged: widget.onChanged,
      onSubmitted: (_) {
        if (_overlay != null && _suggestions.isNotEmpty) {
          final idx = _hoverIndex.clamp(0, _suggestions.length - 1);
          _accept(_suggestions[idx]);
        }
      },
      decoration: InputDecoration(
        hintText: widget.hintText,
        filled: true,
        fillColor: AppColors.surfaceD.withValues(alpha: 0.5),
        hintStyle: TextStyle(
          fontSize: widget.textSize * 0.95,
          color: AppColors.textD.withValues(alpha: 0.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  // ── Suggestion builder ────────────────────────────────────────────────────

  List<_Suggestion> _buildSuggestions(List<String> parts) {
    final depth = parts.length;
    final input = parts.last;

    List<_Suggestion> filter(List<_Suggestion> all) {
      if (input.isEmpty) return all;
      return all.where((s) => s.word.startsWith(input) && s.word != input).toList();
    }

    switch (depth) {
      case 1:
        return filter([
          const _Suggestion('random', 'Random values'),
          const _Suggestion('request', 'Incoming request data'),
          const _Suggestion('customdata', 'Custom data store'),
          const _Suggestion('pagination', 'Pagination context'),
          const _Suggestion('math', 'Math expression'),
        ]);

      case 2:
        final cat = parts[0];
        if (cat == 'random') {
          return filter([
            const _Suggestion('uuid', 'Random UUID v4', closeBrace: true),
            const _Suggestion('name', 'Random full name', closeBrace: true),
            const _Suggestion('username', 'Random username', closeBrace: true),
            const _Suggestion('email', 'Random email', closeBrace: true),
            const _Suggestion('url', 'Random HTTP URL', closeBrace: true),
            const _Suggestion('phone', 'Random phone number', closeBrace: true),
            const _Suggestion('lorem', 'Lorem ipsum sentence', closeBrace: true),
            const _Suggestion('jwt', 'Random JWT token', closeBrace: true),
            const _Suggestion('date', 'Current UTC ISO date', closeBrace: true),
            const _Suggestion('integer', 'Random int (default max 100)'),
            const _Suggestion('double', 'Random double (default max 1.0)'),
            const _Suggestion('string', 'Random string (default len 20)'),
            const _Suggestion('image', 'Placeholder image URL'),
          ]);
        }
        if (cat == 'request') {
          return filter([
            const _Suggestion('url', 'Request URL data'),
            const _Suggestion('header', 'Request header value'),
            const _Suggestion('body', 'Request body field'),
          ]);
        }
        if (cat == 'customdata') {
          final keys = _customDataKeys();
          return filter([
            const _Suggestion('random', 'Random value from key'),
            ...keys.map((k) => _Suggestion(k, 'First value', closeBrace: true)),
          ]);
        }
        if (cat == 'pagination') {
          return filter([
            const _Suggestion('data', 'Paginated data', closeBrace: true),
            const _Suggestion('request', 'Request context'),
          ]);
        }
        return [];

      case 3:
        final cat2 = '${parts[0]}.${parts[1]}';
        if (cat2 == 'random.integer') return input.isEmpty ? [const _Suggestion('100', 'Max value', closeBrace: true)] : [];
        if (cat2 == 'random.double') return input.isEmpty ? [const _Suggestion('1.0', 'Max value', closeBrace: true)] : [];
        if (cat2 == 'random.string') return input.isEmpty ? [const _Suggestion('20', 'Length', closeBrace: true)] : [];
        if (cat2 == 'random.image') return input.isEmpty ? [const _Suggestion('600x400', 'Width x Height', closeBrace: true)] : [];
        if (cat2 == 'request.url') return filter([const _Suggestion('query', 'Query param by name'), const _Suggestion('path', 'Path segment by index')]);
        if (cat2 == 'request.header') return input.isEmpty ? [const _Suggestion('authorization', 'Header name', closeBrace: true)] : [];
        if (cat2 == 'request.body') return input.isEmpty ? [const _Suggestion('field', 'Body field name', closeBrace: true)] : [];
        if (cat2 == 'customdata.random') {
          final keys = _customDataKeys();
          return filter(keys.map((k) => _Suggestion(k, '', closeBrace: true)).toList());
        }
        if (parts[0] == 'customdata' && parts[1] != 'random') {
          final values = _customDataValues(parts[1]);
          return filter(values.map((v) => _Suggestion(v, 'value', closeBrace: true)).toList());
        }
        if (cat2 == 'pagination.request') return filter([const _Suggestion('url', '')]);
        return [];

      case 4:
        final cat3 = '${parts[0]}.${parts[1]}.${parts[2]}';
        if (cat3 == 'request.url.query' || cat3 == 'request.url.path') {
          return input.isEmpty
              ? [_Suggestion(cat3.endsWith('query') ? 'page' : '0', cat3.endsWith('query') ? 'Param name' : 'Segment index', closeBrace: true)]
              : [];
        }
        if (cat3 == 'pagination.request.url') return filter([const _Suggestion('query', '')]);
        return [];

      case 5:
        if (parts.take(4).join('.') == 'pagination.request.url.query') {
          return input.isEmpty ? [const _Suggestion('page', 'Param name', closeBrace: true)] : [];
        }
        return [];

      default:
        return [];
    }
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

// ── Suggestion list widget (stateful for hover) ───────────────────────────────

class _SuggestionList extends StatefulWidget {
  const _SuggestionList({
    required this.suggestions,
    required this.hoverIndex,
    required this.itemHeight,
    required this.visibleCount,
    required this.onHover,
    required this.onSelect,
  });

  final List<_Suggestion> suggestions;
  final int hoverIndex;
  final double itemHeight;
  final int visibleCount;
  final ValueChanged<int> onHover;
  final ValueChanged<int> onSelect;

  @override
  State<_SuggestionList> createState() => _SuggestionListState();
}

class _SuggestionListState extends State<_SuggestionList> {
  late int _hover;

  @override
  void initState() {
    super.initState();
    _hover = widget.hoverIndex;
  }

  @override
  void didUpdateWidget(_SuggestionList old) {
    super.didUpdateWidget(old);
    _hover = widget.hoverIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      height: widget.visibleCount * widget.itemHeight,
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
        itemCount: widget.suggestions.length,
        itemExtent: widget.itemHeight,
        itemBuilder: (_, i) {
          final s = widget.suggestions[i];
          final selected = i == _hover;
          return MouseRegion(
            onEnter: (_) => setState(() { _hover = i; widget.onHover(i); }),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => widget.onSelect(i),
              child: Container(
                color: selected
                    ? AppColors.secondaryD.withValues(alpha: 0.2)
                    : Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.data_object_rounded,
                      size: 11,
                      color: AppColors.secondaryD.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      s.word,
                      style: TextStyle(
                        color: AppColors.textD,
                        fontSize: AppTextSize.small,
                        fontFamily: 'monospace',
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    if (s.description.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s.description,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textD.withValues(alpha: 0.4),
                            fontSize: AppTextSize.badge,
                          ),
                        ),
                      ),
                    ],
                    if (s.closeBrace)
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
            ),
          );
        },
      ),
    );
  }
}
