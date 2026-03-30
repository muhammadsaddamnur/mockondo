import 'package:flutter/material.dart';
import 'package:mockondo/core/colors.dart';
import 'package:mockondo/core/log.dart';

/// A terminal-style log viewer that displays incoming HTTP requests for the
/// active mock server project.
///
/// Listens to [logNotifier] and auto-scrolls to the latest entry whenever the
/// list grows. Supports [didUpdateWidget] so the widget correctly re-subscribes
/// when the parent swaps to a different project's log notifier.
class TerminalWidget extends StatefulWidget {
  const TerminalWidget({super.key, required this.logNotifier});

  /// The reactive log list owned by the active project's [LogService].
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
    // Re-subscribe when the parent provides a different notifier (e.g. after
    // the user switches to another project).
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

  /// Scrolls to the bottom after the current frame so the ListView has already
  /// laid out the new item.
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
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs,
                      ),
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

// ── Header ────────────────────────────────────────────────────────────────────

/// Thin top bar with a green indicator dot, the "TERMINAL" label, entry count,
/// and a clear button.
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
          // Left: status dot + label
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.greenD,
                  shape: BoxShape.circle,
                ),
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
            ],
          ),
          const Spacer(),
          // Right: entry count + clear button (only when there are entries)
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

// ── Single log row ─────────────────────────────────────────────────────────────

/// Routes a [LogModel] to either [_SystemRow] or [_HttpRow] based on whether
/// [_ParsedLog] identifies it as a system event or an HTTP request.
class _LogRow extends StatelessWidget {
  const _LogRow({required this.log});
  final LogModel log;

  @override
  Widget build(BuildContext context) {
    final p = _ParsedLog.from(log);
    final ts = _formatTime(log.timestamp);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: 1,
      ),
      child: p.isSystem
          ? _SystemRow(timestamp: ts, message: p.raw, isError: p.isError)
          : _HttpRow(parsed: p, timestamp: ts),
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

// ── System message row ─────────────────────────────────────────────────────────

/// A plain one-line row for server start/stop or error messages.
/// Green for info, red for errors.
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
    return Row(
      children: [
        _ts(timestamp),
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
    );
  }
}

// ── HTTP request row ───────────────────────────────────────────────────────────

