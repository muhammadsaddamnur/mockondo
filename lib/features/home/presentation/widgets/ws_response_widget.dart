import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mockondo/core/colors.dart';
import 'package:mockondo/core/mock_model.dart';
import 'package:mockondo/core/widgets/app_tab_bar.dart';
import 'package:mockondo/core/widgets/button_widget.dart';
import 'package:mockondo/core/widgets/custom_textfield.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';
import 'package:mockondo/features/home/presentation/controllers/home_controller.dart';
import 'package:re_editor/re_editor.dart';
import 'package:uuid/v4.dart';

/// Dialog for configuring a single [WsMockModel] endpoint.
///
/// Tab 0 — On Connect: optional message sent to the client on connect.
/// Tab 1 — Rules: ordered list of message-match → response pairs.
/// Tab 2 — Scheduled: time-based messages pushed to each connected client.
class WsResponseWidget extends StatefulWidget {
  final int wsIndex;

  const WsResponseWidget({super.key, required this.wsIndex});

  @override
  State<WsResponseWidget> createState() => _WsResponseWidgetState();
}

class _WsResponseWidgetState extends State<WsResponseWidget> {
  final homeController = Get.find<HomeController>();

  int _tab = 0;

  late CodeLineEditingController _onConnectCtrl;
  bool _onConnectEnabled = false;

  late List<_RuleRow> _rows;
  late List<_SchedRow> _schedRows;

  @override
  void initState() {
    super.initState();
    final model = _model;
    _onConnectEnabled = (model?.onConnectMessage?.isNotEmpty) ?? false;
    _onConnectCtrl = CodeLineEditingController()
      ..text = model?.onConnectMessage ?? '';
    _rows =
        (model?.rules ?? [])
            .map(
              (r) => _RuleRow(
                id: r.id,
                patternCtrl: CodeLineEditingController()..text = r.pattern,
                responseCtrl: CodeLineEditingController()..text = r.response,
                isRegex: r.isRegex,
              ),
            )
            .toList();
    _schedRows =
        (model?.scheduledMessages ?? [])
            .map(
              (s) => _SchedRow(
                id: s.id,
                enabled: s.enabled,
                messageCtrl: CodeLineEditingController()..text = s.message,
                delayCtrl: TextEditingController(text: s.delayMs.toString()),
                repeat: s.repeat,
                intervalCtrl: TextEditingController(
                  text: s.intervalMs.toString(),
                ),
              ),
            )
            .toList();
  }

  @override
  void dispose() {
    _onConnectCtrl.dispose();
    for (final r in _rows) {
      r.patternCtrl.dispose();
      r.responseCtrl.dispose();
    }
    for (final s in _schedRows) {
      s.messageCtrl.dispose();
      s.delayCtrl.dispose();
      s.intervalCtrl.dispose();
    }
    super.dispose();
  }

  WsMockModel? get _model =>
      homeController
          .mockModels[homeController.selectedMockModelIndex.value]
          ?.wsMockModels[widget.wsIndex];

  void _save() {
    final rules = _rows
        .map(
          (r) => WsMockRule(
            id: r.id,
            pattern: r.patternCtrl.text,
            isRegex: r.isRegex,
            response: r.responseCtrl.text,
          ),
        )
        .toList();

    final scheduled = _schedRows
        .map(
          (s) => WsScheduledMessage(
            id: s.id,
            enabled: s.enabled,
            message: s.messageCtrl.text,
            delayMs: int.tryParse(s.delayCtrl.text) ?? 1000,
            repeat: s.repeat,
            intervalMs: int.tryParse(s.intervalCtrl.text) ?? 5000,
          ),
        )
        .toList();

    final updated = _model?.copyWith(
      onConnectMessage: _onConnectEnabled ? _onConnectCtrl.text : null,
      rules: rules,
      scheduledMessages: scheduled,
    );
    if (updated != null) {
      homeController.saveWsEndpoint(widget.wsIndex, updated);
    }
    Navigator.pop(context);
  }


