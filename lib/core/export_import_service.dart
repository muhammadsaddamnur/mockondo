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
import 'package:mockondo/features/http_client/presentation/controllers/http_client_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Current schema version written into every export file.
/// Increment this when the export format changes in a breaking way.
const _kExportVersion = 1;

/// Serialises and deserialises the full application state to/from a JSON file.
///
/// The exported JSON contains:
/// ```json
/// {
///   "version": 1,
///   "exported_at": "2026-03-29T12:00:00.000Z",
///   "mock_projects": [ ...MockData.toJson() ],
///   "custom_data":   { "key": ["value1", "value2"] },
///   "http_requests": [ ...HttpRequestItem.toJson() ],
///   "http_groups":   [ ...HttpRequestGroup.toJson() ]
/// }
/// ```
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
      final homeCtrl = Get.find<HomeController>();

      // Serialise mock projects (server is a runtime object — excluded).
      final mockProjects =
          homeCtrl.mockModels.map((m) => m?.toJson()).toList();

      // Serialise custom data: Map<String, RxList<String>> → plain Map.
      final customData = homeCtrl.customData.map(
        (k, v) => MapEntry(k, v.toList()),
      );

      // HttpClientController is only registered once the HTTP client tab has
      // been opened. If it is already in memory, read from it directly.
      // Otherwise fall back to SharedPreferences so no data is lost.
      List<Map<String, dynamic>> httpRequests;
      List<Map<String, dynamic>> httpGroups;

      if (Get.isRegistered<HttpClientController>()) {
        final httpCtrl = Get.find<HttpClientController>();
        httpRequests = httpCtrl.requests.map((r) => r.toJson()).toList();
        httpGroups = httpCtrl.groups.map((g) => g.toJson()).toList();
      } else {
        final prefs = await SharedPreferences.getInstance();
        final reqRaw = prefs.getString('http_client_requests');
        final grpRaw = prefs.getString('http_client_groups');
        httpRequests =
            reqRaw != null
                ? (jsonDecode(reqRaw) as List<dynamic>)
                    .whereType<Map<String, dynamic>>()
                    .toList()
                : [];
        httpGroups =
            grpRaw != null
                ? (jsonDecode(grpRaw) as List<dynamic>)
                    .whereType<Map<String, dynamic>>()
                    .toList()
                : [];
      }

      final payload = {
        'version': _kExportVersion,
        'exported_at': DateTime.now().toUtc().toIso8601String(),
        'mock_projects': mockProjects,
        'custom_data': customData,
        'http_requests': httpRequests,
        'http_groups': httpGroups,
      };

      final jsonString =
          const JsonEncoder.withIndent('  ').convert(payload);

      // Ask the user where to save the file.
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Mockondo settings',
        fileName: 'mockondo_export.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (savePath == null) return false; // User cancelled.

      final file = File(savePath);
      await file.writeAsString(jsonString, flush: true);

      if (context.mounted) {
        _snack(context, '✅ Exported to ${file.path}', success: true);
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
      // Ask the user to pick a .json file.
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

      // Validate version
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

      // Confirm before overwriting.
      if (!context.mounted) return false;
      final confirmed = await _confirmDialog(context);
      if (!confirmed) return false;

      final homeCtrl = Get.find<HomeController>();

      // If the HTTP client tab was never opened, register the controller now
      // so the imported data is available when the tab is opened later.
      final httpCtrl = Get.isRegistered<HttpClientController>()
          ? Get.find<HttpClientController>()
          : Get.put(HttpClientController());

      // ── Restore mock projects ──────────────────────────────────────
      final projectsJson =
          payload['mock_projects'] as List<dynamic>? ?? [];
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

      // ── Restore custom data ────────────────────────────────────────
      final customDataJson =
          payload['custom_data'] as Map<String, dynamic>? ?? {};
      homeCtrl.customData.value = customDataJson.map(
        (k, v) => MapEntry(
          k,
          RxList<String>.from((v as List<dynamic>).cast<String>()),
        ),
      );
      await homeCtrl.saveCustomData();

      // ── Restore HTTP client ────────────────────────────────────────
      final requestsJson =
          payload['http_requests'] as List<dynamic>? ?? [];
      httpCtrl.requests.value = requestsJson
          .whereType<Map<String, dynamic>>()
          .map(HttpRequestItem.fromJson)
          .toList();

      final groupsJson =
          payload['http_groups'] as List<dynamic>? ?? [];
      httpCtrl.groups.value = groupsJson
          .whereType<Map<String, dynamic>>()
          .map(HttpRequestGroup.fromJson)
          .toList();

      httpCtrl.saveRequests();

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

  /// Shows an [AlertDialog] asking the user to confirm the overwrite.
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
          'This will replace all current projects, endpoints, rules, custom data, '
          'and HTTP client requests. This action cannot be undone.',
          style: TextStyle(
            color: AppColors.textD.withValues(alpha: 0.75),
            fontSize: AppTextSize.body,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textD),
            ),
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

  /// Shows a brief [SnackBar] with a success or error message.
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
