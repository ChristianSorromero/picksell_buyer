import '../core/network/api_client.dart';
import '../models/address.dart';
import '../models/json.dart';

/// The buyer's address book and door pin, as on the website's account page
/// (BuyerAddressBook, DeliveryPin on the server). Every address-book call
/// answers with the whole book.
class AddressBookService {
  AddressBookService({ApiClient? client}) : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  Future<AddressBook> load() async => AddressBook.fromJson(await _api.getJson('/buyer/addresses'));

  /// Throws [ApiException]: 422 with field errors, or `address` when 10 are saved.
  Future<AddressBook> add(AddressInput input) async =>
      AddressBook.fromJson(await _api.postJson('/buyer/addresses', input.toJson()));

  /// Send the pin back to keep it: an edit without one removes it (as on the website).
  Future<AddressBook> update(int id, AddressInput input) async =>
      AddressBook.fromJson(await _api.patchJson('/buyer/addresses/$id', input.toJson()));

  Future<AddressBook> remove(int id) async => AddressBook.fromJson(await _api.deleteJson('/buyer/addresses/$id'));

  /// The entry becomes the profile address; the old default is kept as "Previous default".
  Future<AddressBook> makeDefault(int id) async => AddressBook.fromJson(await _api.postJson('/buyer/addresses/$id/default'));

  /// The default address's door pin. Parcels still on their way there follow it.
  Future<PinResult> pinDefault(GeoPin pin) async {
    final j = await _api.patchJson('/buyer/delivery-location', pin.toJson());
    return PinResult(
      parcelsUpdated: toInt(j['parcels_updated']),
      address: DeliveryAddress.fromJson(mapOrNull(j['delivery_address']) ?? const {}),
    );
  }
}

class PinResult {
  const PinResult({required this.parcelsUpdated, required this.address});

  final int parcelsUpdated;
  final DeliveryAddress address;
}

/// The address form's body (website: BuyerAddressController fields).
class AddressInput {
  const AddressInput({
    required this.recipientName,
    required this.contactNo,
    required this.province,
    required this.municipality,
    required this.barangay,
    this.label,
    this.street,
    this.houseNo,
    this.pin,
  });

  final String? label;
  final String recipientName;
  final String contactNo;
  final String province;
  final String municipality;
  final String barangay;
  final String? street;
  final String? houseNo;
  final GeoPin? pin;

  Json toJson() => {
        'label': label,
        'recipient_name': recipientName,
        'contact_no': contactNo,
        'province': province,
        'municipality': municipality,
        'barangay': barangay,
        'street': street,
        'house_no': houseNo,
        'lat': pin?.lat,
        'lng': pin?.lng,
      };
}
