import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:mockondo/core/interpolation.dart';
import 'package:mockondo/features/http_client/data/models/http_client_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/v4.dart';

/// GetX controller for the built-in HTTP client feature.
///
/// Manages the sidebar request/group list, tracks the selected request,
/// sends HTTP requests, and persists everything to SharedPreferences.
class HttpClientController extends GetxController {
  /// All saved requests across all groups.
  final requests = <HttpRequestItem>[].obs;

  /// All saved groups (folders in the sidebar).
  final groups = <HttpRequestGroup>[].obs;

  /// Index into [requests] of the currently open request.
  final selectedIndex = 0.obs;

  /// 0 = HTTP, 1 = WebSocket. Persisted so tab survives page navigation.
  final clientTab = 0.obs;

  /// `true` while a request is in flight.
  final isLoading = false.obs;

  /// The result of the last completed request, or `null` if none.
  final response = Rxn<HttpResponseResult>();

  /// Human-readable error from the last failed request, or `null`.
  final errorMessage = RxnString();

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  /// The currently selected [HttpRequestItem], or `null` when the list is empty.
  HttpRequestItem? get selected =>
      requests.isEmpty ? null : requests[selectedIndex.value];

  // ── Selection ──────────────────────────────────────────────────────────────

  /// Selects the request at [index] and clears the previous response.
  void selectRequest(int index) {
    selectedIndex.value = index;
    response.value = null;
    errorMessage.value = null;
  }

  // ── Request CRUD ───────────────────────────────────────────────────────────

  /// Creates a new request (optionally in [groupId]) and selects it.
  void addRequest({String? groupId}) {
    requests.add(
      HttpRequestItem(
        id: UuidV4().generate(),
        name: 'New Request',
        method: 'GET',
        headers: [KeyValuePair(key: 'Content-Type', value: 'application/json')],
        params: [],
        groupId: groupId,
      ),
    );
    selectedIndex.value = requests.length - 1;
    response.value = null;
    errorMessage.value = null;
    _save();
  }

  /// Creates a deep copy of the request at [index] and inserts it below.
  void duplicateRequest(int index) {
    final original = requests[index];
    final copy = HttpRequestItem(
      id: UuidV4().generate(),
      name: '${original.name} (copy)',
      method: original.method,
      url: original.url,
      headers: original.headers.map((e) => e.copyWith()).toList(),
      params: original.params.map((e) => e.copyWith()).toList(),
      body: original.body,
      bodyType: original.bodyType,
      formData: original.formData.map((e) => e.copyWith()).toList(),
      groupId: original.groupId,
    );
    requests.insert(index + 1, copy);
    selectedIndex.value = index + 1;
    _save();
  }

  /// Removes the request at [index] and adjusts [selectedIndex].
  void deleteRequest(int index) {
    requests.removeAt(index);
    if (requests.isEmpty) {
      response.value = null;
    } else if (selectedIndex.value >= requests.length) {
      selectedIndex.value = requests.length - 1;
    }
    _save();
  }

  /// Replaces the selected request with [updated] and persists.
  void updateSelected(HttpRequestItem updated) {
    if (requests.isEmpty) return;
    requests[selectedIndex.value] = updated;
    _save();
  }

  /// Explicitly persists the current state. Call this after bulk edits that
  /// go through mutable fields rather than [updateSelected].
  void saveRequests() => _save();

  // ── Group management ───────────────────────────────────────────────────────

  /// Creates a new group with the given [name].
  void addGroup(String name) {
    groups.add(HttpRequestGroup(id: UuidV4().generate(), name: name));
    _save();
  }

  /// Renames the group identified by [id].
  void renameGroup(String id, String name) {
    final idx = groups.indexWhere((g) => g.id == id);
    if (idx == -1) return;
    groups[idx] = groups[idx].copyWith(name: name);
    _save();
  }

  /// Deletes the group identified by [id].
  ///
  /// When [deleteRequests] is `true`, all requests in the group are also
  /// deleted. Otherwise they are moved to the ungrouped list.
  void deleteGroup(String id, {bool deleteRequests = false}) {
    if (deleteRequests) {
      requests.removeWhere((r) => r.groupId == id);
      if (selectedIndex.value >= requests.length && requests.isNotEmpty) {
        selectedIndex.value = requests.length - 1;
      }
    } else {
      // Ungroup all requests that belong to the deleted group.
      for (final req in requests) {
        if (req.groupId == id) req.groupId = null;
      }
      requests.refresh();
    }
    groups.removeWhere((g) => g.id == id);
    _save();
  }

  /// Toggles the expanded/collapsed state of the group without persisting
  /// (purely UI state).
  void toggleGroup(String id) {
    final idx = groups.indexWhere((g) => g.id == id);
    if (idx == -1) return;
    groups[idx] = groups[idx].copyWith(isExpanded: !groups[idx].isExpanded);
  }

