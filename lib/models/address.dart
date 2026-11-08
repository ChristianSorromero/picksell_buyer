import 'json.dart';

/// A door pin on the map: where Pickrush riders navigate to.
class GeoPin {
  const GeoPin(this.lat, this.lng);

  final double lat;
  final double lng;

  /// The website accepts pins inside the Philippines only.
  bool get inPhilippines => lat >= 4 && lat <= 22 && lng >= 116 && lng <= 127;

  static GeoPin? fromJson(Object? v) {
    final j = mapOrNull(v);
    final lat = toDoubleOrNull(j?['lat']);
    final lng = toDoubleOrNull(j?['lng']);
    return lat == null || lng == null ? null : GeoPin(lat, lng);
  }

  Json toJson() => {'lat': lat, 'lng': lng};

  @override
  bool operator ==(Object other) => other is GeoPin && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);
}

/// COM-C18 / BUY-A03 delivery address: the buyer's profile (default) address.
/// Extra addresses live in the address book ([SavedAddress]).
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
    this.pin,
    this.municipalityCode,
    this.barangayCode,
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

  /// The door riders navigate to; null until the buyer pins it.
  final GeoPin? pin;

  /// PSGC codes Pickrush routes by (null until the server matches the names).
  final String? municipalityCode;
  final String? barangayCode;

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
        pin: GeoPin.fromJson(j['pin']),
        municipalityCode: toStr(j['municipality_code']),
        barangayCode: toStr(j['barangay_code']),
      );
}

/// An extra delivery address in the buyer's address book (website: Other Addresses).
class SavedAddress {
  const SavedAddress({
    required this.id,
    required this.recipientName,
    required this.phone,
    required this.province,
    required this.municipality,
    required this.barangay,
    this.label,
    this.street,
    this.houseNo,
    this.fullAddress = '',
    this.complete = false,
    this.pin,
  });

  final int id;
  final String? label;
  final String recipientName;
  final String phone;
  final String province;
  final String municipality;
  final String barangay;
  final String? street;
  final String? houseNo;
  final String fullAddress;
  final bool complete;
  final GeoPin? pin;

  String get displayPhone => formatPhPhone(phone);

  factory SavedAddress.fromJson(Json j) => SavedAddress(
        id: toInt(j['id']),
        label: toStr(j['label']),
        recipientName: j['recipient_name'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
        province: j['province'] as String? ?? '',
        municipality: j['municipality'] as String? ?? '',
        barangay: j['barangay'] as String? ?? '',
        street: toStr(j['street']),
        houseNo: toStr(j['house_no']),
        fullAddress: j['full_address'] as String? ?? '',
        complete: j['complete'] == true,
        pin: GeoPin.fromJson(j['pin']),
      );
}

/// GET /buyer/addresses: the default address, the saved ones, and the limit (10).
class AddressBook {
  const AddressBook({required this.defaultAddress, this.addresses = const [], this.max = 10});

  final DeliveryAddress defaultAddress;
  final List<SavedAddress> addresses;
  final int max;

  bool get isFull => addresses.length >= max;

  SavedAddress? byId(int? id) => id == null ? null : addresses.where((a) => a.id == id).firstOrNull;

  factory AddressBook.fromJson(Json j) => AddressBook(
        defaultAddress: DeliveryAddress.fromJson(mapOrNull(j['default']) ?? const {}),
        addresses: listOf(j['addresses'], SavedAddress.fromJson),
        max: toInt(j['max'], 10),
      );
}

/// Where a checkout ships (`ship_to` on the quote): the default address
/// ([addressId] null) or an address-book entry.
class CheckoutShipTo {
  const CheckoutShipTo({
    required this.recipientName,
    required this.phone,
    required this.fullAddress,
    this.addressId,
    this.label,
    this.complete = false,
    this.pin,
  });

  final int? addressId;
  final String? label;
  final String recipientName;
  final String phone;
  final String fullAddress;
  final bool complete;
  final GeoPin? pin;

  bool get isDefault => addressId == null;
  String get displayPhone => formatPhPhone(phone);

  factory CheckoutShipTo.fromJson(Json j) => CheckoutShipTo(
        addressId: j['address_id'] == null ? null : toInt(j['address_id']),
        label: toStr(j['label']),
        recipientName: j['recipient_name'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
        fullAddress: j['full_address'] as String? ?? '',
        complete: j['complete'] == true,
        pin: GeoPin.fromJson(j['pin']),
      );

  /// Older servers send only delivery_address (always the default).
  factory CheckoutShipTo.fromDefault(DeliveryAddress a) => CheckoutShipTo(
        recipientName: a.recipientName,
        phone: a.phone,
        fullAddress: a.fullAddress,
        complete: a.complete,
        pin: a.pin,
        label: 'Default',
      );
}

/// "09171234567" -> "+63 917 123 4567"
String formatPhPhone(String local) {
  final d = local.replaceAll(RegExp(r'\D'), '');
  final n = d.startsWith('0') ? d.substring(1) : (d.startsWith('63') ? d.substring(2) : d);
  if (n.length != 10) return local;
  return '+63 ${n.substring(0, 3)} ${n.substring(3, 6)} ${n.substring(6)}';
}
