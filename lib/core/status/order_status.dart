import 'package:flutter/material.dart';

import '../theme/ps_colors.dart';

/// LOG-C01 Canonical Status: the one mapping from backend order/delivery
/// state to buyer-facing wording, badge tone and Pick Thread marker.
/// Screens must use this instead of inventing their own labels.
enum OrderStatus {
  placed('placed', 'Order Placed'),
  confirmed('confirmed', 'Order Confirmed'),
  preparing('preparing', 'Seller Preparing'),
  readyForPickup('ready_for_pickup', 'Ready for Pickup'),
  pickedUp('picked_up', 'Picked Up'),
  atSortingCenter('at_sorting_center', 'At Sorting Center'),
  sorted('sorted', 'Sorted'),
  assignedToRider('assigned_to_rider', 'Rider Assigned'),
  outForDelivery('out_for_delivery', 'Out for Delivery'),
  delivered('delivered', 'Delivered'),
  completed('completed', 'Completed'),
  deliveryFailed('delivery_failed', 'Delivery Attempt Failed'),
  returned('returned', 'Returned'),
  cancelled('cancelled', 'Cancelled');

  const OrderStatus(this.apiValue, this.buyerLabel);

  /// Value exactly as the Laravel API sends it.
  final String apiValue;
  final String buyerLabel;

  /// Unknown values fall back to [placed] rather than crashing a list.
  static OrderStatus fromApi(String? value) => OrderStatus.values.firstWhere(
        (s) => s.apiValue == value,
        orElse: () => OrderStatus.placed,
      );

  /// The happy-path sequence drawn by the order Pick Thread.
  static const List<OrderStatus> happyPath = [
    placed,
    confirmed,
    preparing,
    readyForPickup,
    pickedUp,
    atSortingCenter,
    sorted,
    assignedToRider,
    outForDelivery,
    delivered,
    completed,
  ];

  bool get isException => this == deliveryFailed || this == returned || this == cancelled;
  bool get isFinal => this == completed || this == cancelled || this == returned;

  StatusTone get tone {
    switch (this) {
      case placed:
      case confirmed:
        return StatusTone.info;
      case preparing:
      case readyForPickup:
      case pickedUp:
      case atSortingCenter:
      case sorted:
      case assignedToRider:
      case outForDelivery:
        return StatusTone.warning;
      case delivered:
      case completed:
        return StatusTone.success;
      case deliveryFailed:
        return StatusTone.error;
      case returned:
      case cancelled:
        return StatusTone.neutral;
    }
  }

  ThreadMarker get marker {
    switch (this) {
      case deliveryFailed:
        return ThreadMarker.warning;
      case returned:
        return ThreadMarker.returned;
      case cancelled:
        return ThreadMarker.cancelled;
      default:
        return ThreadMarker.step;
    }
  }
}

/// Pick Thread glyph per §11: ● step, ⚠ failed, ↩ returned, ✕ cancelled.
enum ThreadMarker { step, warning, returned, cancelled }

/// Visual tone shared by [PsStatusBadge] and other status-aware components.
enum StatusTone {
  info,
  warning,
  success,
  error,
  neutral,
  brand;

  /// Read live so badges follow the light or dark theme.
  Color get background => switch (this) {
        info => PsColors.infoSoft,
        warning => PsColors.warningSoft,
        success => PsColors.successSoft,
        error => PsColors.errorSoft,
        neutral => PsColors.neutralSoft,
        brand => PsColors.primarySoft,
      };

  Color get foreground => switch (this) {
        info => PsColors.info,
        warning => PsColors.warning,
        success => PsColors.success,
        error => PsColors.errorStrong,
        neutral => PsColors.textMuted,
        brand => PsColors.primaryStrong,
      };
}
