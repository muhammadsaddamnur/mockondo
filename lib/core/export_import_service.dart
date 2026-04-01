import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mockondo/core/colors.dart';
import 'package:mockondo/core/mock_model.dart';
import 'package:mockondo/core/server.dart';
import 'package:mockondo/features/home/presentation/controllers/home_controller.dart';
import 'package:mockondo/features/http_client/data/models/http_client_model.dart';
import 'package:mockondo/features/http_client/data/models/ws_client_model.dart';
import 'package:mockondo/features/http_client/presentation/controllers/http_client_controller.dart';
import 'package:mockondo/features/http_client/presentation/controllers/ws_client_controller.dart';
import 'package:mockondo/features/mock_s3/data/models/s3_model.dart';
import 'package:mockondo/features/mock_s3/presentation/controllers/mock_s3_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Current schema version written into every export file.
/// Increment this when the export format changes in a breaking way.
const _kExportVersion = 2;

/// Serialises and deserialises the full application state to/from a JSON file.
///
/// The exported JSON contains:
/// ```json
/// {
///   "version": 2,
///   "exported_at": "2026-03-29T12:00:00.000Z",
///   "mock_projects":  [ ...MockData.toJson() ],
///   "custom_data":    { "key": ["value1", "value2"] },
///   "http_requests":  [ ...HttpRequestItem.toJson() ],
///   "http_groups":    [ ...HttpRequestGroup.toJson() ],
///   "ws_connections": [ ...WsClientItem.toJson() ],
///   "s3_config":      { ...S3Config.toJson() },
///   "s3_buckets":     [ ...S3Bucket.toJson() ],
///   "s3_objects":     [ ...S3Object.toJson() ]
/// }
/// ```
/// Note: actual S3 object file content is not included in the export.
class ExportImportService {
  ExportImportService._();

  // ── Export ─────────────────────────────────────────────────────────────────

  /// Collects all application data, serialises it to JSON, and opens a
  /// system save dialog so the user can choose where to write the file.
  ///
  /// Returns `true` on success, `false` if the user cancelled or an error
  /// occurred. Shows a [SnackBar] on both outcomes.
  static Future<bool> export(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final homeCtrl = Get.find<HomeController>();

      // ── Mock projects + custom data ──────────────────────────────────
      final mockProjects =
          homeCtrl.mockModels.map((m) => m?.toJson()).toList();

      final customData = homeCtrl.customData.map(
        (k, v) => MapEntry(k, v.toList()),
      );

      // ── HTTP client ──────────────────────────────────────────────────
      List<Map<String, dynamic>> httpRequests;
      List<Map<String, dynamic>> httpGroups;

      if (Get.isRegistered<HttpClientController>()) {
        final httpCtrl = Get.find<HttpClientController>();
        httpRequests = httpCtrl.requests.map((r) => r.toJson()).toList();
        httpGroups = httpCtrl.groups.map((g) => g.toJson()).toList();
      } else {
        final reqRaw = prefs.getString('http_client_requests');
        final grpRaw = prefs.getString('http_client_groups');
        httpRequests = reqRaw != null
            ? (jsonDecode(reqRaw) as List).whereType<Map<String, dynamic>>().toList()
            : [];
        httpGroups = grpRaw != null
            ? (jsonDecode(grpRaw) as List).whereType<Map<String, dynamic>>().toList()
            : [];
      }

      // ── WebSocket client ─────────────────────────────────────────────
      List<Map<String, dynamic>> wsConnections;

      if (Get.isRegistered<WsClientController>()) {
        final wsCtrl = Get.find<WsClientController>();
        wsConnections = wsCtrl.items.map((i) => i.toJson()).toList();
      } else {
        final wsRaw = prefs.getString('ws_client_items');
        wsConnections = wsRaw != null
            ? (jsonDecode(wsRaw) as List).whereType<Map<String, dynamic>>().toList()
            : [];
      }

      // ── Mock S3 ──────────────────────────────────────────────────────
      Map<String, dynamic> s3Config;
      List<Map<String, dynamic>> s3Buckets;
      List<Map<String, dynamic>> s3Objects;

      if (Get.isRegistered<MockS3Controller>()) {
        final s3Ctrl = Get.find<MockS3Controller>();
        s3Config = s3Ctrl.config.value.toJson();
        s3Buckets = s3Ctrl.buckets.map((b) => b.toJson()).toList();
        s3Objects = s3Ctrl.objects.map((o) => o.toJson()).toList();
      } else {
        final cfgRaw = prefs.getString('mock_s3_config');
        final bktRaw = prefs.getString('mock_s3_buckets');
        final objRaw = prefs.getString('mock_s3_objects');
        s3Config = cfgRaw != null
            ? jsonDecode(cfgRaw) as Map<String, dynamic>
            : const S3Config().toJson();
        s3Buckets = bktRaw != null
            ? (jsonDecode(bktRaw) as List).whereType<Map<String, dynamic>>().toList()
            : [];
        s3Objects = objRaw != null
            ? (jsonDecode(objRaw) as List).whereType<Map<String, dynamic>>().toList()
            : [];
      }

      final payload = {
        'version': _kExportVersion,
        'exported_at': DateTime.now().toUtc().toIso8601String(),
        'mock_projects': mockProjects,
        'custom_data': customData,
        'http_requests': httpRequests,
        'http_groups': httpGroups,
        'ws_connections': wsConnections,
        's3_config': s3Config,
        's3_buckets': s3Buckets,
        's3_objects': s3Objects,
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(payload);

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Mockondo settings',
        fileName: 'mockondo_export.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (savePath == null) return false;

      await File(savePath).writeAsString(jsonString, flush: true);

      if (context.mounted) {
        _snack(context, '✅ Exported to $savePath', success: true);
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        _snack(context, '❌ Export failed: $e', success: false);
      }
      return false;
    }
  }

