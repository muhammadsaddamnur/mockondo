import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mockondo/core/colors.dart';
import 'package:mockondo/core/widgets/app_tab_bar.dart';
import 'package:mockondo/core/widgets/custom_textfield.dart';
import 'package:mockondo/features/http_client/data/models/ws_client_model.dart';
import 'package:mockondo/features/http_client/presentation/controllers/ws_client_controller.dart';
import 'package:mockondo/features/http_client/presentation/widgets/key_value_table.dart';

/// The WebSocket client screen.
///
/// Layout mirrors [HttpClientPage]: a narrow saved-connections sidebar on the
/// left and the active-connection editor on the right.
class WsClientPage extends StatelessWidget {
  const WsClientPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(WsClientController());

    return Row(
      children: [
        // ── Sidebar ────────────────────────────────────────────────────
        SizedBox(
          width: 200,
          child: Column(
            children: [
              // Header row
              Padding(
                padding: const EdgeInsets.all(AppSpacing.m),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'WS Connections',
                        style: TextStyle(
                          color: AppColors.textD,
                          fontSize: AppTextSize.body,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: ctrl.addItem,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        child: Icon(
                          Icons.add,
                          size: 16,
                          color: AppColors.textD,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: AppColors.textD.withValues(alpha: 0.15),
              ),

              // Connection list
              Expanded(
                child: Obx(() {
                  if (ctrl.items.isEmpty) {
                    return Center(
                      child: Text(
                        'No connections.\nPress + to add one.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textD.withValues(alpha: 0.4),
                          fontSize: AppTextSize.small,
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: ctrl.items.length,
                    itemBuilder: (_, i) => _SidebarItem(ctrl: ctrl, index: i),
                  );
                }),
              ),
            ],
          ),
        ),

        VerticalDivider(
          width: 1,
          color: AppColors.textD.withValues(alpha: 0.15),
        ),

        // ── Main panel ────────────────────────────────────────────────
        Expanded(
          child: Obx(() {
            if (ctrl.items.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.sync_alt,
                      size: 36,
                      color: AppColors.textD.withValues(alpha: 0.2),
                    ),
                    const SizedBox(height: AppSpacing.l),
                    Text(
                      'Create a WebSocket connection to get started',
                      style: TextStyle(
                        color: AppColors.textD.withValues(alpha: 0.4),
                        fontSize: AppTextSize.body,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.m),
                    ElevatedButton(
                      onPressed: ctrl.addItem,
                      style: ButtonStyle(
                        elevation: const WidgetStatePropertyAll(0),
                      ),
                      child: const Text('New Connection'),
                    ),
                  ],
                ),
              );
            }
            final selectedIdx = ctrl.selectedIndex.value;
            return _ConnectionEditor(key: ValueKey(selectedIdx), ctrl: ctrl);
          }),
        ),
      ],
    );
  }
}