  /// Moves the request at [requestIndex] into [groupId] (or ungrouped when
  /// [groupId] is `null`).
  void moveRequestToGroup(int requestIndex, String? groupId) {
    requests[requestIndex].groupId = groupId;
    requests.refresh();
    _save();
  }

  // ── Sidebar list ───────────────────────────────────────────────────────────

  /// Builds the flat, visible list used by the drag-and-drop sidebar.
  ///
  /// The list is ordered as:
  ///   1. Group header followed by its expanded requests (for each group).
  ///   2. All ungrouped requests (or requests whose group no longer exists).
  List<Object> buildVisibleFlatList() {
    final result = <Object>[];
    final validGroupIds = groups.map((g) => g.id).toSet();

    for (final group in groups) {
      result.add(group);
      if (group.isExpanded) {
        for (final req in requests) {
          if (req.groupId == group.id) result.add(req);
        }
      }
    }

    // Append requests that don't belong to any existing group.
    for (final req in requests) {
      if (req.groupId == null || !validGroupIds.contains(req.groupId)) {
        result.add(req);
      }
    }

    return result;
  }

  /// Handles a drag-reorder event in the sidebar.
  ///
  /// When a [HttpRequestGroup] is moved, only the groups list is re-ordered.
  /// When a [HttpRequestItem] is moved, its [groupId] is updated based on the
  /// nearest group header above its new position, and the requests list order
  /// is rebuilt accordingly.
  void reorderSidebar(int oldIdx, int newIdx) {
    if (newIdx > oldIdx) newIdx--;
    if (oldIdx == newIdx) return;

    final flat = buildVisibleFlatList();
    if (oldIdx >= flat.length) return;

    final moved = flat[oldIdx];
    final reordered = List<Object>.from(flat);
    reordered.removeAt(oldIdx);
    reordered.insert(newIdx.clamp(0, reordered.length), moved);

    if (moved is HttpRequestGroup) {
      groups.value = reordered.whereType<HttpRequestGroup>().toList();
    } else if (moved is HttpRequestItem) {
      // Determine new groupId: scan backwards to find the nearest group header.
      final movedPos = reordered.indexOf(moved);
      String? newGroupId;
      for (int i = movedPos - 1; i >= 0; i--) {
        if (reordered[i] is HttpRequestGroup) {
          newGroupId = (reordered[i] as HttpRequestGroup).id;
          break;
        }
      }
      moved.groupId = newGroupId;

      // Rebuild the master requests list in the new sidebar order.
      final visibleIds =
          flat.whereType<HttpRequestItem>().map((r) => r.id).toSet();
      final nonVisible =
          requests.where((r) => !visibleIds.contains(r.id)).toList();
      final validIds = groups.map((g) => g.id).toSet();
      final newOrder = <HttpRequestItem>[];

      for (final group in groups) {
        if (!group.isExpanded) {
          // Collapsed groups keep hidden items at the front.
          newOrder.addAll(nonVisible.where((r) => r.groupId == group.id));
          newOrder.addAll(
            reordered.whereType<HttpRequestItem>().where((r) => r.groupId == group.id),
          );
        } else {
          newOrder.addAll(
            reordered.whereType<HttpRequestItem>().where((r) => r.groupId == group.id),
          );
        }
      }
      // Append ungrouped requests at the end.
      newOrder.addAll(
        reordered.whereType<HttpRequestItem>().where(
          (r) => r.groupId == null || !validIds.contains(r.groupId),
        ),
      );

      // Preserve the current selection by ID.
      final selId = requests.isEmpty ? null : requests[selectedIndex.value].id;
      requests.value = newOrder;
      if (selId != null) {
        final si = requests.indexWhere((r) => r.id == selId);
        if (si != -1) selectedIndex.value = si;
      }
    }

    _save();
  }

  // ── HTTP send ──────────────────────────────────────────────────────────────