/// A structured row showing timestamp, colour-coded method badge, path,
/// status code badge, and response duration for a parsed HTTP log entry.
class _HttpRow extends StatelessWidget {
  const _HttpRow({required this.parsed, required this.timestamp});
  final _ParsedLog parsed;
  final String timestamp;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(parsed.statusCode);
    return Row(
      children: [
        _ts(timestamp),
        const SizedBox(width: AppSpacing.m),
        // Fixed-width method badge
        SizedBox(
          width: 52,
          child: Text(
            parsed.method ?? '???',
            style: TextStyle(
              color: _methodColor(parsed.method),
              fontSize: AppTextSize.small,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s),
        // Path takes remaining horizontal space
        Expanded(
          child: SelectableText(
            parsed.path ?? parsed.raw,
            style: TextStyle(
              color: AppColors.textD.withValues(alpha: 0.85),
              fontSize: AppTextSize.small,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.m),
        // Status code badge with tinted background
        if (parsed.statusCode != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              '${parsed.statusCode}',
              style: TextStyle(
                color: statusColor,
                fontSize: AppTextSize.small,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
          ),
        const SizedBox(width: AppSpacing.m),
        // Duration (right-aligned, fixed width)
        if (parsed.duration != null)
          SizedBox(
            width: 56,
            child: Text(
              parsed.duration!,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppColors.textD.withValues(alpha: 0.35),
                fontSize: AppTextSize.small,
                fontFamily: 'monospace',
              ),
            ),
          ),
      ],
    );
  }

  /// Colour per HTTP method — mirrors VS Code / Postman conventions.
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

  /// Colour per HTTP status code family.
  static Color _statusColor(int? code) {
    if (code == null) return const Color(0xFFABB2BF);
    if (code < 300) return const Color(0xFF98C379); // 2xx → green
    if (code < 400) return const Color(0xFF61AFEF); // 3xx → blue
    if (code < 500) return const Color(0xFFE5C07B); // 4xx → yellow
    return const Color(0xFFE06C75);                  // 5xx → red
  }
}

/// Dim timestamp label shared by all row types.
Widget _ts(String ts) => Text(
      ts,
      style: TextStyle(
        color: AppColors.textD.withValues(alpha: 0.25),
        fontSize: 10,
        fontFamily: 'monospace',
      ),
    );

// ── Log parser ─────────────────────────────────────────────────────────────────

/// Parses a raw [LogModel] message into structured fields.
///
/// Shelf's `logRequests` middleware emits lines in the form:
/// ```
/// GET "/api/users" 200 0:00:00.015261
/// ```
/// The regex extracts method, path, status code, and duration.
/// System messages (server start/stop events) are detected by their prefix
/// and routed to [_SystemRow] instead.
class _ParsedLog {
  const _ParsedLog({
    this.method,
    this.path,
    this.statusCode,
    this.duration,
    required this.raw,
    this.isError = false,
    this.isSystem = false,
  });

  final String? method;

  /// URL path only (host stripped), e.g. `/api/users?page=2`.
  final String? path;

  final int? statusCode;

  /// Human-readable duration string (e.g. `"15ms"`, `"1.2s"`).
  final String? duration;

  /// The original raw log message.
  final String raw;

  final bool isError;

  /// `true` for server lifecycle events rather than HTTP request logs.
  final bool isSystem;

  // Matches shelf's HTTP log format, optionally preceded by a timestamp.
  static final _httpRe = RegExp(
    r'(?:\d{4}-\d{2}-\d{2}T[\d:.]+Z?\s+)?'
    r'(GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS)\s+'
    r'"?([^"\s]+)"?\s+'
    r'(\d{3})\s+'
    r'(\S+)',
    caseSensitive: false,
  );

  factory _ParsedLog.from(LogModel log) {
    final msg = log.log.trim();

    // Detect system / lifecycle messages by their prefix or lack of spaces.
    if (!msg.contains(' ') ||
        msg.startsWith('✅') ||
        msg.startsWith('❌') ||
        msg.startsWith('Server')) {
      return _ParsedLog(
        raw: msg,
        isSystem: true,
        isError: log.status == Status.error,
      );
    }

    final m = _httpRe.firstMatch(msg);
    if (m != null) {
      final rawPath = m.group(2) ?? '';
      final path = _extractPath(rawPath);
      return _ParsedLog(
        method: m.group(1)!.toUpperCase(),
        path: path,
        statusCode: int.tryParse(m.group(3)!),
        duration: _formatDuration(m.group(4)!),
        raw: msg,
        isError: log.status == Status.error,
      );
    }

    // Unrecognised format — render as plain text (not a system message).
    return _ParsedLog(raw: msg, isError: log.status == Status.error);
  }

  /// Strips the host from a full URL to show only the path + query string.
  static String _extractPath(String url) {
    try {
      final uri = Uri.tryParse(url);
      if (uri != null && uri.host.isNotEmpty) {
        final q = uri.query.isEmpty ? '' : '?${uri.query}';
        return '${uri.path}$q';
      }
    } catch (_) {}
    return url;
  }

  /// Converts shelf's `Duration.toString()` format (`"0:00:00.015261"`) to a
  /// compact human-readable string (`"15ms"` or `"1.2s"`).
  /// Passes already-formatted strings (ending in `ms`/`s`) through unchanged.
  static String _formatDuration(String raw) {
    if (raw.endsWith('ms') || raw.endsWith('s')) return raw;
    try {
      final parts = raw.split(':');
      if (parts.length == 3) {
        final h = int.parse(parts[0]);
        final min = int.parse(parts[1]);
        final sec = double.parse(parts[2]);
        final ms = ((h * 3600 + min * 60 + sec) * 1000).round();
        if (ms < 1000) return '${ms}ms';
        return '${(ms / 1000).toStringAsFixed(1)}s';
      }
    } catch (_) {}
    return raw;
  }
}