// ── Sidebar item ──────────────────────────────────────────────────────────────

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({required this.ctrl, required this.index});

  final WsClientController ctrl;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final item = ctrl.items[index];
      final isSelected = ctrl.selectedIndex.value == index;
      final isConnectedItem =
          isSelected && ctrl.connected.value;

      return GestureDetector(
        onSecondaryTapDown: (d) => _showMenu(context, d.globalPosition),
        child: InkWell(
          onTap: () => ctrl.selectItem(index),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.m,
              vertical: AppSpacing.s,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.secondaryD.withValues(alpha: 0.12)
                  : Colors.transparent,
              border: Border(
                left: BorderSide(
                  color: isSelected
                      ? AppColors.secondaryD
                      : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Row(
              children: [
                // Connection status dot
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isConnectedItem
                        ? const Color(0xFF4DFFD6)
                        : AppColors.textD.withValues(alpha: 0.25),
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: Text(
                    item.name.isEmpty ? 'New Connection' : item.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.textD
                          : AppColors.textD.withValues(alpha: 0.7),
                      fontSize: AppTextSize.small,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  void _showMenu(BuildContext context, Offset position) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      color: AppColors.backgroundD,
      items: [
        PopupMenuItem(
          onTap: () => ctrl.deleteItem(index),
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 13, color: AppColors.red),
              const SizedBox(width: AppSpacing.m),
              Text(
                'Delete',
                style: TextStyle(
                  color: AppColors.red,
                  fontSize: AppTextSize.body,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Connection editor ─────────────────────────────────────────────────────────

class _ConnectionEditor extends StatefulWidget {
  const _ConnectionEditor({super.key, required this.ctrl});
  final WsClientController ctrl;

  @override
  State<_ConnectionEditor> createState() => _ConnectionEditorState();
}

class _ConnectionEditorState extends State<_ConnectionEditor> {
  WsClientController get ctrl => widget.ctrl;

  final _urlCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _syncFields();
  }

  void _syncFields() {
    final item = ctrl.selected;
    if (item == null) return;
    _urlCtrl.text = item.url;
    _nameCtrl.text = item.name;
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _nameCtrl.dispose();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final item = ctrl.selected;
      if (item == null) return const SizedBox();

      final isConnected = ctrl.connected.value;

      // Scroll to bottom when messages change.
      if (ctrl.messages.isNotEmpty) _scrollToBottom();

      return Column(
        children: [
          // ── URL bar ────────────────────────────────────────────────
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.m,
              vertical: AppSpacing.s,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppColors.textD.withValues(alpha: 0.1),
                ),
              ),
            ),
            child: Row(
              children: [
                // Name (inline editable)
                SizedBox(
                  width: 140,
                  height: 32,
                  child: CustomTextField(
                    controller: _nameCtrl,
                    hintText: 'Connection name',
                    textSize: AppTextSize.small,
                    onChanged: (v) {
                      item.name = v;
                      ctrl.items.refresh();
                      ctrl.saveItems();
                    },
                  ),
                ),

                const SizedBox(width: AppSpacing.m),

                // URL field
                Expanded(
                  child: SizedBox(
                    height: 32,
                    child: CustomTextField(
                      controller: _urlCtrl,
                      hintText: 'ws://localhost:8081/ws',
                      readOnly: isConnected,
                      textSize: AppTextSize.body,
                      onChanged: (v) {
                        item.url = v;
                        ctrl.saveItems();
                      },
                    ),
                  ),
                ),

                const SizedBox(width: AppSpacing.m),

                // Connect / Disconnect button
                SizedBox(
                  height: 32,
                  child: ElevatedButton(
                    onPressed: isConnected ? ctrl.disconnect : ctrl.connect,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: isConnected
                          ? AppColors.red.withValues(alpha: 0.85)
                          : const Color(0xFF1A6B5E),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.l,
                      ),
                    ),
                    child: Text(
                      isConnected ? 'Disconnect' : 'Connect',
                      style: TextStyle(
                        color: isConnected
                            ? Colors.white
                            : const Color(0xFF4DFFD6),
                        fontSize: AppTextSize.body,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Error banner ──────────────────────────────────────────
          if (ctrl.errorMessage.value != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.m,
                vertical: AppSpacing.xs,
              ),
              color: AppColors.red.withValues(alpha: 0.12),
              child: Text(
                ctrl.errorMessage.value!,
                style: TextStyle(
                  color: AppColors.red,
                  fontSize: AppTextSize.small,
                ),
              ),
            ),

          // ── Tabs: Messages | Headers ──────────────────────────────
          AppTabBar(
            tabs: const ['Messages', 'Headers'],
            selected: _tab,
            onTap: (i) => setState(() => _tab = i),
          ),

          // ── Tab body ──────────────────────────────────────────────
          Expanded(
            child: _tab == 0
                ? _buildMessages(isConnected)
                : _buildHeaders(item),
          ),
        ],
      );
    });
  }

  // ── Messages tab ─────────────────────────────────────────────────────────────

  Widget _buildMessages(bool isConnected) {
    return Column(
      children: [
        // Message log
        Expanded(
          child: Obx(() {
            if (ctrl.messages.isEmpty) {
              return Center(
                child: Text(
                  isConnected
                      ? 'Connected. Send a message below.'
                      : 'Connect to start receiving messages.',
                  style: TextStyle(
                    color: AppColors.textD.withValues(alpha: 0.3),
                    fontSize: AppTextSize.small,
                  ),
                ),
              );
            }
            return ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(AppSpacing.m),
              itemCount: ctrl.messages.length,
              itemBuilder: (_, i) => _MessageBubble(msg: ctrl.messages[i]),
            );
          }),
        ),

        // Send bar
        Container(
          padding: const EdgeInsets.all(AppSpacing.m),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: AppColors.textD.withValues(alpha: 0.1),
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: CustomTextField(
                    controller: _msgCtrl,
                    hintText: 'Type a message…',
                    readOnly: !isConnected,
                    textSize: AppTextSize.body,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              SizedBox(
                height: 36,
                child: ElevatedButton(
                  onPressed: isConnected ? _sendMessage : null,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.l,
                    ),
                  ),
                  child: const Text(
                    'Send',
                    style: TextStyle(fontSize: AppTextSize.body),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _sendMessage() {
    ctrl.send(_msgCtrl.text.trim());
    _msgCtrl.clear();
  }

  // ── Headers tab ──────────────────────────────────────────────────────────────

  Widget _buildHeaders(WsClientItem item) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.m),
      child: KeyValueTable(
        pairs: item.headers,
        onChanged: (_) => ctrl.saveItems(),
      ),
    );
  }
}

// ── Message bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.msg});
  final WsMessage msg;

  @override
  Widget build(BuildContext context) {
    final isSent = msg.isSent;
    final isSystem = !isSent && (msg.text.startsWith('✅') ||
        msg.text.startsWith('🔌') ||
        msg.text.startsWith('❌'));

    if (isSystem) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Text(
          msg.text,
          style: TextStyle(
            color: AppColors.textD.withValues(alpha: 0.45),
            fontSize: AppTextSize.small,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isSent ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isSent) ...[
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1A6B5E),
              ),
              child: const Icon(
                Icons.dns_outlined,
                size: 13,
                color: Color(0xFF4DFFD6),
              ),
            ),
            const SizedBox(width: AppSpacing.s),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.m,
                vertical: AppSpacing.s,
              ),
              decoration: BoxDecoration(
                color: isSent
                    ? AppColors.secondaryD.withValues(alpha: 0.18)
                    : AppColors.surfaceD.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSent
                      ? AppColors.secondaryD.withValues(alpha: 0.3)
                      : AppColors.textD.withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                crossAxisAlignment: isSent
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.text,
                    style: TextStyle(
                      color: AppColors.textD,
                      fontSize: AppTextSize.body,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${msg.time.hour.toString().padLeft(2, '0')}:'
                    '${msg.time.minute.toString().padLeft(2, '0')}:'
                    '${msg.time.second.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: AppColors.textD.withValues(alpha: 0.3),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isSent) ...[
            const SizedBox(width: AppSpacing.s),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondaryD.withValues(alpha: 0.2),
              ),
              child: Icon(
                Icons.person_outline,
                size: 13,
                color: AppColors.secondaryD,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