  // ── Import ─────────────────────────────────────────────────────────────────

  /// Opens a file picker, reads the selected JSON file, and restores all
  /// application data from it.
  ///
  /// Shows a confirmation dialog before overwriting existing data.
  /// Returns `true` on success, `false` if cancelled or an error occurred.
  static Future<bool> import(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Import Mockondo settings',
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return false;

      final filePath = result.files.single.path;
      if (filePath == null) return false;

      final jsonString = await File(filePath).readAsString();
      final Map<String, dynamic> payload =
          jsonDecode(jsonString) as Map<String, dynamic>;

      final version = payload['version'] as int? ?? 0;
      if (version > _kExportVersion) {
        if (context.mounted) {
          _snack(
            context,
            '❌ This file was exported from a newer version of Mockondo.',
            success: false,
          );
        }
        return false;
      }

      if (!context.mounted) return false;
      final confirmed = await _confirmDialog(context);
      if (!confirmed) return false;

      final prefs = await SharedPreferences.getInstance();
      final homeCtrl = Get.find<HomeController>();

      // ── Mock projects ────────────────────────────────────────────────
      final projectsJson = payload['mock_projects'] as List<dynamic>? ?? [];
      homeCtrl.mockModels.value = projectsJson
          .whereType<Map<String, dynamic>>()
          .map((e) => MockData.fromJson(e)..server = MainServer())
          .toList();

      if (homeCtrl.mockModels.isNotEmpty) {
        homeCtrl.selectedMockModelIndex.value = 0;
        homeCtrl.hostController.value.text =
            homeCtrl.mockModels.first?.host ?? '';
        homeCtrl.portController.value.text =
            (homeCtrl.mockModels.first?.port ?? 8080).toString();
      }

      await homeCtrl.save();

      // ── Custom data ──────────────────────────────────────────────────
      final customDataJson =
          payload['custom_data'] as Map<String, dynamic>? ?? {};
      homeCtrl.customData.value = customDataJson.map(
        (k, v) => MapEntry(
          k,
          RxList<String>.from((v as List<dynamic>).cast<String>()),
        ),
      );
      await homeCtrl.saveCustomData();

      // ── HTTP client ──────────────────────────────────────────────────
      final httpCtrl = Get.isRegistered<HttpClientController>()
          ? Get.find<HttpClientController>()
          : Get.put(HttpClientController());

      final requestsJson = payload['http_requests'] as List<dynamic>? ?? [];
      httpCtrl.requests.value = requestsJson
          .whereType<Map<String, dynamic>>()
          .map(HttpRequestItem.fromJson)
          .toList();

      final groupsJson = payload['http_groups'] as List<dynamic>? ?? [];
      httpCtrl.groups.value = groupsJson
          .whereType<Map<String, dynamic>>()
          .map(HttpRequestGroup.fromJson)
          .toList();

      httpCtrl.saveRequests();

      // ── WebSocket client ─────────────────────────────────────────────
      final wsJson = payload['ws_connections'] as List<dynamic>? ?? [];
      final wsItems = wsJson
          .whereType<Map<String, dynamic>>()
          .map(WsClientItem.fromJson)
          .toList();

      if (Get.isRegistered<WsClientController>()) {
        final wsCtrl = Get.find<WsClientController>();
        wsCtrl.items.value = wsItems;
        wsCtrl.saveItems();
      } else {
        await prefs.setString(
          'ws_client_items',
          jsonEncode(wsItems.map((i) => i.toJson()).toList()),
        );
      }

      // ── Mock S3 ──────────────────────────────────────────────────────
      final s3ConfigJson =
          payload['s3_config'] as Map<String, dynamic>? ?? {};
      final s3BucketsJson = payload['s3_buckets'] as List<dynamic>? ?? [];
      final s3ObjectsJson = payload['s3_objects'] as List<dynamic>? ?? [];

      final s3Config = s3ConfigJson.isNotEmpty
          ? S3Config.fromJson(s3ConfigJson)
          : const S3Config();
      final s3Buckets = s3BucketsJson
          .whereType<Map<String, dynamic>>()
          .map(S3Bucket.fromJson)
          .toList();
      final s3Objects = s3ObjectsJson
          .whereType<Map<String, dynamic>>()
          .map(S3Object.fromJson)
          .toList();

      if (Get.isRegistered<MockS3Controller>()) {
        final s3Ctrl = Get.find<MockS3Controller>();
        s3Ctrl.config.value = s3Config;
        s3Ctrl.buckets.value = s3Buckets;
        s3Ctrl.objects.value = s3Objects;
      }

      // Always write S3 data to SharedPrefs so it loads correctly on next start.
      await prefs.setString('mock_s3_config', jsonEncode(s3Config.toJson()));
      await prefs.setString(
        'mock_s3_buckets',
        jsonEncode(s3Buckets.map((b) => b.toJson()).toList()),
      );
      await prefs.setString(
        'mock_s3_objects',
        jsonEncode(s3Objects.map((o) => o.toJson()).toList()),
      );

      if (context.mounted) {
        _snack(context, '✅ Import successful', success: true);
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        _snack(context, '❌ Import failed: $e', success: false);
      }
      return false;
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static Future<bool> _confirmDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundD,
        title: Text(
          'Import?',
          style: TextStyle(color: AppColors.textD, fontSize: AppTextSize.title),
        ),
        content: Text(
          'This will replace all current data including mock projects, endpoints, '
          'custom data, HTTP client requests, WebSocket connections, and S3 settings. '
          'S3 file content stored on disk is not affected. This action cannot be undone.',
          style: TextStyle(
            color: AppColors.textD.withValues(alpha: 0.75),
            fontSize: AppTextSize.body,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textD)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(elevation: 0),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Import',
              style: TextStyle(fontSize: AppTextSize.body),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static void _snack(
    BuildContext context,
    String message, {
    required bool success,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: success ? AppColors.greenD : AppColors.red,
            fontSize: AppTextSize.body,
          ),
        ),
        backgroundColor: AppColors.backgroundD,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
