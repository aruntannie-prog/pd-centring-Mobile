import 'package:flutter/material.dart';

import '../../core/quantity.dart';
import '../theme.dart';

/// Compact "− 24 +" quantity control: one tap per piece, or type a number.
/// Empty means zero.
class QtyStepper extends StatelessWidget {
  const QtyStepper({
    super.key,
    required this.controller,
    this.onChanged,
    this.max,
    this.fieldKey,
    this.focusNode,
    this.hasError = false,
  });

  final TextEditingController controller;
  final VoidCallback? onChanged;

  /// Upper limit for the + button (typing more is still caught on save).
  final double? max;
  final Key? fieldKey;
  final FocusNode? focusNode;
  final bool hasError;

  double get _value => double.tryParse(controller.text.trim()) ?? 0;

  void _set(double v) {
    final next = v <= 0 ? '' : formatQty(v);
    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final sd = context.sd;
    final theme = Theme.of(context);
    final atMax = max != null && _value >= max! - qtyEpsilon;

    Widget button(IconData icon, String tip, VoidCallback? onTap) => SizedBox(
      width: 36,
      height: 40,
      child: IconButton(
        tooltip: tip,
        padding: EdgeInsets.zero,
        iconSize: 18,
        onPressed: onTap,
        icon: Icon(icon),
      ),
    );

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: sd.field,
        borderRadius: BorderRadius.circular(12),
        border: hasError
            ? Border.all(color: SdColors.expired, width: 1.4)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(
            Icons.remove_rounded,
            'Less',
            _value <= 0 ? null : () => _set((_value - 1).floorToDouble()),
          ),
          SizedBox(
            width: 52,
            child: TextField(
              key: fieldKey,
              controller: controller,
              focusNode: focusNode,
              onChanged: (_) => onChanged?.call(),
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: theme.textTheme.titleSmall?.copyWith(fontSize: 15),
              decoration: const InputDecoration(
                hintText: '0',
                filled: false,
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          button(
            Icons.add_rounded,
            'More',
            atMax ? null : () => _set(_value.floorToDouble() + 1),
          ),
        ],
      ),
    );
  }
}
