import 'json.dart';

/// COM-C18 / BUY-A03 delivery address: the buyer's profile address, where
/// the website books every parcel (there is no separate address book).
class DeliveryAddress {
  const DeliveryAddress({
    required this.recipientName,
    required this.phone,
    required this.province,
    required this.municipality,
    required this.barangay,
    this.street,
    this.houseNo,
    this.fullAddress = '',
    this.complete = false,
  });

  final String recipientName;

  /// Local format 09XXXXXXXXX.
  final String phone;
  final String province;
  final String municipality;
  final String barangay;
  final String? street;
  final String? houseNo;
  final String fullAddress;

  /// Province, city and barangay are all set (needed to place an order).
  final bool complete;

  /// "+63 917 123 4567"
  String get displayPhone => formatPhPhone(phone);

  factory DeliveryAddress.fromJson(Json j) => DeliveryAddress(
        recipientName: j['recipient_name'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
        province: j['province'] as String? ?? '',
        municipality: j['municipality'] as String? ?? '',
        barangay: j['barangay'] as String? ?? '',
        street: toStr(j['street']),
        houseNo: toStr(j['house_no']),
        fullAddress: j['full_address'] as String? ?? '',
        complete: j['complete'] == true,
      );
}

/// "09171234567" -> "+63 917 123 4567"
String formatPhPhone(String local) {
  final d = local.replaceAll(RegExp(r'\D'), '');
  final n = d.startsWith('0') ? d.substring(1) : (d.startsWith('63') ? d.substring(2) : d);
  if (n.length != 10) return local;
  return '+63 ${n.substring(0, 3)} ${n.substring(3, 6)} ${n.substring(6)}';
}
