import 'package:flutter/material.dart';
import 'package:mockondo/core/colors.dart';

class CustomDropDown<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final bool isExpanded;

  const CustomDropDown({
    super.key,
    this.value,
    required this.items,
    this.onChanged,
    this.isExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceD.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
          child: DropdownButton<T>(
            value: value,
            isExpanded: isExpanded,
            icon: Icon(Icons.keyboard_arrow_down, color: AppColors.textD),
            dropdownColor: Theme.of(context).canvasColor,
            items: items,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}
