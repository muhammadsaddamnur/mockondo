import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mockondo/core/colors.dart';
import 'package:mockondo/core/widgets/custom_textfield.dart';
import 'package:mockondo/features/settings/presentation/controllers/settings_controller.dart';
import 'package:url_launcher/url_launcher.dart';

enum _SettingsTab {
  remoteServer('Remote Server', Icons.cloud),
  about('About', Icons.info);

  final String label;
  final IconData icon;
  const _SettingsTab(this.label, this.icon);
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final ctrl = Get.put(SettingsController());
  late final TextEditingController _portCtrl;
  late final TextEditingController _keyCtrl;

  _SettingsTab _selectedTab = _SettingsTab.remoteServer;

  @override
  void initState() {
    super.initState();
    _portCtrl = TextEditingController(text: ctrl.port.value.toString());
    _keyCtrl = TextEditingController(text: ctrl.apiKey.value);
  }

  @override
  void dispose() {
    _portCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  // ── Endpoint reference list ───────────────────────────────────────────────

  static const _endpoints = [
    _EndpointEntry('GET', '/api/status', 'Overall app status'),
    _EndpointEntry('GET', '/api/agent-prompt', 'AI agent onboarding prompt'),
    _EndpointEntry('GET', '/api/projects', 'List all projects'),
    _EndpointEntry('POST', '/api/projects', 'Create project'),
    _EndpointEntry('GET', '/api/projects/:id', 'Get project detail'),
    _EndpointEntry('PUT', '/api/projects/:id', 'Update project'),
    _EndpointEntry('DELETE', '/api/projects/:id', 'Delete project'),
    _EndpointEntry('POST', '/api/projects/:id/start', 'Start mock server'),
    _EndpointEntry('POST', '/api/projects/:id/stop', 'Stop mock server'),
    _EndpointEntry('GET', '/api/projects/:id/endpoints', 'List HTTP endpoints'),
    _EndpointEntry('POST', '/api/projects/:id/endpoints', 'Add HTTP endpoint'),
    _EndpointEntry('GET', '/api/projects/:id/endpoints/:i', 'Get endpoint'),
    _EndpointEntry('PUT', '/api/projects/:id/endpoints/:i', 'Update endpoint'),
    _EndpointEntry(
      'DELETE',
      '/api/projects/:id/endpoints/:i',
      'Delete endpoint',
    ),
    _EndpointEntry('GET', '/api/projects/:id/endpoints/:i/rules', 'List rules'),
    _EndpointEntry('POST', '/api/projects/:id/endpoints/:i/rules', 'Add rule'),
    _EndpointEntry(
      'PUT',
      '/api/projects/:id/endpoints/:i/rules/:rid',
      'Update rule',
    ),
    _EndpointEntry(
      'DELETE',
      '/api/projects/:id/endpoints/:i/rules/:rid',
      'Delete rule',
    ),
    _EndpointEntry(
      'GET',
      '/api/projects/:id/ws-endpoints',
      'List WS endpoints',
    ),
    _EndpointEntry('POST', '/api/projects/:id/ws-endpoints', 'Add WS endpoint'),
    _EndpointEntry(
      'GET',
      '/api/projects/:id/ws-endpoints/:i',
      'Get WS endpoint',
    ),
    _EndpointEntry(
      'PUT',
      '/api/projects/:id/ws-endpoints/:i',
      'Update WS endpoint',
    ),
    _EndpointEntry(
      'DELETE',
      '/api/projects/:id/ws-endpoints/:i',
      'Delete WS endpoint',
    ),
    _EndpointEntry('GET', '/api/custom-data', 'List all custom data'),
    _EndpointEntry('GET', '/api/custom-data/:key', 'Get key values'),
    _EndpointEntry('POST', '/api/custom-data/:key', 'Set key values'),
    _EndpointEntry('PATCH', '/api/custom-data/:key', 'Append key values'),
    _EndpointEntry('DELETE', '/api/custom-data/:key', 'Delete key'),
    _EndpointEntry('GET', '/api/s3/config', 'Get S3 config'),
    _EndpointEntry('PUT', '/api/s3/config', 'Update S3 config'),
    _EndpointEntry('POST', '/api/s3/start', 'Start S3 server'),
    _EndpointEntry('POST', '/api/s3/stop', 'Stop S3 server'),
    _EndpointEntry('GET', '/api/s3/buckets', 'List buckets'),
    _EndpointEntry('POST', '/api/s3/buckets', 'Create bucket'),
    _EndpointEntry('DELETE', '/api/s3/buckets/:bucket', 'Delete bucket'),
    _EndpointEntry('GET', '/api/s3/objects/:bucket', 'List objects'),
    _EndpointEntry('DELETE', '/api/s3/objects/:bucket/:key', 'Delete object'),
    _EndpointEntry('POST', '/api/s3/presign', 'Generate presigned URL'),
    _EndpointEntry('GET', '/api/projects/:id/export/openapi', 'Export OpenAPI spec'),
    _EndpointEntry('GET', '/api/projects/:id/export/asyncapi', 'Export AsyncAPI spec'),
    _EndpointEntry('POST', '/api/projects/:id/import/openapi', 'Import OpenAPI spec'),
    _EndpointEntry('POST', '/api/projects/:id/import/asyncapi', 'Import AsyncAPI spec'),
    _EndpointEntry('GET', '/api/projects/:id/schema-to-code-prompt', 'Generate code prompt'),
    _EndpointEntry('GET', '/api/export', 'Export full workspace'),
  ];

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.backgroundD,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Sidebar ─────────────────────────────────────────────────────
          Container(
            width: 200,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: AppColors.textD.withValues(alpha: 0.1),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader('Settings'),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.m,
                      vertical: AppSpacing.m,
                    ),
                    children: [
                      for (final tab in _SettingsTab.values)
                        _SidebarItem(
                          label: tab.label,
                          icon: tab.icon,
                          selected: _selectedTab == tab,
                          onTap: () => setState(() => _selectedTab = tab),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Content ──────────────────────────────────────────────────────
          Expanded(
            child: _selectedTab == _SettingsTab.remoteServer
                ? _buildRemoteServerView()
                : _buildAboutView(),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String get _baseUrl => 'http://localhost:${ctrl.port.value}';

  Widget _sectionHeader(String title) => Container(
    height: 36,
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(color: AppColors.textD.withValues(alpha: 0.1)),
      ),
    ),
    alignment: Alignment.centerLeft,
    child: Text(
      title,
      style: const TextStyle(
        color: AppColors.textD,
        fontSize: AppTextSize.title,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _remoteServerCard() {
    return Obx(() {
      final running = ctrl.isRunning.value;
      final err = ctrl.errorMessage.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title row ──────────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: running ? AppColors.greenD : AppColors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              Text(
                'Remote Server',
                style: const TextStyle(
                  color: AppColors.textD,
                  fontSize: AppTextSize.title,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Switch(
                value: ctrl.enabled.value,
                activeThumbColor: AppColors.secondaryD,
                onChanged: (v) async {
                  await ctrl.toggleEnabled(v);
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Exposes a REST API so AI agents and external tools can '
            'create and manage all Mockondo features programmatically. ',
            style: TextStyle(
              color: AppColors.textD.withValues(alpha: 0.7),
              fontSize: AppTextSize.small,
            ),
          ),

          if (err != null) ...[
            const SizedBox(height: AppSpacing.m),
            Container(
              padding: const EdgeInsets.all(AppSpacing.m),
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.red.withValues(alpha: 0.4)),
              ),
              child: Text(
                err,
                style: const TextStyle(
                  color: AppColors.red,
                  fontSize: AppTextSize.small,
                ),
              ),
            ),
          ],

          if (running) ...[
            const SizedBox(height: AppSpacing.m),
            Text(
              'You can copy and paste the text below into your AI agent.',
              style: TextStyle(
                color: AppColors.textD.withValues(alpha: 0.7),
                fontSize: AppTextSize.small,
              ),
            ),
            const SizedBox(height: AppSpacing.m),

            _baseUrlChip(),
          ],

          const SizedBox(height: AppSpacing.xxl),

          // ── Port ─────────────────────────────────────────────────────
          _label('Port'),
          const SizedBox(height: AppSpacing.s),
          CustomTextField(
            controller: _portCtrl,
            hintText: '3131',
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (v) {
              final n = int.tryParse(v);
              if (n != null && n > 0 && n <= 65535) {
                ctrl.updatePort(n);
              }
            },
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Port the remote server listens on (default: 3131)',
            style: TextStyle(
              color: AppColors.textD.withValues(alpha: 0.5),
              fontSize: AppTextSize.small,
            ),
          ),

          const SizedBox(height: AppSpacing.l),

          // ── API Key ──────────────────────────────────────────────────
          _label('API Key (optional)'),
          const SizedBox(height: AppSpacing.s),
          CustomTextField(
            controller: _keyCtrl,
            hintText: 'Leave empty to disable authentication',
            onChanged: (v) => ctrl.updateApiKey(v),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'If set, all requests must include:\n'
            'Authorization: Bearer <key>',
            style: TextStyle(
              color: AppColors.textD.withValues(alpha: 0.5),
              fontSize: AppTextSize.small,
            ),
          ),

          if (running) ...[
            const SizedBox(height: AppSpacing.xxl),
            _restartButton(),
          ],
        ],
      );
    });
  }

  Widget _baseUrlChip() {
    final url =
        'Create a mock server using Mockondo. You can see the documentation at $_baseUrl';
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: url));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Prompt copied',
              style: TextStyle(color: AppColors.textD, fontSize: AppTextSize.body),
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: AppColors.backgroundD,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m,
          vertical: AppSpacing.s,
        ),
        decoration: BoxDecoration(
          color: AppColors.secondaryD.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: AppColors.secondaryD.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link, size: 12, color: AppColors.secondaryD),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: Text(
                url,
                style: const TextStyle(
                  color: AppColors.secondaryD,
                  fontSize: AppTextSize.body,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Icon(
              Icons.copy_outlined,
              size: 12,
              color: AppColors.secondaryD.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }

  Widget _restartButton() {
    return InkWell(
      onTap: () => ctrl.restart(),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m,
          vertical: AppSpacing.s,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.textD.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.refresh, size: 13, color: AppColors.textD),
            const SizedBox(width: AppSpacing.s),
            Text(
              'Restart Server',
              style: const TextStyle(
                color: AppColors.textD,
                fontSize: AppTextSize.body,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      color: AppColors.textD,
      fontSize: AppTextSize.body,
      fontWeight: FontWeight.w500,
    ),
  );

  Widget _buildRemoteServerView() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _remoteServerCard(),
            const SizedBox(height: AppSpacing.xxl),
            _label('API Endpoints'),
            const SizedBox(height: AppSpacing.m),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _endpoints.length,
              itemBuilder: (_, i) => _EndpointRow(
                entry: _endpoints[i],
                baseUrl: _baseUrl,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutView() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'About Mockondo',
              style: const TextStyle(
                color: AppColors.textD,
                fontSize: AppTextSize.title,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            Text(
              'Mockondo is a powerful mock server builder that enables developers to '
              'quickly create, manage, and test APIs without relying on backend services.',
              style: TextStyle(
                color: AppColors.textD.withValues(alpha: 0.7),
                fontSize: AppTextSize.body,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            _label('Features'),
            const SizedBox(height: AppSpacing.m),
            ...[
              'Create and manage HTTP endpoints with custom responses',
              'WebSocket support for real-time communication',
              'Rule-based response routing with conditional logic',
              'Custom data management for dynamic responses',
              'S3-compatible file storage',
              'HLS streaming support for media content',
              'OpenAPI 3.0 and AsyncAPI 2.6 import/export',
              'Remote REST API for programmatic control',
              'Response interpolation with custom variables',
              'Request/response logging and inspection',
            ].map((feature) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4, right: AppSpacing.s),
                    child: Icon(
                      Icons.check_circle,
                      size: 16,
                      color: AppColors.greenD,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      feature,
                      style: const TextStyle(
                        color: AppColors.textD,
                        fontSize: AppTextSize.body,
                      ),
                    ),
                  ),
                ],
              ),
            )),
            const SizedBox(height: AppSpacing.xxl),
            _label('Support'),
            const SizedBox(height: AppSpacing.m),
            GestureDetector(
              onTap: () async {
                final url = Uri.parse('https://github.com/sponsors/muhammadsaddamnur');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.m),
                decoration: BoxDecoration(
                  color: AppColors.secondaryD.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.secondaryD.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.favorite, size: 16, color: AppColors.secondaryD),
                    const SizedBox(width: AppSpacing.s),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sponsor on GitHub',
                            style: const TextStyle(
                              color: AppColors.secondaryD,
                              fontSize: AppTextSize.body,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Support Mockondo development by sponsoring @muhammadsaddamnur',
                            style: TextStyle(
                              color: AppColors.textD.withValues(alpha: 0.5),
                              fontSize: AppTextSize.small,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.open_in_new, size: 14, color: AppColors.secondaryD.withValues(alpha: 0.7)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

// ── Endpoint row widget ───────────────────────────────────────────────────────

// ── Sidebar item widget ──────────────────────────────────────────────────────

class _SidebarItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m,
          vertical: AppSpacing.m,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.secondaryD.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: selected
              ? Border.all(
                  color: AppColors.secondaryD.withValues(alpha: 0.3),
                )
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? AppColors.secondaryD : AppColors.textD,
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.secondaryD : AppColors.textD,
                  fontSize: AppTextSize.body,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Endpoint row widget ───────────────────────────────────────────────────────

class _EndpointEntry {
  final String method;
  final String path;
  final String description;

  const _EndpointEntry(this.method, this.path, this.description);
}

class _EndpointRow extends StatelessWidget {
  final _EndpointEntry entry;
  final String baseUrl;

  const _EndpointRow({required this.entry, required this.baseUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundD,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.textD.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          // Method badge
          Container(
            width: 56,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: AppColors.methodColor(
                entry.method,
              ).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(3),
            ),
            alignment: Alignment.center,
            child: Text(
              entry.method,
              style: TextStyle(
                color: AppColors.methodColor(entry.method),
                fontSize: AppTextSize.small,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.m),
          // Path
          Expanded(
            child: Text(
              entry.path,
              style: const TextStyle(
                color: AppColors.textD,
                fontSize: AppTextSize.body,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.m),
          // Description
          SizedBox(
            width: 200,
            child: Text(
              entry.description,
              style: TextStyle(
                color: AppColors.textD.withValues(alpha: 0.5),
                fontSize: AppTextSize.small,
              ),
            ),
          ),
          // Copy button
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: '$baseUrl${entry.path}'));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '$baseUrl${entry.path}',
                    style: const TextStyle(
                      color: AppColors.textD,
                      fontSize: AppTextSize.body,
                      fontFamily: 'monospace',
                    ),
                  ),
                  duration: const Duration(seconds: 2),
                  backgroundColor: AppColors.backgroundD,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.only(left: AppSpacing.s),
              child: Icon(
                Icons.copy_outlined,
                size: 12,
                color: AppColors.textD.withValues(alpha: 0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
