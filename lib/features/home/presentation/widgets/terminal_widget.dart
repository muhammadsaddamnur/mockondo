import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mockondo/core/colors.dart';
import 'package:mockondo/core/log.dart';

/// A terminal-style log viewer that displays incoming HTTP requests for the
/// active mock server project.
class TerminalWidget extends StatefulWidget {
  const TerminalWidget({super.key, required this.logNotifier});

  final ValueNotifier<List<LogModel>> logNotifier;

  @override
  State<TerminalWidget> createState() => _TerminalWidgetState();
}

class _TerminalWidgetState extends State<TerminalWidget> {
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.logNotifier.addListener(_onLogsChanged);
  }

  @override
  void didUpdateWidget(TerminalWidget old) {
    super.didUpdateWidget(old);
    if (old.logNotifier != widget.logNotifier) {
      old.logNotifier.removeListener(_onLogsChanged);
      widget.logNotifier.addListener(_onLogsChanged);
    }
  }

  @override
  void dispose() {
    widget.logNotifier.removeListener(_onLogsChanged);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onLogsChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<LogModel>>(
      valueListenable: widget.logNotifier,
      builder: (_, logs, __) {
        return Column(
          children: [
            _Header(logs: logs),
            Expanded(
              child: logs.isEmpty
                  ? Center(
                      child: Text(
                        'No requests yet',
                        style: TextStyle(
                          color: AppColors.textD.withValues(alpha: 0.25),
                          fontSize: AppTextSize.small,
                          fontFamily: 'monospace',
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                      itemCount: logs.length,
                      itemBuilder: (_, i) => _LogRow(log: logs[i]),
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.logs});
  final List<LogModel> logs;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
      decoration: BoxDecoration(
        color: AppColors.terminalD,
        border: Border(
          bottom: BorderSide(color: AppColors.textD.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: AppColors.greenD, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.s),
          Text(
            'TERMINAL',
            style: TextStyle(
              color: AppColors.textD.withValues(alpha: 0.5),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              fontFamily: 'monospace',
            ),
          ),
          const Spacer(),
          if (logs.isNotEmpty) ...[
            Text(
              '${logs.length} entries',
              style: TextStyle(
                color: AppColors.textD.withValues(alpha: 0.25),
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: AppSpacing.m),
            InkWell(
              onTap: LogService().clear,
              borderRadius: BorderRadius.circular(3),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Icon(
                  Icons.delete_outline_rounded,
                  size: 13,
                  color: AppColors.textD.withValues(alpha: 0.35),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Log row (routes to system or HTTP) ────────────────────────────────────────

class _LogRow extends StatelessWidget {
  const _LogRow({required this.log});
  final LogModel log;

  @override
  Widget build(BuildContext context) {
    final ts = _formatTime(log.timestamp);
    if (log.isHttpEntry) {
      return _HttpRow(log: log, timestamp: ts);
    }
    return _SystemRow(
      timestamp: ts,
      message: log.log,
      isError: log.status == Status.error,
    );
  }

  static String _formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    final s = t.second.toString().padLeft(2, '0');
    final ms = t.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }
}

// ── System row ─────────────────────────────────────────────────────────────────

class _SystemRow extends StatelessWidget {
  const _SystemRow({
    required this.timestamp,
    required this.message,
    required this.isError,
  });
  final String timestamp;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: 1),
      child: Row(
        children: [
          _Ts(timestamp),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: SelectableText(
              message,
              style: TextStyle(
                color: isError
                    ? AppColors.red.withValues(alpha: 0.85)
                    : AppColors.greenD.withValues(alpha: 0.85),
                fontSize: AppTextSize.small,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── HTTP row (expandable) ─────────────────────────────────────────────────────

class _HttpRow extends StatefulWidget {
  const _HttpRow({required this.log, required this.timestamp});
  final LogModel log;
  final String timestamp;

  @override
  State<_HttpRow> createState() => _HttpRowState();
}

class _HttpRowState extends State<_HttpRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final log = widget.log;
    final statusColor = _statusColor(log.statusCode);
    final methodColor = _methodColor(log.method);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Summary line ────────────────────────────────────────────
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.m, vertical: 2),
            child: Row(
              children: [
                _Ts(widget.timestamp),
                const SizedBox(width: AppSpacing.m),
                // Expand indicator
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_right_rounded,
                  size: 12,
                  color: AppColors.textD.withValues(alpha: 0.3),
                ),
                const SizedBox(width: AppSpacing.xs),
                // Method badge
                SizedBox(
                  width: 52,
                  child: Text(
                    log.method ?? '???',
                    style: TextStyle(
                      color: methodColor,
                      fontSize: AppTextSize.small,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                // Path
                Expanded(
                  child: SelectableText(
                    log.path ?? '',
                    style: TextStyle(
                      color: AppColors.textD.withValues(alpha: 0.85),
                      fontSize: AppTextSize.small,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.m),
                // Status badge
                if (log.statusCode != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      '${log.statusCode}',
                      style: TextStyle(
                        color: statusColor,
                        fontSize: AppTextSize.small,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                const SizedBox(width: AppSpacing.m),
                // Duration
                if (log.durationMs != null)
                  SizedBox(
                    width: 56,
                    child: Text(
                      '${log.durationMs}ms',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: AppColors.textD.withValues(alpha: 0.35),
                        fontSize: AppTextSize.small,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // ── Expanded detail panel ────────────────────────────────────
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(
                left: AppSpacing.xl, right: AppSpacing.m, bottom: AppSpacing.s, top: AppSpacing.s),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceD.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: AppColors.textD.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // REQUEST section
                  _SectionHeader(label: 'REQUEST'),
                  if (log.requestHeaders != null &&
                      log.requestHeaders!.isNotEmpty)
                    _DetailBlock(
                      label: 'Headers',
                      content: log.requestHeaders!.entries
                          .map((e) => '${e.key}: ${e.value}')
                          .join('\n'),
                    ),
                  if (log.requestBody != null && log.requestBody!.isNotEmpty)
                    _DetailBlock(
                      label: 'Body',
                      content: _prettyJson(log.requestBody!),
                    ),
                  if ((log.requestHeaders == null ||
                          log.requestHeaders!.isEmpty) &&
                      (log.requestBody == null || log.requestBody!.isEmpty))
                    _EmptyHint(text: 'No request body or headers'),

                  // RESPONSE section
                  _SectionHeader(label: 'RESPONSE'),
                  if (log.responseHeaders != null &&
                      log.responseHeaders!.isNotEmpty)
                    _DetailBlock(
                      label: 'Headers',
                      content: log.responseHeaders!.entries
                          .map((e) => '${e.key}: ${e.value}')
                          .join('\n'),
                    ),
                  if (log.responseBody != null && log.responseBody!.isNotEmpty)
                    _DetailBlock(
                      label: 'Body',
                      content: _prettyJson(log.responseBody!),
                    ),
                  if ((log.responseHeaders == null ||
                          log.responseHeaders!.isEmpty) &&
                      (log.responseBody == null || log.responseBody!.isEmpty))
                    _EmptyHint(text: 'No response body'),
                ],
              ),
            ),
          ),
      ],
    );
  }

  static String _prettyJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return raw;
    }
  }

  static Color _methodColor(String? method) {
    switch (method) {
      case 'GET':    return const Color(0xFF61AFEF);
      case 'POST':   return const Color(0xFF98C379);
      case 'PUT':    return const Color(0xFFE5C07B);
      case 'PATCH':  return const Color(0xFFD19A66);
      case 'DELETE': return const Color(0xFFE06C75);
      case 'HEAD':   return const Color(0xFF56B6C2);
      default:       return const Color(0xFFABB2BF);
    }
  }

  static Color _statusColor(int? code) {
    if (code == null) return const Color(0xFFABB2BF);
    if (code < 300) return const Color(0xFF98C379);
    if (code < 400) return const Color(0xFF61AFEF);
    if (code < 500) return const Color(0xFFE5C07B);
    return const Color(0xFFE06C75);
  }
}

// ── Detail sub-widgets ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(color: AppColors.textD.withValues(alpha: 0.07))),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.textD.withValues(alpha: 0.4),
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({required this.label, required this.content});
  final String label;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.m, AppSpacing.s, AppSpacing.m, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: AppColors.textD.withValues(alpha: 0.35),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  fontFamily: 'monospace',
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () =>
                    Clipboard.setData(ClipboardData(text: content)),
                borderRadius: BorderRadius.circular(3),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.copy_rounded,
                    size: 11,
                    color: AppColors.textD.withValues(alpha: 0.25),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          SelectableText(
            content,
            style: TextStyle(
              color: AppColors.textD.withValues(alpha: 0.75),
              fontSize: AppTextSize.small,
              fontFamily: 'monospace',
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.s),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m, vertical: AppSpacing.s),
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.textD.withValues(alpha: 0.2),
          fontSize: AppTextSize.small,
          fontFamily: 'monospace',
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

// ── Shared timestamp widget ───────────────────────────────────────────────────

class _Ts extends StatelessWidget {
  const _Ts(this.ts);
  final String ts;

  @override
  Widget build(BuildContext context) {
    return Text(
      ts,
      style: TextStyle(
        color: AppColors.textD.withValues(alpha: 0.25),
        fontSize: 10,
        fontFamily: 'monospace',
      ),
    );
  }
}