  /// Sends the currently selected request and stores the result in [response].
  ///
  /// - Enabled query params are merged into the URL.
  /// - Enabled headers are sent with the request.
  /// - `formData` body type is URL-encoded; other types send [body] as-is.
  /// - Connection and client errors are caught and stored in [errorMessage].
  Future<void> sendRequest() async {
    final req = selected;
    if (req == null) return;

    isLoading.value = true;
    response.value = null;
    errorMessage.value = null;

    try {
      // Helper: resolve all ${...} interpolation placeholders in a string.
      final interp = Interpolation();
      String ip(String s) => interp.excute(before: s, data: '');

      // Merge enabled query params into the URL.
      var urlStr = ip(req.url.trim());
      final enabledParams =
          req.params.where((p) => p.enabled && p.key.isNotEmpty).toList();
      if (enabledParams.isNotEmpty) {
        final uri = Uri.tryParse(urlStr);
        if (uri != null) {
          final queryParams = Map<String, String>.from(uri.queryParameters);
          for (final p in enabledParams) {
            queryParams[ip(p.key)] = ip(p.value);
          }
          urlStr = uri.replace(queryParameters: queryParams).toString();
        }
      }

      final uri = Uri.parse(urlStr);

      // Collect enabled request headers.
      final headers = <String, String>{};
      for (final h in req.headers) {
        if (h.enabled && h.key.isNotEmpty) {
          headers[ip(h.key)] = ip(h.value);
        }
      }

      final stopwatch = Stopwatch()..start();

      // Build the request body.
      String? body;
      bool usedMultipart = false;

      if (req.bodyType == RequestBodyType.binary) {
        // Send raw file bytes as the request body (no interpolation on file paths).
        final filePath = req.body.trim();
        if (filePath.isNotEmpty) {
          final fileBytes = await File(filePath).readAsBytes();
          final request = http.Request(req.method, uri);
          request.headers.addAll(headers);
          if (!request.headers.containsKey('Content-Type')) {
            request.headers['Content-Type'] = 'application/octet-stream';
          }
          request.bodyBytes = fileBytes;
          final streamed = await request.send();
          final httpResponse = await http.Response.fromStream(streamed);
          stopwatch.stop();
          response.value = HttpResponseResult(
            statusCode: httpResponse.statusCode,
            body: httpResponse.body,
            headers: httpResponse.headers,
            durationMs: stopwatch.elapsedMilliseconds,
          );
          usedMultipart = true; // marks "response already set"
        }
      } else if (req.bodyType == RequestBodyType.formData) {
        final enabled =
            req.formData.where((f) => f.enabled && f.key.isNotEmpty).toList();
        final hasFile =
            enabled.any((f) => f.type == RequestFormFieldType.file);

        if (hasFile) {
          // multipart/form-data
          usedMultipart = true;
          final multipart = http.MultipartRequest(req.method, uri);
          headers.remove('Content-Type'); // let http set boundary
          multipart.headers.addAll(headers);
          for (final f in enabled) {
            if (f.type == RequestFormFieldType.file &&
                f.filePath != null &&
                f.filePath!.isNotEmpty) {
              multipart.files.add(
                await http.MultipartFile.fromPath(ip(f.key), f.filePath!,
                    filename: f.displayFileName),
              );
            } else {
              multipart.fields[ip(f.key)] = ip(f.value);
            }
          }
          final streamed = await multipart.send();
          final httpResponse = await http.Response.fromStream(streamed);
          stopwatch.stop();
          response.value = HttpResponseResult(
            statusCode: httpResponse.statusCode,
            body: httpResponse.body,
            headers: httpResponse.headers,
            durationMs: stopwatch.elapsedMilliseconds,
          );
        } else if (enabled.isNotEmpty) {
          // application/x-www-form-urlencoded (text fields only)
          body = enabled
              .map((f) =>
                  '${Uri.encodeQueryComponent(ip(f.key))}=${Uri.encodeQueryComponent(ip(f.value))}')
              .join('&');
          headers['Content-Type'] = 'application/x-www-form-urlencoded';
        }
      } else {
        body = req.body.isEmpty ? null : ip(req.body);
      }

      if (usedMultipart) {
        // Response already set inside the multipart branch above.
      } else {
        http.Response httpResponse;

        switch (req.method) {
          case 'GET':
            httpResponse = await http.get(uri, headers: headers);
            break;
          case 'POST':
            httpResponse = await http.post(uri, headers: headers, body: body);
            break;
          case 'PUT':
            httpResponse = await http.put(uri, headers: headers, body: body);
            break;
          case 'PATCH':
            httpResponse =
                await http.patch(uri, headers: headers, body: body);
            break;
          case 'DELETE':
            httpResponse =
                await http.delete(uri, headers: headers, body: body);
            break;
          case 'HEAD':
            httpResponse = await http.head(uri, headers: headers);
            break;
          default:
            httpResponse = await http.get(uri, headers: headers);
        }

        stopwatch.stop();

        response.value = HttpResponseResult(
          statusCode: httpResponse.statusCode,
          body: httpResponse.body,
          headers: httpResponse.headers,
          durationMs: stopwatch.elapsedMilliseconds,
        );
      }
    } on SocketException catch (e) {
      errorMessage.value = 'Connection error: ${e.message}';
    } on http.ClientException catch (e) {
      errorMessage.value = 'Request failed: ${e.message}';
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  // ── Persistence ────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'http_client_requests',
      jsonEncode(requests.map((r) => r.toJson()).toList()),
    );
    await prefs.setString(
      'http_client_groups',
      jsonEncode(groups.map((g) => g.toJson()).toList()),
    );
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();

    final reqData = prefs.getString('http_client_requests');
    if (reqData != null) {
      try {
        final list = jsonDecode(reqData) as List<dynamic>;
        requests.value = list
            .map((e) => HttpRequestItem.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    final groupData = prefs.getString('http_client_groups');
    if (groupData != null) {
      try {
        final list = jsonDecode(groupData) as List<dynamic>;
        groups.value = list
            .map((e) => HttpRequestGroup.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
  }
}
