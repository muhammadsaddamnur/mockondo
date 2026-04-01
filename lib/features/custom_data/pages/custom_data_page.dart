import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mockondo/core/colors.dart';
import 'package:mockondo/core/widgets/button_widget.dart';
import 'package:mockondo/features/home/presentation/controllers/home_controller.dart';
import 'package:mockondo/features/home/presentation/widgets/input_custom_dialog_widget.dart';

/// Modal dialog for managing the user-defined custom data store.
///
/// Presents a split-pane layout:
///   - **Left panel** — list of keys (category names, e.g. "cities").
///   - **Right panel** — list of values for the selected key.
///
/// Keys and values can be added, renamed, and deleted inline. Changes are
/// persisted to SharedPreferences when the user taps **Save Changes**.
class CustomDataPage extends StatelessWidget {
  CustomDataPage({super.key});
  final homeController = Get.find<HomeController>();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s),
      decoration: BoxDecoration(
        color: AppColors.backgroundD,
        borderRadius: BorderRadius.circular(AppSpacing.l),
      ),
      child: Column(
        children: [
          // ── Header ─────────────────────────────────────────────────────────
          Row(
            children: [
              Icon(Icons.data_object, size: 16, color: AppColors.secondaryD),
              const SizedBox(width: AppSpacing.s),
              Text(
                'Custom Data',
                style: TextStyle(
                  color: AppColors.textD,
                  fontSize: AppTextSize.title,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          Divider(height: 1, color: AppColors.textD.withValues(alpha: 0.12)),
          const SizedBox(height: AppSpacing.m),

          // ── Split pane ─────────────────────────────────────────────────────
          Expanded(
            child: Row(
              children: [
                // LEFT: Keys
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader(
                        title: 'Keys',
                        onAdd:
                            () => _showInputDialog(
                              context,
                              title: 'Add Key',
                              onTap: (input) {
                                if (homeController.customData.containsKey(
                                  input,
                                )) {
                                  return;
                                }
                                homeController.customData.addAll({
                                  input: <String>[].obs,
                                });
                              },
                            ),
                      ),
                      const SizedBox(height: AppSpacing.s),
                      Expanded(
                        child: Obx(() {
                          final keys = homeController.customData.keys.toList();
                          if (keys.isEmpty) return _EmptyState('No keys yet');
                          return _DataList(
                            items: keys,
                            selectedValue:
                                homeController.selectedCustomDataKey.value,
                            onTap: (k) {
                              homeController.selectedCustomDataKey.value = k;
                              // Clear value selection when switching keys.
                              homeController.selectedCustomDataValue.value =
                                  null;
                            },
                            onEdit: (k, input) {
                              if (homeController.customData.containsKey(
                                input,
                              )) {
                                return;
                              }
                              final oldData =
                                  homeController.customData[k] ??
                                  <String>[].obs;
                              homeController.customData.removeWhere(
                                (key, _) => key == k,
                              );
                              homeController.customData.addAll({
                                input: oldData,
                              });
                            },
                            onDelete:
                                (k) => homeController.customData.removeWhere(
                                  (key, _) => key == k,
                                ),
                            context: context,
                          );
                        }),
                      ),
                    ],
                  ),
                ),

                // Vertical divider between panels
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
                  color: AppColors.textD.withValues(alpha: 0.12),
                ),

                // RIGHT: Values for the selected key
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Obx(() {
                        final key = homeController.selectedCustomDataKey.value;
                        return _SectionHeader(
                          title: key.isEmpty ? 'Values' : 'Values of "$key"',
                          // Disable the add button when no key is selected.
                          onAdd:
                              key.isEmpty
                                  ? null
                                  : () => _showInputDialog(
                                    context,
                                    title: 'Add Value',
                                    isCodeEditor: true,
                                    onTap: (input) {
                                      if (homeController.customData[key]
                                              ?.contains(input) ??
                                          true) {
                                        return;
                                      }
                                      homeController.customData[key]?.add(
                                        input,
                                      );
                                    },
                                  ),
                        );
                      }),
                      const SizedBox(height: AppSpacing.s),
                      Expanded(
                        child: Obx(() {
                          final key =
                              homeController.selectedCustomDataKey.value;
                          if (key.isEmpty) {
                            return _EmptyState('Select a key to view values');
                          }
                          final values =
                              homeController.customData[key] ?? <String>[].obs;
                          if (values.isEmpty) {
                            return _EmptyState('No values yet');
                          }
                          return _DataList(
                            items: values,
                            selectedValue:
                                homeController.selectedCustomDataValue.value ??
                                '',
                            onTap:
                                (v) =>
                                    homeController
                                        .selectedCustomDataValue
                                        .value = v,
                            onEdit: (v, input) {
                              if (values.contains(input)) return;
                              homeController.customData[key]?.remove(v);
                              homeController.customData[key]?.add(input);
                            },
                            onDelete:
                                (v) =>
                                    homeController.customData[key]?.remove(v),
                            context: context,
                            isCodeEditor: true,
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.m),
          Divider(height: 1, color: AppColors.textD.withValues(alpha: 0.12)),
          const SizedBox(height: AppSpacing.m),

          // ── Footer ─────────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // TextButton(
              //   onPressed: () => Navigator.pop(context),
              //   child: Text(
              //     'Cancel',
              //     style: TextStyle(
              //       color: AppColors.textD,
              //       fontSize: AppTextSize.body,
              //     ),
              //   ),
              // ),
              // const SizedBox(width: AppSpacing.m),
              // ButtonWidget(
              //   onTap: () async {
              //     homeController.saveCustomData();
              //     // Navigator.pop(context);
              //   },
              //   color: AppColors.secondaryD,
              //   child: const Text(
              //     'Save Changes',
              //     style: TextStyle(fontSize: AppTextSize.body),
              //   ),
              // ),
            ],
          ),
        ],
      ),
    );
  }

  void _showInputDialog(
    BuildContext context, {
    required Function(String) onTap,
    String? title,
    bool isCodeEditor = false,
  }) {
    showDialog(
      context: context,
      builder:
          (_) => InputCustomDialogWidget(
            title: title,
            isCodeEditor: isCodeEditor,
            onTap: (x) {
              onTap(x);
              homeController.saveCustomData();
            },
          ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

/// A row with a title label and an add (+) icon button.
/// The icon is dimmed and non-interactive when [onAdd] is `null`.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onAdd});
  final String title;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textD,
              fontSize: AppTextSize.body,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        InkWell(
          onTap: onAdd,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: Icon(
              Icons.add,
              size: 16,
              color:
                  onAdd != null
                      ? AppColors.greenD
                      : AppColors.textD.withValues(alpha: 0.2),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────

/// Centred italic placeholder shown when a list is empty.
class _EmptyState extends StatelessWidget {
  const _EmptyState(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.textD.withValues(alpha: 0.35),
          fontSize: AppTextSize.small,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

// ── Data list ──────────────────────────────────────────────────────────────────

/// A scrollable list of string items with selection highlight, edit, and
/// delete actions per row.
class _DataList extends StatelessWidget {
  const _DataList({
    required this.items,
    required this.selectedValue,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.context,
    this.isCodeEditor = false,
  });

  final List<String> items;
  final String selectedValue;
  final ValueChanged<String> onTap;
  final void Function(String item, String newValue) onEdit;
  final ValueChanged<String> onDelete;
  final BuildContext context;
  final bool isCodeEditor;

  @override
  Widget build(BuildContext _) {
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder:
          (_, __) => Divider(
            height: 1,
            color: AppColors.textD.withValues(alpha: 0.08),
          ),
      itemBuilder: (_, index) {
        final item = items[index];
        final isSelected = item == selectedValue;
        return InkWell(
          onTap: () => onTap(item),
          child: Container(
            color:
                isSelected
                    ? AppColors.secondaryD.withValues(alpha: 0.12)
                    : Colors.transparent,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.m,
              vertical: AppSpacing.s,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textD,
                      fontSize: AppTextSize.body,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                // Edit button
                InkWell(
                  onTap:
                      () => showDialog(
                        context: context,
                        builder:
                            (_) => InputCustomDialogWidget(
                              initData: item,
                              title: 'Edit',
                              isCodeEditor: isCodeEditor,
                              onTap: (input) => onEdit(item, input),
                            ),
                      ),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: Icon(
                      Icons.edit_outlined,
                      size: 14,
                      color: AppColors.textD.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                // Delete button
                InkWell(
                  onTap: () => onDelete(item),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: Icon(
                      Icons.delete_outline,
                      size: 14,
                      color: AppColors.red.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
