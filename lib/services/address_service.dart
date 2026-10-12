import 'dart:convert';

import 'package:http/http.dart' as http;

/// -----------------------------------------------------------------------
/// MODELS
/// -----------------------------------------------------------------------
/// Each one carries the PSGC `code` (needed to fetch the next level down)
/// and `name` (what's shown in the dropdown). toString() returns the
/// name so these can be dropped straight into a DropdownButtonFormField
/// without any extra mapping.
class Province {
  final String code;
  final String name;
  const Province({required this.code, required this.name});

  factory Province.fromJson(Map<String, dynamic> json) => Province(
        code: json['code'] as String,
        name: json['name'] as String,
      );

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) => other is Province && other.code == code;
  @override
  int get hashCode => code.hashCode;
}

class Municipality {
  final String code;
  final String name;
  const Municipality({required this.code, required this.name});

  factory Municipality.fromJson(Map<String, dynamic> json) => Municipality(
        code: json['code'] as String,
        name: json['name'] as String,
      );

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) =>
      other is Municipality && other.code == code;
  @override
  int get hashCode => code.hashCode;
}

class Barangay {
  final String code;
  final String name;
  const Barangay({required this.code, required this.name});

  factory Barangay.fromJson(Map<String, dynamic> json) => Barangay(
        code: json['code'] as String,
        name: json['name'] as String,
      );

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) => other is Barangay && other.code == code;
  @override
  int get hashCode => code.hashCode;
}

/// -----------------------------------------------------------------------
/// SERVICE
/// -----------------------------------------------------------------------
/// Wraps https://psgc.gitlab.io/api — a free public API for the
/// Philippine Standard Geographic Code (provinces, cities/municipalities,
/// barangays). No API key required.
///
/// Example raw responses:
///   GET /provinces/
///     [{ "code": "0128", "name": "Batangas", "regionCode": "04", ... }, ...]
///   GET /provinces/0128/cities-municipalities/
///     [{ "code": "012801", "name": "Agoncillo", "provinceCode": "0128", ... }, ...]
///   GET /cities-municipalities/012801/barangays/
///     [{ "code": "012801001", "name": "Adia", "cityCode": "012801", ... }, ...]
class AddressService {
  static const String _baseUrl = 'https://psgc.gitlab.io/api';

  Future<List<Province>> getProvinces() async {
    final response = await http.get(Uri.parse('$_baseUrl/provinces/'));
    if (response.statusCode != 200) {
      throw Exception('Failed to load provinces (${response.statusCode}).');
    }
    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    final provinces =
        data.map((e) => Province.fromJson(e as Map<String, dynamic>)).toList();
    provinces.sort((a, b) => a.name.compareTo(b.name));
    return provinces;
  }

  Future<List<Municipality>> getMunicipalities(String provinceCode) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/provinces/$provinceCode/cities-municipalities/'),
    );
    if (response.statusCode != 200) {
      throw Exception(
          'Failed to load municipalities (${response.statusCode}).');
    }
    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    final list = data
        .map((e) => Municipality.fromJson(e as Map<String, dynamic>))
        .toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  Future<List<Barangay>> getBarangays(String municipalityCode) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/cities-municipalities/$municipalityCode/barangays/'),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load barangays (${response.statusCode}).');
    }
    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    final list =
        data.map((e) => Barangay.fromJson(e as Map<String, dynamic>)).toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }
}
