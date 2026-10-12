import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product.dart';
import 'auth_service.dart';

class ProductService {
  Future<List<Product>> getProducts({String? category, String? search}) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/products').replace(
        queryParameters: {
          if (category != null && category.isNotEmpty) 'category': category,
          if (search != null && search.isNotEmpty) 'search': search,
        },
      );

      final response = await http.get(uri, headers: {
        'Accept': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = data['products'] as List<dynamic>;
        return list.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
