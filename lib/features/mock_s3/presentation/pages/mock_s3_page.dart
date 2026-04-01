import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mockondo/core/colors.dart';
import 'package:mockondo/core/widgets/chip_start.dart';
import 'package:mockondo/core/widgets/custom_textfield.dart';
import 'package:mockondo/features/mock_s3/data/models/s3_model.dart';
import 'package:mockondo/features/mock_s3/presentation/controllers/mock_s3_controller.dart';

class MockS3Page extends StatelessWidget {
  const MockS3Page({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(MockS3Controller());
    return Column(
      children: [
        _TopBar(ctrl: ctrl),
        Expanded(
          child: Row(
            children: [
              _BucketSidebar(ctrl: ctrl),
              Container(
                width: 1,
                color: AppColors.textD.withValues(alpha: 0.08),
              ),
              Expanded(child: _ObjectBrowser(ctrl: ctrl)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Top Bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.ctrl});
  final MockS3Controller ctrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.surfaceD.withValues(alpha: 0.12),
        border: Border(
          bottom: BorderSide(color: AppColors.textD.withValues(alpha: 0.08)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
      child: Row(
        children: [
          Icon(Icons.storage_rounded, size: 14, color: AppColors.secondaryD),
          const SizedBox(width: AppSpacing.s),
          Text(
            'Mock Storage',
            style: TextStyle(
              color: AppColors.textD,
              fontSize: AppTextSize.title,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: AppSpacing.xl),
          // Running status
          Obx(() {
            if (!ctrl.isRunning.value) return const SizedBox.shrink();
            final c = ctrl.config.value;
            return Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.greenD,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'http://${c.host}:${c.port}',
                  style: const TextStyle(
                    color: AppColors.greenD,
                    fontSize: AppTextSize.body,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                Tooltip(
                  message: 'SDK Connection Info',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () => _showConnectionInfo(context),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      child: Icon(
                        Icons.info_outline_rounded,
                        size: 13,
                        color: AppColors.textD.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
          // const Spacer(),
          // Server error
          Obx(() {
            final err = ctrl.serverError.value;
            if (err == null) return const Spacer();
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.m),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, size: 12, color: AppColors.red),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        err,
                        style: TextStyle(
                          color: AppColors.red,
                          fontSize: AppTextSize.small,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          // Settings
          Tooltip(
            message: 'Server Settings',
            child: InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap:
                  () => showDialog(
                    context: context,
                    builder: (_) => _SettingsDialog(ctrl: ctrl),
                  ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: Icon(
                  Icons.tune_rounded,
                  size: 16,
                  color: AppColors.textD.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s),
          // Start / Stop button
          Obx(
            () => ChipStart(
              label: ctrl.isRunning.value ? 'Stop' : 'Start',
              color: ctrl.isRunning.value ? AppColors.red : AppColors.greenD,
              onTap: ctrl.isRunning.value ? ctrl.stopServer : ctrl.startServer,
            ),
          ),
        ],
      ),
    );
  }

  void _showConnectionInfo(BuildContext context) {
    final c = ctrl.config.value;
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: AppColors.backgroundD,
            title: Text(
              'SDK Connection Info',
              style: TextStyle(
                color: AppColors.textD,
                fontSize: AppTextSize.title,
              ),
            ),
            content: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Configure your S3 client to connect to this mock server:',
                    style: TextStyle(
                      color: AppColors.textD.withValues(alpha: 0.6),
                      fontSize: AppTextSize.body,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.m),
                  _InfoRow('Endpoint', 'http://${c.host}:${c.port}'),
                  _InfoRow('Access Key', c.accessKey),
                  _InfoRow('Secret Key', c.secretKey),
                  _InfoRow('Region', c.region),
                  _InfoRow('Path Style', 'true (force)'),
                  const SizedBox(height: AppSpacing.l),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.m),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceD.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '# AWS CLI example',
                          style: TextStyle(
                            color: AppColors.textD.withValues(alpha: 0.4),
                            fontSize: AppTextSize.small,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        SelectableText(
                          'aws s3 ls \\\n'
                          '  --endpoint-url http://${c.host}:${c.port} \\\n'
                          '  --no-sign-request',
                          style: TextStyle(
                            color: AppColors.textD,
                            fontSize: AppTextSize.small,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close', style: TextStyle(color: AppColors.textD)),
              ),
            ],
          ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textD.withValues(alpha: 0.55),
                fontSize: AppTextSize.body,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                color: AppColors.secondaryD,
                fontSize: AppTextSize.body,
                fontFamily: 'monospace',
              ),
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: () => Clipboard.setData(ClipboardData(text: value)),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: Icon(
                Icons.copy_rounded,
                size: 12,
                color: AppColors.textD.withValues(alpha: 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bucket Sidebar ────────────────────────────────────────────────────────────

class _BucketSidebar extends StatelessWidget {
  const _BucketSidebar({required this.ctrl});
  final MockS3Controller ctrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      color: AppColors.backgroundD,
      child: Column(
        children: [
          // Header
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppColors.textD.withValues(alpha: 0.08),
                ),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'BUCKETS',
                  style: TextStyle(
                    color: AppColors.textD,
                    fontSize: AppTextSize.body,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Tooltip(
                  message: 'New Bucket',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () => _showCreate(context),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      child: Icon(Icons.add, size: 16, color: AppColors.greenD),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // List
          Expanded(
            child: Obx(() {
              if (ctrl.buckets.isEmpty) {
                return Center(
                  child: Text(
                    'No buckets yet.\nTap + to create one.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textD.withValues(alpha: 0.35),
                      fontSize: AppTextSize.small,
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                itemCount: ctrl.buckets.length,
                itemBuilder: (_, i) {
                  final b = ctrl.buckets[i];
                  return Obx(
                    () => _BucketRow(
                      bucket: b,
                      isSelected: ctrl.selectedBucket.value == b.name,
                      onTap: () => ctrl.selectBucket(b.name),
                      onDelete: () => _confirmDelete(context, b.name),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  void _showCreate(BuildContext context) => showDialog(
    context: context,
    builder: (_) => _CreateBucketDialog(ctrl: ctrl),
  );

  void _confirmDelete(BuildContext context, String name) => showDialog(
    context: context,
    builder:
        (_) => AlertDialog(
          backgroundColor: AppColors.backgroundD,
          title: Text(
            'Delete Bucket',
            style: TextStyle(
              color: AppColors.textD,
              fontSize: AppTextSize.title,
            ),
          ),
          content: Text(
            'Delete "$name" and all its objects? This cannot be undone.',
            style: TextStyle(
              color: AppColors.textD.withValues(alpha: 0.7),
              fontSize: AppTextSize.body,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: AppColors.textD)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                ctrl.deleteBucket(name);
              },
              child: Text('Delete', style: TextStyle(color: AppColors.red)),
            ),
          ],
        ),
  );
}

class _BucketRow extends StatefulWidget {
  const _BucketRow({
    required this.bucket,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
  });
  final S3Bucket bucket;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  State<_BucketRow> createState() => _BucketRowState();
}

class _BucketRowState extends State<_BucketRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
          color:
              widget.isSelected
                  ? AppColors.secondaryD.withValues(alpha: 0.15)
                  : _hovered
                  ? AppColors.textD.withValues(alpha: 0.05)
                  : Colors.transparent,
          child: Row(
            children: [
              Icon(
                Icons.folder_outlined,
                size: 14,
                color:
                    widget.isSelected
                        ? AppColors.secondaryD
                        : AppColors.textD.withValues(alpha: 0.5),
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Text(
                  widget.bucket.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color:
                        widget.isSelected
                            ? AppColors.textD
                            : AppColors.textD.withValues(alpha: 0.7),
                    fontSize: AppTextSize.body,
                    fontWeight:
                        widget.isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (_hovered)
                InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: widget.onDelete,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: Icon(
                      Icons.delete_outline,
                      size: 13,
                      color: AppColors.red.withValues(alpha: 0.7),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Object Browser ────────────────────────────────────────────────────────────

class _ObjectBrowser extends StatelessWidget {
  const _ObjectBrowser({required this.ctrl});
  final MockS3Controller ctrl;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final bucket = ctrl.selectedBucket.value;
      if (bucket == null) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.storage_rounded,
                size: 52,
                color: AppColors.textD.withValues(alpha: 0.12),
              ),
              const SizedBox(height: AppSpacing.m),
              Text(
                'Select a bucket',
                style: TextStyle(
                  color: AppColors.textD.withValues(alpha: 0.35),
                  fontSize: AppTextSize.title,
                ),
              ),
            ],
          ),
        );
      }
      return Column(
        children: [
          _BrowserToolbar(ctrl: ctrl, bucket: bucket),
          Expanded(child: _ObjectList(ctrl: ctrl, bucket: bucket)),
        ],
      );
    });
  }
}

class _BrowserToolbar extends StatelessWidget {
  const _BrowserToolbar({required this.ctrl, required this.bucket});
  final MockS3Controller ctrl;
  final String bucket;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
      decoration: BoxDecoration(
        color: AppColors.surfaceD.withValues(alpha: 0.07),
        border: Border(
          bottom: BorderSide(color: AppColors.textD.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          // Back arrow when inside a prefix
          Obx(() {
            if (ctrl.currentPrefix.value.isEmpty) {
              return const SizedBox.shrink();
            }
            return Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: ctrl.navigateUp,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: Icon(
                      Icons.arrow_back_rounded,
                      size: 14,
                      color: AppColors.textD.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
            );
          }),
          // Breadcrumb
          Expanded(
            child: Obx(() {
              final prefix = ctrl.currentPrefix.value;
              final crumbs = <Widget>[];

              crumbs.add(
                _Crumb(label: bucket, onTap: () => ctrl.navigateToPrefix('')),
              );

              if (prefix.isNotEmpty) {
                final parts =
                    prefix.split('/').where((s) => s.isNotEmpty).toList();
                String acc = '';
                for (final part in parts) {
                  acc += '$part/';
                  final cap = acc;
                  crumbs.add(
                    Icon(
                      Icons.chevron_right,
                      size: 14,
                      color: AppColors.textD.withValues(alpha: 0.35),
                    ),
                  );
                  crumbs.add(
                    _Crumb(
                      label: part,
                      onTap: () => ctrl.navigateToPrefix(cap),
                    ),
                  );
                }
              }
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: crumbs),
              );
            }),
          ),
          // Upload spinner
          Obx(() {
            if (!ctrl.isUploading.value) return const SizedBox.shrink();
            return Row(
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.secondaryD,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Uploading…',
                  style: TextStyle(
                    color: AppColors.textD.withValues(alpha: 0.5),
                    fontSize: AppTextSize.small,
                  ),
                ),
                const SizedBox(width: AppSpacing.m),
              ],
            );
          }),
          // Upload button
          Obx(() {
            final prefix = ctrl.currentPrefix.value;
            return _TBtn(
              icon: Icons.upload_rounded,
              label: 'Upload',
              onTap:
                  ctrl.isUploading.value
                      ? null
                      : () => ctrl.uploadFiles(bucket, prefix),
            );
          }),
          const SizedBox(width: AppSpacing.xs),
          // New Folder button
          Obx(() {
            final prefix = ctrl.currentPrefix.value;
            return _TBtn(
              icon: Icons.create_new_folder_outlined,
              label: 'New Folder',
              onTap:
                  () => showDialog(
                    context: context,
                    builder:
                        (_) => _CreateFolderDialog(
                          onCreate:
                              (name) => ctrl.createFolder(bucket, prefix, name),
                        ),
                  ),
            );
          }),
          const SizedBox(width: AppSpacing.xs),
          // Presign URL button
          Obx(() {
            final prefix = ctrl.currentPrefix.value;
            return _TBtn(
              icon: Icons.link_rounded,
              label: 'Presign URL',
              onTap:
                  () => showDialog(
                    context: context,
                    builder:
                        (_) => _PresignDialog(
                          ctrl: ctrl,
                          bucket: bucket,
                          initialKey: prefix,
                        ),
                  ),
            );
          }),
        ],
      ),
    );
  }
}

class _Crumb extends StatelessWidget {
  const _Crumb({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xs,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: AppColors.secondaryD,
            fontSize: AppTextSize.body,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _TBtn extends StatelessWidget {
  const _TBtn({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c =
        onTap == null
            ? AppColors.textD.withValues(alpha: 0.25)
            : AppColors.textD.withValues(alpha: 0.65);
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: c),
            const SizedBox(width: AppSpacing.xs),
            Text(label, style: TextStyle(color: c, fontSize: AppTextSize.body)),
          ],
        ),
      ),
    );
  }
}

// ── Object List ───────────────────────────────────────────────────────────────

class _ObjectList extends StatelessWidget {
  const _ObjectList({required this.ctrl, required this.bucket});
  final MockS3Controller ctrl;
  final String bucket;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Trigger rebuild on prefix or objects changes
      ctrl.currentPrefix.value;
      ctrl.objects.length;

      final items = ctrl.getVisibleItems();

      if (items.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 44,
                color: AppColors.textD.withValues(alpha: 0.12),
              ),
              const SizedBox(height: AppSpacing.m),
              Text(
                'No objects here',
                style: TextStyle(
                  color: AppColors.textD.withValues(alpha: 0.3),
                  fontSize: AppTextSize.body,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Upload files or create a folder',
                style: TextStyle(
                  color: AppColors.textD.withValues(alpha: 0.2),
                  fontSize: AppTextSize.small,
                ),
              ),
            ],
          ),
        );
      }

      return Column(
        children: [
          // Table header
          Container(
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
            decoration: BoxDecoration(
              color: AppColors.surfaceD.withValues(alpha: 0.07),
              border: Border(
                bottom: BorderSide(
                  color: AppColors.textD.withValues(alpha: 0.06),
                ),
              ),
            ),
            child: _headerRow(),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: items.length,
              itemBuilder: (_, i) {
                final item = items[i];
                return _ObjectRow(
                  item: item,
                  ctrl: ctrl,
                  onTap:
                      item.isFolder
                          ? () => ctrl.navigateToPrefix(item.folderPrefix)
                          : null,
                  onDownload:
                      item.isFolder
                          ? null
                          : () => ctrl.downloadObject(item.object!),
                  onPresign:
                      () => showDialog(
                        context: context,
                        builder:
                            (_) => _PresignDialog(
                              ctrl: ctrl,
                              bucket: ctrl.selectedBucket.value!,
                              initialKey:
                                  item.isFolder
                                      ? item.folderPrefix
                                      : item.object!.key,
                            ),
                      ),
                  onDelete:
                      item.isFolder
                          ? () => _confirmDeleteFolder(context, item)
                          : () => _confirmDeleteObject(context, item.object!),
                );
              },
            ),
          ),
        ],
      );
    });
  }

  Widget _headerRow() {
    style() => TextStyle(
      color: AppColors.textD.withValues(alpha: 0.4),
      fontSize: AppTextSize.small,
    );
    return Row(
      children: [
        const SizedBox(width: 20),
        const SizedBox(width: AppSpacing.s),
        Expanded(flex: 5, child: Text('Name', style: style())),
        SizedBox(width: 72, child: Text('Size', style: style())),
        SizedBox(width: 160, child: Text('Type', style: style())),
        SizedBox(width: 90, child: Text('Modified', style: style())),
        const SizedBox(width: 90), // actions
      ],
    );
  }

  void _confirmDeleteObject(BuildContext context, S3Object obj) => showDialog(
    context: context,
    builder:
        (_) => AlertDialog(
          backgroundColor: AppColors.backgroundD,
          title: Text(
            'Delete Object',
            style: TextStyle(
              color: AppColors.textD,
              fontSize: AppTextSize.title,
            ),
          ),
          content: Text(
            'Delete "${obj.key}"?',
            style: TextStyle(
              color: AppColors.textD.withValues(alpha: 0.7),
              fontSize: AppTextSize.body,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: AppColors.textD)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                ctrl.deleteObject(obj);
              },
              child: Text('Delete', style: TextStyle(color: AppColors.red)),
            ),
          ],
        ),
  );

  void _confirmDeleteFolder(BuildContext context, S3Item item) => showDialog(
    context: context,
    builder:
        (_) => AlertDialog(
          backgroundColor: AppColors.backgroundD,
          title: Text(
            'Delete Folder',
            style: TextStyle(
              color: AppColors.textD,
              fontSize: AppTextSize.title,
            ),
          ),
          content: Text(
            'Delete "${item.displayName}" and all its contents?',
            style: TextStyle(
              color: AppColors.textD.withValues(alpha: 0.7),
              fontSize: AppTextSize.body,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: AppColors.textD)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                ctrl.deleteFolderPrefix(
                  ctrl.selectedBucket.value!,
                  item.folderPrefix,
                );
              },
              child: Text('Delete', style: TextStyle(color: AppColors.red)),
            ),
          ],
        ),
  );
}

class _ObjectRow extends StatefulWidget {
  const _ObjectRow({
    required this.item,
    required this.ctrl,
    this.onTap,
    this.onDownload,
    this.onPresign,
    this.onDelete,
  });
  final S3Item item;
  final MockS3Controller ctrl;
  final VoidCallback? onTap;
  final VoidCallback? onDownload;
  final VoidCallback? onPresign;
  final VoidCallback? onDelete;

  @override
  State<_ObjectRow> createState() => _ObjectRowState();
}

class _ObjectRowState extends State<_ObjectRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final obj = item.object;
    final isFolder = item.isFolder;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
          decoration: BoxDecoration(
            color:
                _hovered
                    ? AppColors.textD.withValues(alpha: 0.04)
                    : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: AppColors.textD.withValues(alpha: 0.04),
              ),
            ),
          ),
          child: Row(
            children: [
              // Icon
              Icon(
                isFolder
                    ? Icons.folder_rounded
                    : _fileIcon(obj?.contentType ?? ''),
                size: 15,
                color:
                    isFolder
                        ? Colors.amberAccent.withValues(alpha: 0.75)
                        : AppColors.textD.withValues(alpha: 0.45),
              ),
              const SizedBox(width: AppSpacing.s),
              // Name
              Expanded(
                flex: 5,
                child: Text(
                  item.displayName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color:
                        isFolder
                            ? AppColors.secondaryD
                            : AppColors.textD.withValues(alpha: 0.85),
                    fontSize: AppTextSize.body,
                  ),
                ),
              ),
              // Size
              SizedBox(
                width: 72,
                child: Text(
                  isFolder ? '—' : _fmtSize(obj!.size),
                  style: TextStyle(
                    color: AppColors.textD.withValues(alpha: 0.45),
                    fontSize: AppTextSize.small,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              // Type
              SizedBox(
                width: 160,
                child: Text(
                  isFolder ? 'Folder' : (obj?.contentType ?? ''),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textD.withValues(alpha: 0.45),
                    fontSize: AppTextSize.small,
                  ),
                ),
              ),
              // Modified
              SizedBox(
                width: 90,
                child: Text(
                  isFolder ? '—' : _fmtDate(obj!.lastModified),
                  style: TextStyle(
                    color: AppColors.textD.withValues(alpha: 0.45),
                    fontSize: AppTextSize.small,
                  ),
                ),
              ),
              // Actions (hover only)
              SizedBox(
                width: 90,
                child:
                    _hovered
                        ? Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (widget.onDownload != null)
                              _Act(
                                icon: Icons.download_rounded,
                                tooltip: 'Download',
                                onTap: widget.onDownload!,
                              ),
                            if (widget.onPresign != null)
                              _Act(
                                icon: Icons.link_rounded,
                                tooltip: 'Presigned URL',
                                onTap: widget.onPresign!,
                              ),
                            if (widget.onDelete != null)
                              _Act(
                                icon: Icons.delete_outline,
                                tooltip: 'Delete',
                                color: AppColors.red.withValues(alpha: 0.7),
                                onTap: widget.onDelete!,
                              ),
                          ],
                        )
                        : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _fileIcon(String ct) {
    if (ct.startsWith('image/')) return Icons.image_outlined;
    if (ct.startsWith('video/')) return Icons.videocam_outlined;
    if (ct.startsWith('audio/')) return Icons.audio_file_outlined;
    if (ct.contains('json')) return Icons.data_object_rounded;
    if (ct.contains('html')) return Icons.html_rounded;
    if (ct.contains('pdf')) return Icons.picture_as_pdf_outlined;
    if (ct.contains('zip') || ct.contains('gzip') || ct.contains('tar')) {
      return Icons.folder_zip_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  String _fmtSize(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    if (b < 1024 * 1024 * 1024) {
      return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _fmtDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _Act extends StatelessWidget {
  const _Act({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: Icon(
            icon,
            size: 14,
            color: color ?? AppColors.textD.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}

// ── Dialogs ───────────────────────────────────────────────────────────────────

class _CreateBucketDialog extends StatefulWidget {
  const _CreateBucketDialog({required this.ctrl});
  final MockS3Controller ctrl;

  @override
  State<_CreateBucketDialog> createState() => _CreateBucketDialogState();
}

class _CreateBucketDialogState extends State<_CreateBucketDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.backgroundD,
      title: Text(
        'New Bucket',
        style: TextStyle(color: AppColors.textD, fontSize: AppTextSize.title),
      ),
      content: SizedBox(
        width: 300,
        child: CustomTextField(
          controller: _ctrl,
          hintText: 'e.g. my-assets',
          textSize: AppTextSize.body,
          onChanged: (_) => setState(() {}),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: AppColors.textD)),
        ),
        TextButton(
          onPressed:
              _ctrl.text.trim().isEmpty
                  ? null
                  : () {
                    widget.ctrl.createBucket(_ctrl.text.trim());
                    Navigator.pop(context);
                  },
          child: Text(
            'Create',
            style: TextStyle(
              color:
                  _ctrl.text.trim().isEmpty
                      ? AppColors.textD.withValues(alpha: 0.3)
                      : AppColors.secondaryD,
            ),
          ),
        ),
      ],
    );
  }
}

class _CreateFolderDialog extends StatefulWidget {
  const _CreateFolderDialog({required this.onCreate});
  final void Function(String name) onCreate;

  @override
  State<_CreateFolderDialog> createState() => _CreateFolderDialogState();
}

class _CreateFolderDialogState extends State<_CreateFolderDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.backgroundD,
      title: Text(
        'New Folder',
        style: TextStyle(color: AppColors.textD, fontSize: AppTextSize.title),
      ),
      content: SizedBox(
        width: 300,
        child: CustomTextField(
          controller: _ctrl,
          hintText: 'Folder name',
          textSize: AppTextSize.body,
          onChanged: (_) => setState(() {}),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: AppColors.textD)),
        ),
        TextButton(
          onPressed:
              _ctrl.text.trim().isEmpty
                  ? null
                  : () {
                    widget.onCreate(_ctrl.text.trim());
                    Navigator.pop(context);
                  },
          child: Text(
            'Create',
            style: TextStyle(
              color:
                  _ctrl.text.trim().isEmpty
                      ? AppColors.textD.withValues(alpha: 0.3)
                      : AppColors.secondaryD,
            ),
          ),
        ),
      ],
    );
  }
}

class _PresignDialog extends StatefulWidget {
  const _PresignDialog({
    required this.ctrl,
    required this.bucket,
    required this.initialKey,
  });
  final MockS3Controller ctrl;
  final String bucket;
  final String initialKey;

  @override
  State<_PresignDialog> createState() => _PresignDialogState();
}

class _PresignDialogState extends State<_PresignDialog> {
  String _op = 'GET';
  int _expiry = 3600;
  PresignedUrl? _result;
  late final TextEditingController _keyCtrl;
  // If initialKey ends with '/', it is a folder prefix that is shown as
  // read-only context. The user then types only the filename.
  late final String _folderPrefix;

  static const _expiryOpts = [
    ('15 minutes', 900),
    ('1 hour', 3600),
    ('12 hours', 43200),
    ('24 hours', 86400),
    ('7 days', 604800),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialKey.endsWith('/')) {
      // Opened from a folder row: keep prefix as context, key input = filename
      _folderPrefix = widget.initialKey;
      _keyCtrl = TextEditingController();
      _op = 'PUT';
    } else {
      _folderPrefix = '';
      _keyCtrl = TextEditingController(text: widget.initialKey);
    }
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.backgroundD,
      title: Text(
        'Presigned URL',
        style: TextStyle(color: AppColors.textD, fontSize: AppTextSize.title),
      ),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Object key (editable)
            _label('Object Key'),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Text(
                  '${widget.bucket}/$_folderPrefix',
                  style: TextStyle(
                    color: AppColors.textD.withValues(alpha: 0.5),
                    fontSize: AppTextSize.small,
                    fontFamily: 'monospace',
                  ),
                ),
                Expanded(
                  child: SizedBox(
                    height: 28,
                    child: CustomTextField(
                      controller: _keyCtrl,
                      hintText: _folderPrefix.isNotEmpty
                          ? 'filename.ext'
                          : 'path/to/object',
                      textSize: AppTextSize.small,
                      onChanged: (_) => setState(() => _result = null),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.m),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Operation selector
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Operation'),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children:
                          ['GET', 'PUT'].map((op) {
                            final sel = _op == op;
                            return Padding(
                              padding: const EdgeInsets.only(
                                right: AppSpacing.s,
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(5),
                                onTap:
                                    () => setState(() {
                                      _op = op;
                                      _result = null;
                                    }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.m,
                                    vertical: AppSpacing.xs,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        sel
                                            ? AppColors.secondaryD.withValues(
                                              alpha: 0.2,
                                            )
                                            : AppColors.surfaceD.withValues(
                                              alpha: 0.3,
                                            ),
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(
                                      color:
                                          sel
                                              ? AppColors.secondaryD.withValues(
                                                alpha: 0.5,
                                              )
                                              : AppColors.textD.withValues(
                                                alpha: 0.12,
                                              ),
                                    ),
                                  ),
                                  child: Text(
                                    op,
                                    style: TextStyle(
                                      color:
                                          sel
                                              ? AppColors.secondaryD
                                              : AppColors.textD.withValues(
                                                alpha: 0.6,
                                              ),
                                      fontSize: AppTextSize.body,
                                      fontWeight:
                                          sel
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                  ],
                ),
                const SizedBox(width: AppSpacing.xl),
                // Expiry dropdown
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Expires in'),
                      const SizedBox(height: AppSpacing.xs),
                      Container(
                        height: 30,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.m,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceD.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _expiry,
                            dropdownColor: AppColors.backgroundD,
                            style: TextStyle(
                              color: AppColors.textD,
                              fontSize: AppTextSize.body,
                            ),
                            icon: Icon(
                              Icons.keyboard_arrow_down,
                              size: 14,
                              color: AppColors.textD,
                            ),
                            onChanged:
                                (v) => setState(() {
                                  _expiry = v!;
                                  _result = null;
                                }),
                            items:
                                _expiryOpts
                                    .map(
                                      (e) => DropdownMenuItem(
                                        value: e.$2,
                                        child: Text(e.$1),
                                      ),
                                    )
                                    .toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Generated URL
            if (_result != null) ...[
              const SizedBox(height: AppSpacing.m),
              _label('Generated URL'),
              const SizedBox(height: AppSpacing.xs),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.m),
                decoration: BoxDecoration(
                  color: AppColors.surfaceD.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: AppColors.greenD.withValues(alpha: 0.3),
                  ),
                ),
                child: SelectableText(
                  _result!.url,
                  style: TextStyle(
                    color: AppColors.greenD,
                    fontSize: AppTextSize.small,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 11,
                    color: AppColors.textD.withValues(alpha: 0.4),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Expires ${_result!.expiresAt.toLocal().toString().substring(0, 19)}',
                    style: TextStyle(
                      color: AppColors.textD.withValues(alpha: 0.4),
                      fontSize: AppTextSize.small,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap:
                        () => Clipboard.setData(
                          ClipboardData(text: _result!.url),
                        ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      child: Row(
                        children: [
                          Icon(
                            Icons.copy_rounded,
                            size: 12,
                            color: AppColors.secondaryD.withValues(alpha: 0.8),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            'Copy URL',
                            style: TextStyle(
                              color: AppColors.secondaryD,
                              fontSize: AppTextSize.small,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.m),
              _label('cURL Example'),
              const SizedBox(height: AppSpacing.xs),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.m),
                decoration: BoxDecoration(
                  color: AppColors.surfaceD.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SelectableText(
                        _curlExample(_result!),
                        style: TextStyle(
                          color: AppColors.textD.withValues(alpha: 0.8),
                          fontSize: AppTextSize.small,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap:
                          () => Clipboard.setData(
                            ClipboardData(text: _curlExample(_result!)),
                          ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        child: Icon(
                          Icons.copy_rounded,
                          size: 12,
                          color: AppColors.textD.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Close', style: TextStyle(color: AppColors.textD)),
        ),
        TextButton(
          onPressed: _result != null ? null : () {
            final key = _folderPrefix + _keyCtrl.text.trim();
            if (key.isEmpty) return;
            setState(() {
              _result = widget.ctrl.generatePresignedUrl(
                bucket: widget.bucket,
                key: key,
                operation: _op,
                expirySeconds: _expiry,
              );
            });
          },
          child: Text(
            'Generate',
            style: TextStyle(color: _result != null || (_folderPrefix + _keyCtrl.text.trim()).isEmpty ? AppColors.surfaceD : AppColors.secondaryD),
          ),
        ),
      ],
    );
  }

  String _curlExample(PresignedUrl p) {
    if (p.operation == 'PUT') {
      return 'curl -X PUT \\\n'
          '  "${p.url}" \\\n'
          '  --upload-file /path/to/file';
    }
    return 'curl -X GET \\\n'
        '  "${p.url}"';
  }

  Widget _label(String text) => Text(
    text,
    style: TextStyle(
      color: AppColors.textD.withValues(alpha: 0.5),
      fontSize: AppTextSize.small,
    ),
  );
}

class _SettingsDialog extends StatefulWidget {
  const _SettingsDialog({required this.ctrl});
  final MockS3Controller ctrl;

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _access;
  late final TextEditingController _secret;
  late final TextEditingController _region;

  @override
  void initState() {
    super.initState();
    final c = widget.ctrl.config.value;
    _host = TextEditingController(text: c.host);
    _port = TextEditingController(text: c.port.toString());
    _access = TextEditingController(text: c.accessKey);
    _secret = TextEditingController(text: c.secretKey);
    _region = TextEditingController(text: c.region);
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _access.dispose();
    _secret.dispose();
    _region.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.backgroundD,
      title: Text(
        'S3 Server Settings',
        style: TextStyle(color: AppColors.textD, fontSize: AppTextSize.title),
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Field(label: 'Host', ctrl: _host, hint: '127.0.0.1'),
            const SizedBox(height: AppSpacing.m),
            _Field(
              label: 'Port',
              ctrl: _port,
              hint: '9000',
              formatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: AppSpacing.m),
            _Field(label: 'Access Key', ctrl: _access, hint: 'mockondo'),
            const SizedBox(height: AppSpacing.m),
            _Field(label: 'Secret Key', ctrl: _secret, hint: 'mockondo123'),
            const SizedBox(height: AppSpacing.m),
            _Field(label: 'Region', ctrl: _region, hint: 'us-east-1'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: AppColors.textD)),
        ),
        TextButton(
          onPressed: () {
            widget.ctrl.updateConfig(
              S3Config(
                host: _host.text.trim(),
                port: int.tryParse(_port.text) ?? 9000,
                accessKey: _access.text.trim(),
                secretKey: _secret.text.trim(),
                region: _region.text.trim(),
              ),
            );
            if (widget.ctrl.isRunning.value) widget.ctrl.restartServer();
            Navigator.pop(context);
          },
          child: Text('Save', style: TextStyle(color: AppColors.secondaryD)),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.ctrl,
    required this.hint,
    this.formatters,
  });
  final String label;
  final TextEditingController ctrl;
  final String hint;
  final List<TextInputFormatter>? formatters;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.textD.withValues(alpha: 0.6),
              fontSize: AppTextSize.body,
            ),
          ),
        ),
        Expanded(
          child: CustomTextField(
            controller: ctrl,
            hintText: hint,
            textSize: AppTextSize.body,
            inputFormatters: formatters,
          ),
        ),
      ],
    );
  }
}