  @override
  Widget build(BuildContext context) {
    return Container(
      width: 680,
      height: 560,
      decoration: BoxDecoration(
        color: AppColors.backgroundD,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.textD.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppColors.textD.withValues(alpha: 0.1),
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.sync_alt, size: 16, color: Color(0xFF4DFFD6)),
                const SizedBox(width: AppSpacing.s),
                Text(
                  'WebSocket Config  —  ${_model?.endpoint ?? ''}',
                  style: const TextStyle(
                    color: Color(0xFF4DFFD6),
                    fontSize: AppTextSize.body,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(4),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: AppColors.textD.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),

          // Tabs
          AppTabBar(
            tabs: const ['On Connect', 'Rules', 'Scheduled'],
            selected: _tab,
            onTap: (i) => setState(() => _tab = i),
          ),

          // Body
          Expanded(
            child: _tab == 0
                ? _buildOnConnect()
                : _tab == 1
                ? _buildRules()
                : _buildScheduled(),
          ),

          // Footer
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.textD.withValues(alpha: 0.1)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: AppColors.textD.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                ButtonWidget(
                  onTap: () async {
                    _save();
                  },
                  color: AppColors.secondaryD,
                  child: const Text(
                    'Save Changes',
                    style: TextStyle(fontSize: AppTextSize.body),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 0: On Connect ────────────────────────────────────────────────────────

  Widget _buildOnConnect() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toggle
          Row(
            children: [
              InkWell(
                onTap: () =>
                    setState(() => _onConnectEnabled = !_onConnectEnabled),
                borderRadius: BorderRadius.circular(4),
                child: Icon(
                  _onConnectEnabled
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  size: 18,
                  color: _onConnectEnabled
                      ? const Color(0xFF4DFFD6)
                      : AppColors.textD.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              Text(
                'Send message on client connect',
                style: TextStyle(
                  color: AppColors.textD.withValues(alpha: 0.8),
                  fontSize: AppTextSize.body,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => Opacity(
                opacity: _onConnectEnabled ? 1.0 : 0.35,
                child: AbsorbPointer(
                  absorbing: !_onConnectEnabled,
                  child: _WsCodeField(
                    controller: _onConnectCtrl,
                    hintText: '{"event":"connected"}',
                    height: constraints.maxHeight,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 1: Rules ─────────────────────────────────────────────────────────────

  Widget _buildRules() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.m,
            vertical: AppSpacing.s,
          ),
          child: Row(
            children: [
              Text(
                'Rules are matched in order. First match wins.',
                style: TextStyle(
                  color: AppColors.textD.withValues(alpha: 0.45),
                  fontSize: AppTextSize.small,
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 28,
                child: ButtonWidget(
                  onTap: () async {
                    setState(() {
                      _rows.add(
                        _RuleRow(
                          id: UuidV4().generate(),
                          patternCtrl: CodeLineEditingController(),
                          responseCtrl: CodeLineEditingController(),
                          isRegex: false,
                        ),
                      );
                    });
                  },
                  color: AppColors.secondaryD,
                  child: const Text(
                    'Add Rule',
                    style: TextStyle(fontSize: AppTextSize.small),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _rows.isEmpty
              ? Center(
                  child: Text(
                    'No rules. Add one to auto-reply to messages.',
                    style: TextStyle(
                      color: AppColors.textD.withValues(alpha: 0.3),
                      fontSize: AppTextSize.small,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
                  itemCount: _rows.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.s),
                  itemBuilder: (_, i) => _buildRuleRow(i),
                ),
        ),
      ],
    );
  }

  Widget _buildRuleRow(int i) {
    final row = _rows[i];
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s),
      decoration: BoxDecoration(
        color: AppColors.surfaceD.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.textD.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: regex toggle + delete
          Row(
            children: [
              Tooltip(
                message: 'Use regex',
                child: InkWell(
                  onTap: () => setState(() => row.isRegex = !row.isRegex),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: 2,
                    ),
                    child: Text(
                      '.*  regex',
                      style: TextStyle(
                        color: row.isRegex
                            ? const Color(0xFF4DFFD6)
                            : AppColors.textD.withValues(alpha: 0.35),
                        fontSize: AppTextSize.small,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => setState(() => _rows.removeAt(i)),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: Icon(
                    Icons.delete_outline,
                    size: 16,
                    color: AppColors.textD.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          // Pattern editor
          _WsCodeField(
            controller: row.patternCtrl,
            hintText: row.isRegex ? 'regex pattern' : 'exact message',
            height: 90,
          ),
          // Arrow divider
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: [
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  Icons.arrow_downward,
                  size: 13,
                  color: AppColors.textD.withValues(alpha: 0.3),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'response',
                  style: TextStyle(
                    fontSize: AppTextSize.small,
                    color: AppColors.textD.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ),
          // Response editor
          _WsCodeField(
            controller: row.responseCtrl,
            hintText: 'response message',
            height: 90,
          ),
        ],
      ),
    );
  }

  // ── Tab 2: Scheduled ─────────────────────────────────────────────────────────

  Widget _buildScheduled() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.m,
            vertical: AppSpacing.s,
          ),
          child: Row(
            children: [
              Text(
                'Messages pushed automatically to each connected client.',
                style: TextStyle(
                  color: AppColors.textD.withValues(alpha: 0.45),
                  fontSize: AppTextSize.small,
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 28,
                child: ButtonWidget(
                  onTap: () async {
                    setState(() {
                      _schedRows.add(
                        _SchedRow(
                          id: UuidV4().generate(),
                          enabled: true,
                          messageCtrl: CodeLineEditingController(),
                          delayCtrl: TextEditingController(text: '1000'),
                          repeat: false,
                          intervalCtrl: TextEditingController(text: '5000'),
                        ),
                      );
                    });
                  },
                  color: AppColors.secondaryD,
                  child: const Text(
                    'Add Scheduled Message',
                    style: TextStyle(fontSize: AppTextSize.small),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _schedRows.isEmpty
              ? Center(
                  child: Text(
                    'No scheduled messages. Add one to push messages on a timer.',
                    style: TextStyle(
                      color: AppColors.textD.withValues(alpha: 0.3),
                      fontSize: AppTextSize.small,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
                  itemCount: _schedRows.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.s),
                  itemBuilder: (_, i) => _buildSchedRow(i),
                ),
        ),
      ],
    );
  }

  Widget _buildSchedRow(int i) {
    final row = _schedRows[i];
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s),
      decoration: BoxDecoration(
        color: AppColors.surfaceD.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.textD.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: enable + timing settings + delete
          Row(
            children: [
              InkWell(
                onTap: () => setState(() => row.enabled = !row.enabled),
                borderRadius: BorderRadius.circular(4),
                child: Icon(
                  row.enabled
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  size: 16,
                  color: row.enabled
                      ? const Color(0xFF4DFFD6)
                      : AppColors.textD.withValues(alpha: 0.3),
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              Icon(
                Icons.schedule,
                size: 13,
                color: AppColors.textD.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 4),
              Text(
                'After',
                style: TextStyle(
                  fontSize: AppTextSize.small,
                  color: AppColors.textD.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              SizedBox(
                width: 70,
                height: 26,
                child: CustomTextField(
                  controller: row.delayCtrl,
                  hintText: '1000',
                  keyboardType: TextInputType.number,
                  textSize: AppTextSize.small,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'ms',
                style: TextStyle(
                  fontSize: AppTextSize.small,
                  color: AppColors.textD.withValues(alpha: 0.45),
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              InkWell(
                onTap: () => setState(() => row.repeat = !row.repeat),
                borderRadius: BorderRadius.circular(4),
                child: Row(
                  children: [
                    Icon(
                      Icons.repeat,
                      size: 14,
                      color: row.repeat
                          ? const Color(0xFF4DFFD6)
                          : AppColors.textD.withValues(alpha: 0.35),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Repeat',
                      style: TextStyle(
                        fontSize: AppTextSize.small,
                        color: row.repeat
                            ? const Color(0xFF4DFFD6)
                            : AppColors.textD.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),
              if (row.repeat) ...[
                const SizedBox(width: AppSpacing.m),
                Text(
                  'every',
                  style: TextStyle(
                    fontSize: AppTextSize.small,
                    color: AppColors.textD.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                SizedBox(
                  width: 70,
                  height: 26,
                  child: CustomTextField(
                    controller: row.intervalCtrl,
                    hintText: '5000',
                    keyboardType: TextInputType.number,
                    textSize: AppTextSize.small,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'ms',
                  style: TextStyle(
                    fontSize: AppTextSize.small,
                    color: AppColors.textD.withValues(alpha: 0.45),
                  ),
                ),
              ],
              const Spacer(),
              InkWell(
                onTap: () => setState(() => _schedRows.removeAt(i)),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: Icon(
                    Icons.delete_outline,
                    size: 16,
                    color: AppColors.textD.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s),
          // Message code editor
          _WsCodeField(
            controller: row.messageCtrl,
            hintText: 'message to send',
            height: 90,
          ),
        ],
      ),
    );
  }
}

/// Internal state for a single rule row in the Rules tab.
class _RuleRow {
  final String id;
  final CodeLineEditingController patternCtrl;
  final CodeLineEditingController responseCtrl;
  bool isRegex;

  _RuleRow({
    required this.id,
    required this.patternCtrl,
    required this.responseCtrl,
    required this.isRegex,
  });
}

/// Internal state for a single scheduled-message row in the Scheduled tab.
class _SchedRow {
  final String id;
  bool enabled;
  final CodeLineEditingController messageCtrl;
  final TextEditingController delayCtrl;
  bool repeat;
  final TextEditingController intervalCtrl;

  _SchedRow({
    required this.id,
    required this.enabled,
    required this.messageCtrl,
    required this.delayCtrl,
    required this.repeat,
    required this.intervalCtrl,
  });
}

/// Lightweight code editor for WS dialog fields.
///
/// Mirrors [CustomJsonTextField]'s layout (Container > Column > Expanded >
/// CodeEditor) but strips CodeAutocomplete, JSON highlighting, and the
/// Beautify button to avoid keystroke lag.
class _WsCodeField extends StatelessWidget {
  final CodeLineEditingController controller;
  final String? hintText;
  final double height;

  const _WsCodeField({
    required this.controller,
    this.hintText,
    this.height = 90,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceD.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        children: [
          Expanded(
            child: CodeEditor(
              controller: controller,
              hint: hintText,
              style: CodeEditorStyle(
                codeTheme: CodeHighlightTheme(
                  languages: {'json': CodeHighlightThemeMode(mode: langJson)},
                  theme: atomOneDarkTheme,
                ),
                hintTextColor: AppColors.textD.withValues(alpha: 0.5),
                fontSize: AppTextSize.body,
                fontFamily: 'monospace',
                backgroundColor: Colors.transparent,
              ),
              indicatorBuilder: (_, editing, chunk, notifier) => Row(
                children: [
                  DefaultCodeLineNumber(
                    controller: editing,
                    notifier: notifier,
                    textStyle: TextStyle(
                      color: AppColors.textD.withValues(alpha: 0.35),
                      fontSize: AppTextSize.small,
                    ),
                    focusedTextStyle: TextStyle(
                      color: AppColors.textD.withValues(alpha: 0.6),
                      fontSize: AppTextSize.small,
                    ),
                  ),
                  DefaultCodeChunkIndicator(
                    width: 14,
                    controller: chunk,
                    notifier: notifier,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
