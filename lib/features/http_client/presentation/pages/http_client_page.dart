import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mockondo/core/colors.dart';
import 'package:mockondo/core/curl_utils.dart';
import 'package:mockondo/core/interpolation.dart';
import 'package:mockondo/core/widgets/app_tab_bar.dart';
import 'package:mockondo/core/widgets/button_widget.dart';
import 'package:mockondo/core/widgets/custom_json_textfield.dart';
import 'package:mockondo/core/widgets/custom_textfield.dart';
import 'package:mockondo/core/widgets/interpolation_textfield.dart';
import 'package:mockondo/features/http_client/data/models/http_client_model.dart';
import 'package:mockondo/features/http_client/presentation/controllers/http_client_controller.dart';
import 'package:mockondo/features/http_client/presentation/pages/ws_client_page.dart';
import 'package:mockondo/features/http_client/presentation/widgets/key_value_table.dart';
import 'package:re_editor/re_editor.dart';

class HttpClientPage extends StatefulWidget {
  const HttpClientPage({super.key});

  @override
  State<HttpClientPage> createState() => _HttpClientPageState();
}

class _HttpClientPageState extends State<HttpClientPage> {
  double _sidebarWidth = 200;

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(HttpClientController());
    return Obx(() {
      final tab = ctrl.clientTab.value;
      // If WebSocket tab is active, delegate entirely to WsClientPage.
      if (tab == 1) {
        return Column(
          children: [
            _ClientTabBar(
              selected: tab,
              onTap: (i) => ctrl.clientTab.value = i,
            ),
            const Expanded(child: WsClientPage()),
          ],
        );
      }

      return Column(
      children: [
        // ── HTTP / WebSocket tab switcher ─────────────────────────────
        _ClientTabBar(
          selected: tab,
          onTap: (i) => ctrl.clientTab.value = i,
        ),
        Expanded(
          child: Row(
      children: [
        // ── Left sidebar: saved requests ──────────────────────────────
        SizedBox(
          width: _sidebarWidth,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.m),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Requests',
                        style: TextStyle(
                          color: AppColors.textD,
                          fontSize: AppTextSize.body,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => _showImportCurlDialog(context, ctrl),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        child: Icon(
                          Icons.content_paste_rounded,
                          size: 14,
                          color: AppColors.textD.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    InkWell(
                      onTap: () => _showAddGroupDialog(ctrl),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        child: Icon(
                          Icons.create_new_folder_outlined,
                          size: 14,
                          color: AppColors.textD.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    InkWell(
                      onTap: () => ctrl.addRequest(),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        child: Icon(
                          Icons.add,
                          size: 16,
                          color: AppColors.greenD
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppColors.textD.withValues(alpha: 0.15)),
              Expanded(
                child: _SidebarList(
                  ctrl: ctrl,
                  onRequestContextMenu: _showContextMenu,
                  onGroupContextMenu: _showGroupContextMenu,
                ),
              ),
            ],
          ),
        ),

        // ── Resizable divider ──────────────────────────────────────────
        MouseRegion(
          cursor: SystemMouseCursors.resizeColumn,
          child: GestureDetector(
            onHorizontalDragUpdate: (d) {
              setState(() {
                _sidebarWidth = (_sidebarWidth + d.delta.dx).clamp(140.0, 400.0);
              });
            },
            child: Container(
              width: 5,
              color: Colors.transparent,
              child: VerticalDivider(width: 1, color: AppColors.textD.withValues(alpha: 0.15)),
            ),
          ),
        ),

        // ── Main: request editor + response ──────────────────────────
        Expanded(
          child: Obx(() {
            if (ctrl.requests.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.send_outlined,
                      size: 36,
                      color: AppColors.textD.withValues(alpha: 0.2),
                    ),
                    const SizedBox(height: AppSpacing.l),
                    Text(
                      'Create a request to get started',
                      style: TextStyle(
                        color: AppColors.textD.withValues(alpha: 0.4),
                        fontSize: AppTextSize.body,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.m),
                    ElevatedButton(
                      onPressed: ctrl.addRequest,
                      style: ButtonStyle(elevation: WidgetStatePropertyAll(0)),
                      child: const Text('New Request'),
                    ),
                  ],
                ),
              );
            }
            return _RequestEditor(ctrl: ctrl);
          }),
        ),
      ],
    ),        // Row
          ),  // Expanded
        ],
      );      // Column
    });       // Obx
  }

  void _showImportCurlDialog(BuildContext context, HttpClientController ctrl) {
    final textCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 540,
          decoration: BoxDecoration(
            color: AppColors.backgroundD,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.l, AppSpacing.m, AppSpacing.l),
                child: Row(
                  children: [
                    Icon(Icons.content_paste_rounded, size: 16, color: AppColors.textD),
                    const SizedBox(width: AppSpacing.m),
                    Expanded(
                      child: Text(
                        'Import cURL',
                        style: TextStyle(
                          color: AppColors.textD,
                          fontSize: AppTextSize.title,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(ctx),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.s),
                        child: Icon(Icons.close, size: 14, color: AppColors.textD.withValues(alpha: 0.5)),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppColors.textD.withValues(alpha: 0.12)),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: TextField(
                  controller: textCtrl,
                  maxLines: 6,
                  style: TextStyle(color: AppColors.textD, fontSize: AppTextSize.small, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: "curl -X POST 'https://example.com/api' \\\n  -H 'Content-Type: application/json' \\\n  --data-raw '{\"key\": \"value\"}'",
                    hintStyle: TextStyle(color: AppColors.textD.withValues(alpha: 0.3), fontSize: AppTextSize.small),
                    filled: true,
                    fillColor: AppColors.surfaceD.withValues(alpha: 0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide: BorderSide(color: AppColors.textD.withValues(alpha: 0.15)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide: BorderSide(color: AppColors.textD.withValues(alpha: 0.15)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                      borderSide: BorderSide(color: AppColors.secondaryD.withValues(alpha: 0.6)),
                    ),
                    contentPadding: const EdgeInsets.all(AppSpacing.m),
                  ),
                ),
              ),
              Divider(height: 1, color: AppColors.textD.withValues(alpha: 0.12)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.m),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Cancel', style: TextStyle(color: AppColors.textD.withValues(alpha: 0.6), fontSize: AppTextSize.body)),
                    ),
                    const SizedBox(width: AppSpacing.m),
                    ElevatedButton(
                      onPressed: () {
                        final item = CurlUtils.parse(textCtrl.text.trim());
                        if (item != null) {
                          ctrl.requests.add(item);
                          ctrl.selectedIndex.value = ctrl.requests.length - 1;
                          ctrl.response.value = null;
                          ctrl.errorMessage.value = null;
                          ctrl.saveRequests();
                        }
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondaryD,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                      ),
                      child: const Text('Import', style: TextStyle(color: Colors.white, fontSize: AppTextSize.body)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContextMenu(
    BuildContext context,
    HttpClientController ctrl,
    int index,
    Offset position, {
    Set<String> selectedIds = const {},
    VoidCallback? onClearSelection,
  }) {
    final req = ctrl.requests[index];
    final hasMultiSelection = selectedIds.length > 1 && selectedIds.contains(req.id);
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      color: AppColors.backgroundD,
      items: [
        if (hasMultiSelection)
          PopupMenuItem(
            onTap: () {
              final ids = selectedIds.toList();
              final emptyGroupIds = ctrl.groups
                  .where((g) {
                    final groupReqs = ctrl.requests.where((r) => r.groupId == g.id).toList();
                    return groupReqs.isNotEmpty &&
                        groupReqs.every((r) => ids.contains(r.id));
                  })
                  .map((g) => g.id)
                  .toList();
              ctrl.deleteRequests(ids);
              for (final gid in emptyGroupIds) {
                ctrl.deleteGroup(gid);
              }
              onClearSelection?.call();
            },
            child: Row(children: [
              Icon(Icons.delete_sweep_outlined, size: 13, color: AppColors.red),
              const SizedBox(width: AppSpacing.m),
              Text('Delete ${selectedIds.length} selected', style: TextStyle(color: AppColors.red, fontSize: AppTextSize.body)),
            ]),
          ),
        if (hasMultiSelection)
          PopupMenuItem(
            onTap: () {
              for (final id in selectedIds) {
                final idx = ctrl.requests.indexWhere((r) => r.id == id);
                if (idx != -1) ctrl.duplicateRequest(idx);
              }
            },
            child: Row(children: [
              Icon(Icons.copy, size: 13, color: AppColors.textD),
              const SizedBox(width: AppSpacing.m),
              Text('Duplicate ${selectedIds.length} selected', style: TextStyle(color: AppColors.textD, fontSize: AppTextSize.body)),
            ]),
          )
        else
          PopupMenuItem(
            onTap: () => ctrl.duplicateRequest(index),
            child: Row(children: [
              Icon(Icons.copy, size: 13, color: AppColors.textD),
              const SizedBox(width: AppSpacing.m),
              Text('Duplicate', style: TextStyle(color: AppColors.textD, fontSize: AppTextSize.body)),
            ]),
          ),
        if (ctrl.groups.isNotEmpty)
          PopupMenuItem(
            onTap: () => _showMoveToGroupDialog(ctrl, index),
            child: Row(children: [
              Icon(Icons.drive_file_move_outlined, size: 13, color: AppColors.textD),
              const SizedBox(width: AppSpacing.m),
              Text(req.groupId != null ? 'Move / remove from group' : 'Move to group',
                  style: TextStyle(color: AppColors.textD, fontSize: AppTextSize.body)),
            ]),
          ),
        if(!hasMultiSelection)
          PopupMenuItem(
            onTap: () => ctrl.deleteRequest(index),
            child: Row(children: [
              Icon(Icons.delete_outline, size: 13, color: AppColors.red),
              const SizedBox(width: AppSpacing.m),
              Text('Delete', style: TextStyle(color: AppColors.red, fontSize: AppTextSize.body)),
            ]),
          ),
      ],
    );
  }

  void _showGroupContextMenu(
    BuildContext context,
    HttpClientController ctrl,
    HttpRequestGroup group,
    Offset position,
  ) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      color: AppColors.backgroundD,
      items: [
        PopupMenuItem(
          onTap: () => _showRenameGroupDialog(ctrl, group),
          child: Row(children: [
            Icon(Icons.edit_outlined, size: 13, color: AppColors.textD),
            const SizedBox(width: AppSpacing.m),
            Text('Rename', style: TextStyle(color: AppColors.textD, fontSize: AppTextSize.body)),
          ]),
        ),
        PopupMenuItem(
          onTap: () => ctrl.deleteGroup(group.id),
          child: Row(children: [
            Icon(Icons.folder_delete_outlined, size: 13, color: AppColors.red),
            const SizedBox(width: AppSpacing.m),
            Text('Delete group', style: TextStyle(color: AppColors.red, fontSize: AppTextSize.body)),
          ]),
        ),
        PopupMenuItem(
          onTap: () => ctrl.deleteGroup(group.id, deleteRequests: true),
          child: Row(children: [
            Icon(Icons.delete_sweep_outlined, size: 13, color: AppColors.red),
            const SizedBox(width: AppSpacing.m),
            Text('Delete group & requests', style: TextStyle(color: AppColors.red, fontSize: AppTextSize.body)),
          ]),
        ),
      ],
    );
  }

  void _showAddGroupDialog(HttpClientController ctrl) {
    final textCtrl = TextEditingController();
    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 320,
          decoration: BoxDecoration(
            color: AppColors.backgroundD,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.l, AppSpacing.m, AppSpacing.l),
                child: Text('New Group',
                    style: TextStyle(color: AppColors.textD, fontSize: AppTextSize.title, fontWeight: FontWeight.bold)),
              ),
              Divider(height: 1, color: AppColors.textD.withValues(alpha: 0.12)),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: TextField(
                  controller: textCtrl,
                  autofocus: true,
                  style: TextStyle(color: AppColors.textD, fontSize: AppTextSize.body),
                  decoration: InputDecoration(
                    hintText: 'Group name',
                    hintStyle: TextStyle(color: AppColors.textD.withValues(alpha: 0.3)),
                    filled: true,
                    fillColor: AppColors.surfaceD.withValues(alpha: 0.5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(5), borderSide: BorderSide(color: AppColors.textD.withValues(alpha: 0.15))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(5), borderSide: BorderSide(color: AppColors.textD.withValues(alpha: 0.15))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(5), borderSide: BorderSide(color: AppColors.secondaryD.withValues(alpha: 0.6))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: AppSpacing.s),
                  ),
                  onSubmitted: (v) {
                    if (v.trim().isNotEmpty) ctrl.addGroup(v.trim());
                    Get.back();
                  },
                ),
              ),
              Divider(height: 1, color: AppColors.textD.withValues(alpha: 0.12)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.m),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: Get.back,
                      child: Text('Cancel', style: TextStyle(color: AppColors.textD.withValues(alpha: 0.6))),
                    ),
                    const SizedBox(width: AppSpacing.m),
                    ElevatedButton(
                      onPressed: () {
                        if (textCtrl.text.trim().isNotEmpty) ctrl.addGroup(textCtrl.text.trim());
                        Get.back();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondaryD, elevation: 0),
                      child: const Text('Add', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRenameGroupDialog(HttpClientController ctrl, HttpRequestGroup group) {
    final textCtrl = TextEditingController(text: group.name);
    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 320,
          decoration: BoxDecoration(color: AppColors.backgroundD, borderRadius: BorderRadius.circular(8)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.l, AppSpacing.m, AppSpacing.l),
                child: Text('Rename Group',
                    style: TextStyle(color: AppColors.textD, fontSize: AppTextSize.title, fontWeight: FontWeight.bold)),
              ),
              Divider(height: 1, color: AppColors.textD.withValues(alpha: 0.12)),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: TextField(
                  controller: textCtrl,
                  autofocus: true,
                  style: TextStyle(color: AppColors.textD, fontSize: AppTextSize.body),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.surfaceD.withValues(alpha: 0.5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(5), borderSide: BorderSide(color: AppColors.textD.withValues(alpha: 0.15))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(5), borderSide: BorderSide(color: AppColors.textD.withValues(alpha: 0.15))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(5), borderSide: BorderSide(color: AppColors.secondaryD.withValues(alpha: 0.6))),
                    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: AppSpacing.s),
                  ),
                  onSubmitted: (v) {
                    if (v.trim().isNotEmpty) ctrl.renameGroup(group.id, v.trim());
                    Get.back();
                  },
                ),
              ),
              Divider(height: 1, color: AppColors.textD.withValues(alpha: 0.12)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.m),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: Get.back,
                      child: Text('Cancel', style: TextStyle(color: AppColors.textD.withValues(alpha: 0.6))),
                    ),
                    const SizedBox(width: AppSpacing.m),
                    ElevatedButton(
                      onPressed: () {
                        if (textCtrl.text.trim().isNotEmpty) ctrl.renameGroup(group.id, textCtrl.text.trim());
                        Get.back();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondaryD, elevation: 0),
                      child: const Text('Save', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMoveToGroupDialog(HttpClientController ctrl, int reqIdx) {
    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 280,
          decoration: BoxDecoration(color: AppColors.backgroundD, borderRadius: BorderRadius.circular(8)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.l, AppSpacing.xl, AppSpacing.l),
                child: Text('Move to group',
                    style: TextStyle(color: AppColors.textD, fontSize: AppTextSize.title, fontWeight: FontWeight.bold)),
              ),
              Divider(height: 1, color: AppColors.textD.withValues(alpha: 0.12)),
              ...ctrl.groups.map((g) => InkWell(
                onTap: () {
                  ctrl.moveRequestToGroup(reqIdx, g.id);
                  Get.back();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.m),
                  child: Row(children: [
                    Icon(Icons.folder_rounded, size: 13, color: AppColors.secondaryD.withValues(alpha: 0.8)),
                    const SizedBox(width: AppSpacing.m),
                    Text(g.name, style: TextStyle(color: AppColors.textD, fontSize: AppTextSize.body)),
                  ]),
                ),
              )),
              if (ctrl.requests[reqIdx].groupId != null) ...[
                Divider(height: 1, color: AppColors.textD.withValues(alpha: 0.12)),
                InkWell(
                  onTap: () {
                    ctrl.moveRequestToGroup(reqIdx, null);
                    Get.back();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.m),
                    child: Row(children: [
                      Icon(Icons.folder_off_outlined, size: 13, color: AppColors.textD.withValues(alpha: 0.5)),
                      const SizedBox(width: AppSpacing.m),
                      Text('Remove from group', style: TextStyle(color: AppColors.textD.withValues(alpha: 0.6), fontSize: AppTextSize.body)),
                    ]),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.s),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sidebar drag-drop list ────────────────────────────────────────────────────

class _SidebarList extends StatefulWidget {
  const _SidebarList({
    required this.ctrl,
    required this.onRequestContextMenu,
    required this.onGroupContextMenu,
  });

  final HttpClientController ctrl;
  final void Function(BuildContext, HttpClientController, int, Offset, {Set<String> selectedIds, VoidCallback? onClearSelection}) onRequestContextMenu;
  final void Function(BuildContext, HttpClientController, HttpRequestGroup, Offset) onGroupContextMenu;

  @override
  State<_SidebarList> createState() => _SidebarListState();
}

class _SidebarListState extends State<_SidebarList> {
  String? _draggingId; // req id being dragged
  int? _hoverInsert;   // flat insert-before index
  String? _hoverGroup; // group id being hovered
  bool _hoverUngroup = false;

  // Multi-select state
  final _selectedIds = <String>{};
  bool get _hasMultiSelection => _selectedIds.length > 1;

  bool _isShiftHeld() => HardwareKeyboard.instance.isShiftPressed;
  bool _isCtrlHeld() =>
      HardwareKeyboard.instance.isControlPressed ||
      HardwareKeyboard.instance.isMetaPressed;

  void _handleReqTap(String id, int reqIdx) {
    if (_isCtrlHeld()) {
      // Ctrl/Cmd: toggle individual item
      setState(() {
        // include the currently focused item into the selection set first
        final currentId = widget.ctrl.requests.isNotEmpty
            ? widget.ctrl.requests[widget.ctrl.selectedIndex.value].id
            : null;
        if (_selectedIds.isEmpty && currentId != null) {
          _selectedIds.add(currentId);
        }
        if (_selectedIds.contains(id)) {
          _selectedIds.remove(id);
        } else {
          _selectedIds.add(id);
        }
      });
    } else if (_isShiftHeld()) {
      // Shift: select range from current focused item to tapped item
      setState(() {
        final anchor = widget.ctrl.selectedIndex.value;
        final from = anchor < reqIdx ? anchor : reqIdx;
        final to = anchor < reqIdx ? reqIdx : anchor;
        _selectedIds.clear();
        for (var i = from; i <= to; i++) {
          if (i < widget.ctrl.requests.length) {
            _selectedIds.add(widget.ctrl.requests[i].id);
          }
        }
      });
    } else {
      if (_selectedIds.isNotEmpty) setState(() => _selectedIds.clear());
      widget.ctrl.selectRequest(reqIdx);
    }
  }

  void _startDrag(String id) => setState(() => _draggingId = id);

  void _endDrag() => setState(() {
    _draggingId = null;
    _hoverInsert = null;
    _hoverGroup = null;
    _hoverUngroup = false;
  });

  void _dropAtInsert(String reqId, int insertIdx, List<Object> flat) {
    final oldIdx = flat.indexWhere((e) => e is HttpRequestItem && e.id == reqId);
    if (oldIdx != -1) widget.ctrl.reorderSidebar(oldIdx, insertIdx);
    _endDrag();
  }

  void _dropOnGroup(String reqId, String groupId) {
    final ctrl = widget.ctrl;
    if (_selectedIds.contains(reqId) && _selectedIds.length > 1) {
      ctrl.moveRequestsToGroup(_selectedIds.toList(), groupId);
      setState(() => _selectedIds.clear());
    } else {
      final reqIdx = ctrl.requests.indexWhere((r) => r.id == reqId);
      if (reqIdx != -1 && ctrl.requests[reqIdx].groupId != groupId) {
        ctrl.moveRequestToGroup(reqIdx, groupId);
      }
    }
    _endDrag();
  }

  void _dropToUngroup(String reqId) {
    final ctrl = widget.ctrl;
    if (_selectedIds.contains(reqId) && _selectedIds.length > 1) {
      ctrl.moveRequestsToGroup(_selectedIds.toList(), null);
      setState(() => _selectedIds.clear());
    } else {
      final reqIdx = ctrl.requests.indexWhere((r) => r.id == reqId);
      if (reqIdx != -1) ctrl.moveRequestToGroup(reqIdx, null);
    }
    _endDrag();
  }

  void _deleteSelected() {
    final ctrl = widget.ctrl;
    if (_selectedIds.isEmpty) return;
    final ids = _selectedIds.toList();
    final emptyGroupIds = ctrl.groups
        .where((g) {
          final groupReqs = ctrl.requests.where((r) => r.groupId == g.id).toList();
          return groupReqs.isNotEmpty &&
              groupReqs.every((r) => ids.contains(r.id));
        })
        .map((g) => g.id)
        .toList();
    ctrl.deleteRequests(ids);
    for (final gid in emptyGroupIds) {
      ctrl.deleteGroup(gid);
    }
    setState(() => _selectedIds.clear());
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.ctrl;
    return KeyboardListener(
      focusNode: FocusNode(),
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.delete ||
             event.logicalKey == LogicalKeyboardKey.backspace) &&
            _selectedIds.isNotEmpty) {
          _deleteSelected();
        }
      },
      child: Obx(() {
      final flat = ctrl.buildVisibleFlatList();
      if (flat.isEmpty) {
        return Center(
          child: Text(
            'No requests yet.\nPress + to add one.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textD.withValues(alpha: 0.4),
              fontSize: AppTextSize.small,
            ),
          ),
        );
      }

      // Check if the dragged request is inside a group (show ungroup zone)
      final draggingGrouped = _draggingId != null &&
          ctrl.requests.any((r) => r.id == _draggingId && r.groupId != null);

      // Always return a Column so the widget tree stays stable during drag
      return Column(
        children: [
          // 2*N+1 slots: insert_zone, entry, insert_zone, entry, ..., insert_zone
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: flat.length * 2 + 1,
              itemBuilder: (context, i) {
                if (i.isEven) return _insertZone(i ~/ 2, flat);
                final entry = flat[i ~/ 2];
                if (entry is HttpRequestGroup) return _groupEntry(entry, context);
                return _reqEntry(entry as HttpRequestItem, flat, context);
              },
            ),
          ),
          _ungroupZone(visible: draggingGrouped),
          _multiActionBar(),
        ],
      );
    }),
    );
  }

  Widget _ungroupZone({bool visible = false}) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (_) {
        setState(() { _hoverUngroup = true; _hoverInsert = null; _hoverGroup = null; });
        return true;
      },
      onLeave: (_) => setState(() => _hoverUngroup = false),
      onAcceptWithDetails: (d) => _dropToUngroup(d.data),
      builder: (_, candidate, __) {
        final active = _hoverUngroup || candidate.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: visible ? 44 : 0,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: active
                ? AppColors.secondaryD.withValues(alpha: 0.15)
                : AppColors.backgroundD.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(6),
            border: visible
                ? Border.all(
                    color: active
                        ? AppColors.secondaryD.withValues(alpha: 0.6)
                        : AppColors.textD.withValues(alpha: 0.2),
                    strokeAlign: BorderSide.strokeAlignInside,
                  )
                : null,
          ),
          margin: visible ? const EdgeInsets.all(AppSpacing.s) : EdgeInsets.zero,
          child: Center(
            child: Text(
              'Drop to ungroup',
              style: TextStyle(
                fontSize: AppTextSize.small,
                color: active
                    ? AppColors.secondaryD
                    : AppColors.textD.withValues(alpha: 0.4),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _insertZone(int insertIdx, List<Object> flat) {
    if (_draggingId == null) return const SizedBox(height: 2);
    final active = _hoverInsert == insertIdx;
    return DragTarget<String>(
      onWillAcceptWithDetails: (_) {
        setState(() { _hoverInsert = insertIdx; _hoverGroup = null; });
        return true;
      },
      onLeave: (_) { if (_hoverInsert == insertIdx) setState(() => _hoverInsert = null); },
      onAcceptWithDetails: (d) => _dropAtInsert(d.data, insertIdx, flat),
      builder: (_, candidate, __) {
        final isActive = active || candidate.isNotEmpty;
        return SizedBox(
          height: 10,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              height: isActive ? 2 : 0,
              color: isActive ? AppColors.secondaryD : Colors.transparent,
            ),
          ),
        );
      },
    );
  }

  void _handleGroupTap(HttpRequestGroup group) {
    final ctrl = widget.ctrl;
    if (_isCtrlHeld() || _isShiftHeld()) {
      // Select/deselect all requests in this group
      final groupReqIds = ctrl.requests
          .where((r) => r.groupId == group.id)
          .map((r) => r.id)
          .toSet();
      setState(() {
        final allSelected = groupReqIds.every((id) => _selectedIds.contains(id));
        if (allSelected) {
          _selectedIds.removeAll(groupReqIds);
        } else {
          _selectedIds.addAll(groupReqIds);
        }
      });
    } else {
      if (_selectedIds.isNotEmpty) setState(() => _selectedIds.clear());
      ctrl.toggleGroup(group.id);
    }
  }

  Widget _groupEntry(HttpRequestGroup group, BuildContext context) {
    final hovering = _hoverGroup == group.id;
    final groupReqIds = widget.ctrl.requests
        .where((r) => r.groupId == group.id)
        .map((r) => r.id)
        .toSet();
    final isGroupSelected = groupReqIds.isNotEmpty &&
        groupReqIds.every((id) => _selectedIds.contains(id));
    return DragTarget<String>(
      onWillAcceptWithDetails: (_) {
        setState(() { _hoverGroup = group.id; _hoverInsert = null; });
        return true;
      },
      onLeave: (_) { if (_hoverGroup == group.id) setState(() => _hoverGroup = null); },
      onAcceptWithDetails: (d) => _dropOnGroup(d.data, group.id),
      builder: (_, candidate, __) => _GroupRow(
        group: group,
        ctrl: widget.ctrl,
        isDropTarget: hovering || candidate.isNotEmpty,
        isGroupSelected: isGroupSelected,
        onTap: () => _handleGroupTap(group),
        onContextMenu: (pos) => widget.onGroupContextMenu(context, widget.ctrl, group, pos),
      ),
    );
  }

  Widget _reqEntry(HttpRequestItem req, List<Object> flat, BuildContext context) {
    final reqIdx = widget.ctrl.requests.indexOf(req);
    final isMultiSelected = _selectedIds.contains(req.id);
    final row = _ReqRow(
      req: req,
      reqIdx: reqIdx,
      ctrl: widget.ctrl,
      isMultiSelected: isMultiSelected,
      onTap: () => _handleReqTap(req.id, reqIdx),
      onContextMenu: (pos) => widget.onRequestContextMenu(
        context, widget.ctrl, reqIdx, pos,
        selectedIds: _selectedIds,
        onClearSelection: () => setState(() => _selectedIds.clear()),
      ),
    );
    return Draggable<String>(
      data: req.id,
      onDragStarted: () => _startDrag(req.id),
      onDragEnd: (_) => _endDrag(),
      onDraggableCanceled: (_, __) => _endDrag(),
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 200,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.backgroundD,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 3))],
                ),
                child: row,
              ),
              if (isMultiSelected && _selectedIds.length > 1)
                Positioned(
                  top: -6,
                  right: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryD,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_selectedIds.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: row),
      child: row,
    );
  }

  Widget _multiActionBar() {
    if (_selectedIds.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: AppSpacing.s),
      decoration: BoxDecoration(
        color: AppColors.secondaryD.withValues(alpha: 0.12),
        border: Border(top: BorderSide(color: AppColors.secondaryD.withValues(alpha: 0.3))),
      ),
      child: Row(
        children: [
          Text(
            '${_selectedIds.length} selected',
            style: TextStyle(color: AppColors.secondaryD, fontSize: AppTextSize.small, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          Tooltip(
            message: 'Delete selected',
            child: InkWell(
              onTap: _deleteSelected,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: Icon(Icons.delete_outline, size: 16, color: AppColors.red),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Tooltip(
            message: 'Clear selection',
            child: InkWell(
              onTap: () => setState(() => _selectedIds.clear()),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: Icon(Icons.close, size: 14, color: AppColors.textD.withValues(alpha: 0.5)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sidebar widgets ───────────────────────────────────────────────────────────

class _GroupRow extends StatelessWidget {
  const _GroupRow({
    required this.group,
    required this.ctrl,
    required this.onContextMenu,
    required this.onTap,
    this.isDropTarget = false,
    this.isGroupSelected = false,
  });

  final HttpRequestGroup group;
  final HttpClientController ctrl;
  final void Function(Offset) onContextMenu;
  final VoidCallback onTap;
  final bool isDropTarget;
  final bool isGroupSelected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapDown: (d) => onContextMenu(d.globalPosition),
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          decoration: BoxDecoration(
            color: isDropTarget
                ? AppColors.secondaryD.withValues(alpha: 0.15)
                : isGroupSelected
                    ? AppColors.secondaryD.withValues(alpha: 0.25)
                    : Colors.transparent,
            border: isDropTarget
                ? Border.all(color: AppColors.secondaryD.withValues(alpha: 0.5))
                : null,
            borderRadius: BorderRadius.circular(4),
          ),
          margin: isDropTarget ? const EdgeInsets.symmetric(horizontal: 4, vertical: 1) : EdgeInsets.zero,
          padding: EdgeInsets.symmetric(horizontal: isDropTarget ? 6 : 10, vertical: 6),
          child: Row(
            children: [
              Icon(
                isDropTarget || group.isExpanded
                    ? Icons.folder_open_rounded
                    : Icons.folder_rounded,
                size: 13,
                color: isDropTarget
                    ? AppColors.secondaryD
                    : AppColors.secondaryD.withValues(alpha: 0.8),
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Text(
                  group.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDropTarget ? AppColors.secondaryD : AppColors.textD,
                    fontSize: AppTextSize.small,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (!isDropTarget)
                Icon(
                  group.isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 14,
                  color: AppColors.textD.withValues(alpha: 0.4),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReqRow extends StatelessWidget {
  const _ReqRow({
    required this.req,
    required this.reqIdx,
    required this.ctrl,
    required this.onContextMenu,
    required this.onTap,
    this.isMultiSelected = false,
  });

  final HttpRequestItem req;
  final int reqIdx;
  final HttpClientController ctrl;
  final void Function(Offset) onContextMenu;
  final VoidCallback onTap;
  final bool isMultiSelected;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isSelected = ctrl.selectedIndex.value == reqIdx;
      final highlighted = isSelected || isMultiSelected;
      return GestureDetector(
        onSecondaryTapDown: (d) => onContextMenu(d.globalPosition),
        child: InkWell(
          onTap: onTap,
          child: Container(
            color: isMultiSelected
                ? AppColors.secondaryD.withValues(alpha: 0.25)
                : isSelected
                    ? AppColors.secondaryD.withValues(alpha: 0.2)
                    : Colors.transparent,
            padding: EdgeInsets.only(
              left: req.groupId != null ? 20 : 10,
              right: 10,
              top: 7,
              bottom: 7,
            ),
            child: Row(
              children: [
                if (isMultiSelected)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: Icon(Icons.check_circle, size: 12, color: AppColors.secondaryD),
                  ),
                _MethodBadge(method: req.method),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: Text(
                    req.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textD,
                      fontSize: AppTextSize.small,
                      fontWeight: highlighted ? FontWeight.bold : FontWeight.normal,
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
}

// ── Request Editor ────────────────────────────────────────────────────────────

class _RequestEditor extends StatefulWidget {
  const _RequestEditor({required this.ctrl});
  final HttpClientController ctrl;

  @override
  State<_RequestEditor> createState() => _RequestEditorState();
}

class _RequestEditorState extends State<_RequestEditor> {
  int _reqTab = 0; // 0=params, 1=headers, 2=body
  int _resTab = 0; // 0=body, 1=headers
  double _splitRatio = 0.4; // fraction for request pane height

  HttpClientController get ctrl => widget.ctrl;

  late TextEditingController _urlCtrl;
  late TextEditingController _nameCtrl;
  late CodeLineEditingController _bodyCtrl;

  int? _lastIndex;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController();
    _nameCtrl = TextEditingController();
    _bodyCtrl = CodeLineEditingController();
    _syncControllers();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _nameCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  void _syncControllers() {
    final req = ctrl.selected;
    if (req == null) return;
    if (_lastIndex != ctrl.selectedIndex.value) {
      _lastIndex = ctrl.selectedIndex.value;
      _urlCtrl.text = req.url;
      _nameCtrl.text = req.name;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _bodyCtrl.text = req.body;
      });
    }
  }

  HttpRequestItem get _req => ctrl.selected!;

  void _update(HttpRequestItem updated) => ctrl.updateSelected(updated);

  void _onUrlChanged(String v) {
    if (v.trimLeft().toLowerCase().startsWith('curl')) {
      final parsed = CurlUtils.parse(v.trim());
      if (parsed != null) {
        final withId = HttpRequestItem(
          id: _req.id,
          name: parsed.name != 'Imported Request' ? parsed.name : _req.name,
          method: parsed.method,
          url: parsed.url,
          headers: parsed.headers,
          params: parsed.params,
          body: parsed.body,
          bodyType: parsed.bodyType,
          formData: parsed.formData,
        );
        // Force _syncControllers to re-sync all controllers on next rebuild
        _lastIndex = null;
        ctrl.updateSelected(withId);
        return;
      }
    }
    _update(_req.copyWith(url: v));
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      ctrl.selectedIndex.value; // reactive
      _syncControllers();
      final req = ctrl.selected;
      if (req == null) return const SizedBox();

      return Column(
        children: [
          // ── Request name bar ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.l, AppSpacing.m, AppSpacing.l, AppSpacing.xs),
            child: SizedBox(
              height: 28,
              child: InterpolationTextField(
                controller: _nameCtrl,
                hintText: 'Request name',
                textSize: 12,
                onChanged: (v) => _update(_req.copyWith(name: v)),
              ),
            ),
          ),

          // ── URL bar ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: AppSpacing.xs),
            child: SizedBox(
              height: 36,
              child: Row(
                children: [
                  // Method selector
                  _MethodSelector(
                    value: req.method,
                    onChanged: (v) => _update(_req.copyWith(method: v)),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  // URL
                  Expanded(
                    child: InterpolationTextField(
                      controller: _urlCtrl,
                      hintText: 'https://example.com/api/endpoint',
                      textSize: 12,
                      onChanged: _onUrlChanged,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s),
                  // Copy cURL button
                  InkWell(
                    onTap: () {
                      final r = ctrl.selected;
                      if (r == null) return;
                      // Interpolate URL so ${customdata.*} placeholders are resolved
                      var urlStr = Interpolation()
                          .excute(before: r.url.trim(), data: '')
                          .replaceAll('"', '');
                      final enabledParams = r.params.where((p) => p.enabled && p.key.isNotEmpty).toList();
                      if (enabledParams.isNotEmpty) {
                        final uri = Uri.tryParse(urlStr);
                        if (uri != null) {
                          final q = Map<String, String>.from(uri.queryParameters);
                          for (final p in enabledParams) { q[p.key] = p.value; }
                          urlStr = uri.replace(queryParameters: q).toString();
                        }
                      }
                      final headers = <String, String>{
                        for (final h in r.headers)
                          if (h.enabled && h.key.isNotEmpty) h.key: h.value,
                      };
                      final curl = CurlUtils.generate(
                        method: r.method,
                        url: urlStr,
                        headers: headers,
                        body: r.body.isNotEmpty ? r.body : null,
                      );
                      Clipboard.setData(ClipboardData(text: curl));
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.s),
                      child: Icon(
                        Icons.content_copy_rounded,
                        size: 14,
                        color: AppColors.textD.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  // Send button
                  Obx(() => SizedBox(
                    height: 36,
                    child: ButtonWidget(
                      onTap: ctrl.isLoading.value ? null : ctrl.sendRequest,
                      color: AppColors.secondaryD,
                      child: ctrl.isLoading.value
                          ? SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Send',
                              style: TextStyle(color: Colors.white, fontSize: AppTextSize.body),
                            ),
                    ),
                  )),
                ],
              ),
            ),
          ),

          Divider(height: 1, color: AppColors.textD.withValues(alpha: 0.15)),

          // ── Split: request config top / response bottom ────────────
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final totalH = constraints.maxHeight;
                final topH = (totalH * _splitRatio).clamp(80.0, totalH - 80.0);
                return Column(
              children: [
                // Request tabs (params/headers/body)
                SizedBox(
                  height: topH,
                  child: Column(
                    children: [
                      AppTabBar(
                        tabs: [
                          'Params (${req.params.where((p) => p.enabled && p.key.isNotEmpty).length})',
                          'Headers (${req.headers.where((h) => h.enabled && h.key.isNotEmpty).length})',
                          'Body',
                        ],
                        selected: _reqTab,
                        onTap: (i) => setState(() => _reqTab = i),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.l),
                          child: _reqTab == 0
                              ? SingleChildScrollView(
                                  child: KeyValueTable(
                                    pairs: req.params,
                                    keyHint: 'Parameter',
                                    enableInterpolation: true,
                                    onChanged: (v) => _update(_req.copyWith(params: v)),
                                  ),
                                )
                              : _reqTab == 1
                                  ? SingleChildScrollView(
                                      child: KeyValueTable(
                                        pairs: req.headers,
                                        keyHint: 'Header',
                                        enableInterpolation: true,
                                        onChanged: (v) => _update(_req.copyWith(headers: v)),
                                      ),
                                    )
                                  : _BodyEditor(
                                      bodyType: req.bodyType,
                                      bodyCtrl: _bodyCtrl,
                                      body: req.body,
                                      formData: req.formData,
                                      onBodyTypeChanged: (t) => _update(_req.copyWith(bodyType: t)),
                                      onBodyChanged: (v) => _update(_req.copyWith(body: v)),
                                      onFormDataChanged: (v) => _update(_req.copyWith(formData: v)),
                                    ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Draggable horizontal divider ──────────────────────
                MouseRegion(
                  cursor: SystemMouseCursors.resizeRow,
                  child: GestureDetector(
                    onVerticalDragUpdate: (d) {
                      setState(() {
                        _splitRatio = (_splitRatio + d.delta.dy / totalH).clamp(0.15, 0.85);
                      });
                    },
                    child: Container(
                      height: 5,
                      color: Colors.transparent,
                      child: Divider(height: 1, color: AppColors.textD.withValues(alpha: 0.15)),
                    ),
                  ),
                ),

                // Response section
                Expanded(
                  child: Obx(() => _ResponsePanel(
                    response: ctrl.response.value,
                    error: ctrl.errorMessage.value,
                    isLoading: ctrl.isLoading.value,
                    selectedTab: _resTab,
                    onTabChanged: (i) => setState(() => _resTab = i),
                  )),
                ),
              ],
            );
          },
        ),
          ),
        ],
      );
    });
  }
}

// ── Response Panel ────────────────────────────────────────────────────────────

class _ResponsePanel extends StatefulWidget {
  const _ResponsePanel({
    required this.response,
    required this.error,
    required this.isLoading,
    required this.selectedTab,
    required this.onTabChanged,
  });

  final HttpResponseResult? response;
  final String? error;
  final bool isLoading;
  final int selectedTab;
  final ValueChanged<int> onTabChanged;

  @override
  State<_ResponsePanel> createState() => _ResponsePanelState();
}

class _ResponsePanelState extends State<_ResponsePanel> {
  final _bodyCtrl = CodeLineEditingController();
  String? _lastBody;

  @override
  void dispose() {
    _bodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final response = widget.response;
    final error = widget.error;
    final isLoading = widget.isLoading;

    // Sync body controller only when response body changes
    if (response != null && response.prettyBody != _lastBody) {
      _lastBody = response.prettyBody;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _bodyCtrl.text = response.prettyBody;
      });
    }

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: AppColors.red, size: 28),
              const SizedBox(height: AppSpacing.m),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.red, fontSize: AppTextSize.body),
              ),
            ],
          ),
        ),
      );
    }

    if (response == null) {
      return Center(
        child: Text(
          'Send a request to see the response',
          style: TextStyle(
            color: AppColors.textD.withValues(alpha: 0.3),
            fontSize: AppTextSize.body,
          ),
        ),
      );
    }

    final res = response;
    return Column(
      children: [
        // Status bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l, vertical: AppSpacing.s),
          child: Row(
            children: [
              Text(
                'Response',
                style: TextStyle(
                  color: AppColors.textD,
                  fontSize: AppTextSize.body,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              _StatusBadge(statusCode: res.statusCode),
              const SizedBox(width: AppSpacing.l),
              _InfoChip(
                icon: Icons.timer_outlined,
                label: '${res.durationMs}ms',
              ),
              const SizedBox(width: AppSpacing.s),
              _InfoChip(
                icon: Icons.data_usage,
                label: '${(res.body.length / 1024).toStringAsFixed(1)} KB',
              ),
            ],
          ),
        ),

        AppTabBar(
          tabs: ['Body', 'Headers (${res.headers.length})'],
          selected: widget.selectedTab,
          onTap: widget.onTabChanged,
        ),

        Expanded(
          child: widget.selectedTab == 0
              ? Padding(
                  padding: const EdgeInsets.all(AppSpacing.m),
                  child: CustomJsonTextField(
                    hintText: '',
                    controller: _bodyCtrl,
                    onChanged: (_) {},
                    readOnly: true,
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.l),
                  children: res.headers.entries.map((e) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 180,
                            child: Text(
                              e.key,
                              style: TextStyle(
                                color: AppColors.secondaryD,
                                fontSize: AppTextSize.small,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            child: SelectableText(
                              e.value,
                              style: TextStyle(
                                color: AppColors.textD,
                                fontSize: AppTextSize.small,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}

// ── Body Editor ───────────────────────────────────────────────────────────────

class _BodyEditor extends StatelessWidget {
  const _BodyEditor({
    required this.bodyType,
    required this.bodyCtrl,
    required this.body,
    required this.formData,
    required this.onBodyTypeChanged,
    required this.onBodyChanged,
    required this.onFormDataChanged,
  });

  final RequestBodyType bodyType;
  final CodeLineEditingController bodyCtrl;
  /// Current raw body string — used for binary file path display.
  final String body;
  final List<RequestFormField> formData;
  final ValueChanged<RequestBodyType> onBodyTypeChanged;
  final ValueChanged<String> onBodyChanged;
  final ValueChanged<List<RequestFormField>> onFormDataChanged;

  static const _labels = {
    RequestBodyType.none: 'None',
    RequestBodyType.json: 'JSON',
    RequestBodyType.text: 'Text',
    RequestBodyType.formData: 'Form Data',
    RequestBodyType.binary: 'Binary',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Type selector ──────────────────────────────────────────
        Row(
          children: RequestBodyType.values.map((t) {
            return Padding(
              padding: const EdgeInsets.only(right: AppSpacing.l),
              child: InkWell(
                onTap: () => onBodyTypeChanged(t),
                child: Row(
                  children: [
                    Icon(
                      t == bodyType
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 14,
                      color: t == bodyType
                          ? AppColors.secondaryD
                          : AppColors.textD.withValues(alpha: 0.4),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      _labels[t]!,
                      style: TextStyle(
                          color: AppColors.textD,
                          fontSize: AppTextSize.small),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.s),

        // ── Body content ───────────────────────────────────────────
        if (bodyType == RequestBodyType.formData)
          Expanded(
            child: _FormDataTable(
              fields: formData,
              onChanged: onFormDataChanged,
            ),
          )
        else if (bodyType == RequestBodyType.binary)
          _BinaryFilePicker(
            filePath: body,
            onChanged: onBodyChanged,
          )
        else if (bodyType != RequestBodyType.none)
          Expanded(
            child: CustomJsonTextField(
              hintText: bodyType == RequestBodyType.json
                  ? '{ "key": "value" }'
                  : 'Request body...',
              controller: bodyCtrl,
              onChanged: onBodyChanged,
            ),
          ),
      ],
    );
  }
}

// ── Form Data Table (supports Text + File fields) ─────────────────────────────

// ── Binary file picker ────────────────────────────────────────────────────────

class _BinaryFilePicker extends StatelessWidget {
  const _BinaryFilePicker({required this.filePath, required this.onChanged});

  final String filePath;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final hasFile = filePath.isNotEmpty;
    final name = hasFile ? filePath.split('/').last : null;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s),
      child: Row(
        children: [
          TextButton.icon(
            style: TextButton.styleFrom(
              backgroundColor: AppColors.surfaceD.withValues(alpha: 0.4),
              foregroundColor: AppColors.textD,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.m, vertical: AppSpacing.s),
            ),
            icon: const Icon(Icons.attach_file, size: 14),
            label: Text(
              hasFile ? 'Change File' : 'Choose File',
              style: const TextStyle(fontSize: AppTextSize.small),
            ),
            onPressed: () async {
              final result = await FilePicker.platform.pickFiles();
              if (result != null && result.files.single.path != null) {
                onChanged(result.files.single.path!);
              }
            },
          ),
          const SizedBox(width: AppSpacing.m),
          if (hasFile) ...[
            Icon(Icons.insert_drive_file_outlined,
                size: 14, color: AppColors.secondaryD),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                name!,
                style: TextStyle(
                    color: AppColors.textD, fontSize: AppTextSize.small),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: Icon(Icons.close,
                  size: 14, color: AppColors.textD.withValues(alpha: 0.4)),
              onPressed: () => onChanged(''),
              tooltip: 'Clear',
            ),
          ] else
            Text(
              'No file selected',
              style: TextStyle(
                  color: AppColors.textD.withValues(alpha: 0.3),
                  fontSize: AppTextSize.small),
            ),
        ],
      ),
    );
  }
}

// ── Form data table ───────────────────────────────────────────────────────────

class _FormDataTable extends StatefulWidget {
  const _FormDataTable({required this.fields, required this.onChanged});

  final List<RequestFormField> fields;
  final ValueChanged<List<RequestFormField>> onChanged;

  @override
  State<_FormDataTable> createState() => _FormDataTableState();
}

class _FormDataTableState extends State<_FormDataTable> {
  late List<RequestFormField> _fields;
  final List<TextEditingController> _keyCtrls = [];
  final List<TextEditingController> _valCtrls = [];

  @override
  void initState() {
    super.initState();
    _fields = List.from(widget.fields);
    _rebuildControllers();
  }

  @override
  void didUpdateWidget(_FormDataTable old) {
    super.didUpdateWidget(old);
    if (old.fields.length != widget.fields.length) {
      _fields = List.from(widget.fields);
      _rebuildControllers();
    }
  }

  void _rebuildControllers() {
    for (final c in _keyCtrls) { c.dispose(); }
    for (final c in _valCtrls) { c.dispose(); }
    _keyCtrls.clear();
    _valCtrls.clear();
    for (final f in _fields) {
      _keyCtrls.add(TextEditingController(text: f.key));
      _valCtrls.add(TextEditingController(text: f.value));
    }
  }

  @override
  void dispose() {
    for (final c in _keyCtrls) { c.dispose(); }
    for (final c in _valCtrls) { c.dispose(); }
    super.dispose();
  }

  void _notify() => widget.onChanged(List.from(_fields));

  void _addField() {
    setState(() {
      _fields.add(RequestFormField());
      _keyCtrls.add(TextEditingController());
      _valCtrls.add(TextEditingController());
    });
    _notify();
  }

  void _remove(int i) {
    _keyCtrls[i].dispose();
    _valCtrls[i].dispose();
    setState(() {
      _fields.removeAt(i);
      _keyCtrls.removeAt(i);
      _valCtrls.removeAt(i);
    });
    _notify();
  }

  Future<void> _pickFile(int i) async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: false);
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;
    setState(() {
      _fields[i] = _fields[i].copyWith(filePath: path, value: result.files.single.name);
      _valCtrls[i].text = result.files.single.name;
    });
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...List.generate(_fields.length, (i) {
            final f = _fields[i];
            final isFile = f.type == RequestFormFieldType.file;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: [
                  // Enabled checkbox — same pattern as KeyValueTable
                  InkWell(
                    onTap: () {
                      setState(() => _fields[i] = f.copyWith(enabled: !f.enabled));
                      _notify();
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      child: Icon(
                        f.enabled
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        size: 16,
                        color: f.enabled
                            ? AppColors.greenD
                            : AppColors.textD.withValues(alpha: 0.4),
                      ),
                    ),
                  ),

                  // Type toggle: Text / File
                  Tooltip(
                    message: isFile ? 'Switch to text' : 'Switch to file',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: () {
                        setState(() {
                          _fields[i] = f.copyWith(
                            type: isFile
                                ? RequestFormFieldType.text
                                : RequestFormFieldType.file,
                            filePath: isFile ? null : f.filePath,
                          );
                        });
                        _notify();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs, vertical: 2),
                        decoration: BoxDecoration(
                          color: isFile
                              ? AppColors.secondaryD.withValues(alpha: 0.15)
                              : AppColors.textD.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isFile
                                ? AppColors.secondaryD.withValues(alpha: 0.4)
                                : AppColors.textD.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Text(
                          isFile ? 'File' : 'Text',
                          style: TextStyle(
                            fontSize: AppTextSize.small,
                            color: isFile
                                ? AppColors.secondaryD
                                : AppColors.textD.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),

                  // Key field
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 30,
                      child: CustomTextField(
                        controller: _keyCtrls[i],
                        hintText: 'Field name',
                        textSize: AppTextSize.small,
                        onChanged: (v) {
                          _fields[i] = f.copyWith(key: v);
                          _notify();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s),

                  // Value field or file picker
                  Expanded(
                    flex: 3,
                    child: isFile
                        ? InkWell(
                            onTap: () => _pickFile(i),
                            borderRadius: BorderRadius.circular(5),
                            child: Container(
                              height: 30,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.m),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceD.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.attach_file_rounded,
                                      size: 13,
                                      color: AppColors.textD
                                          .withValues(alpha: 0.45)),
                                  const SizedBox(width: AppSpacing.xs),
                                  Expanded(
                                    child: Text(
                                      f.filePath != null
                                          ? f.displayFileName
                                          : 'Choose file…',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: AppTextSize.small,
                                        color: f.filePath != null
                                            ? AppColors.textD
                                            : AppColors.textD
                                                .withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : SizedBox(
                            height: 30,
                            child: CustomTextField(
                              controller: _valCtrls[i],
                              hintText: 'Value',
                              textSize: AppTextSize.small,
                              onChanged: (v) {
                                _fields[i] = f.copyWith(value: v);
                                _notify();
                              },
                            ),
                          ),
                  ),

                  // Remove button — same pattern as KeyValueTable
                  InkWell(
                    onTap: () => _remove(i),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      child: Icon(
                        Icons.close,
                        size: 12,
                        color: AppColors.textD.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          // Add button — same pattern as KeyValueTable
          InkWell(
            onTap: _addField,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 13, color: AppColors.greenD),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Add',
                    style: TextStyle(
                        color: AppColors.greenD, fontSize: AppTextSize.small),
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

// ── Helpers ───────────────────────────────────────────────────────────────────

class _MethodSelector extends StatelessWidget {
  const _MethodSelector({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  static const _methods = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'HEAD'];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
      decoration: BoxDecoration(
        color: AppColors.surfaceD.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: const Icon(Icons.keyboard_arrow_down, size: 14, color: AppColors.textD),
          dropdownColor: Theme.of(context).canvasColor,
          style: TextStyle(
            color: AppColors.methodColor(value),
            fontSize: AppTextSize.body,
            fontWeight: FontWeight.bold,
          ),
          items: _methods
              .map(
                (m) => DropdownMenuItem(
                  value: m,
                  child: Text(
                    m,
                    style: TextStyle(
                      color: AppColors.methodColor(m),
                      fontSize: AppTextSize.body,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (v) => v != null ? onChanged(v) : null,
        ),
      ),
    );
  }
}

class _MethodBadge extends StatelessWidget {
  const _MethodBadge({required this.method});
  final String method;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.methodColor(method);
    return Text(
      method,
      style: TextStyle(
        color: color,
        fontSize: AppTextSize.badge,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.statusCode});
  final int statusCode;

  @override
  Widget build(BuildContext context) {
    final color = statusCode >= 200 && statusCode < 300
        ? AppColors.greenD
        : statusCode >= 400 && statusCode < 500
            ? Colors.orangeAccent
            : statusCode >= 500
                ? AppColors.red
                : AppColors.textD;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$statusCode',
        style: TextStyle(
          color: color,
          fontSize: AppTextSize.small,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: AppColors.textD.withValues(alpha: 0.5)),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: TextStyle(
            color: AppColors.textD.withValues(alpha: 0.5),
            fontSize: AppTextSize.small,
          ),
        ),
      ],
    );
  }
}

// ── Client tab bar (HTTP | WebSocket) ─────────────────────────────────────────

class _ClientTabBar extends StatelessWidget {
  const _ClientTabBar({required this.selected, required this.onTap});

  final int selected;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.textD.withValues(alpha: 0.12)),
        ),
      ),
      child: Row(
        children: [
          _chip(0, 'HTTP', false),
          _chip(1, 'WebSocket', true),
        ],
      ),
    );
  }

  Widget _chip(int index, String label, bool wsStyle) {
    final isSelected = selected == index;
    final color = wsStyle ? const Color(0xFF4DFFD6) : AppColors.secondaryD;
    return InkWell(
      onTap: () => onTap(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? color : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? color
                : AppColors.textD.withValues(alpha: 0.45),
            fontSize: AppTextSize.small,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
