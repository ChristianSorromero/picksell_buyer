import 'package:flutter/material.dart';

import '../../core/theme/ps_colors.dart';
import '../../core/theme/ps_tokens.dart';
import '../../core/theme/ps_typography.dart';
import '../shared/ps_card.dart';

/// COM-C18 Address Card — structured PH address with landmark.
class PsAddressCard extends StatelessWidget {
  const PsAddressCard({
    super.key,
    required this.name,
    required this.phone,
    required this.address,
    this.label,
    this.landmark,
    this.isDefault = false,
    this.title,
    this.onEdit,
    this.onTap,
    this.trailing,
    this.selected = false,
  });

  final String name;
  final String phone;
  final String address;
  final String? label;
  final String? landmark;
  final bool isDefault;
  final String? title;
  final VoidCallback? onEdit;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return PsCard(
      title: title,
      onTap: onTap,
      borderColor: selected ? PsColors.primary : PsColors.border,
      trailing: onEdit == null ? null : InkWell(onTap: onEdit, child: Text('Edit', style: PsText.link)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.location_on_rounded, color: PsColors.primary, size: 20),
          ),
          const SizedBox(width: PsSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(name, style: PsText.bodyStrong),
                    Text(phone, style: PsText.caption),
                    if (label != null) PsTag.muted(label!.toUpperCase()),
                    if (isDefault) const PsTag('DEFAULT'),
                  ],
                ),
                const SizedBox(height: 4),
                Text(address, style: PsText.bodyMuted),
                if (landmark != null && landmark!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.near_me_outlined, size: 14, color: PsColors.textMuted),
                      const SizedBox(width: 4),
                      Flexible(child: Text(landmark!, style: PsText.caption)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
