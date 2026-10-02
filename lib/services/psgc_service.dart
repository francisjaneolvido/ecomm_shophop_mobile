import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/psgc_location.dart';

class PsgcService {
  static const String _baseUrl =
      'https://psgc.gitlab.io/api';

  Future<List<PsgcLocation>>
      getProvinces() {
    return _getLocations(
      '/provinces/',
    );
  }

  Future<List<PsgcLocation>>
      getMunicipalities(
    String provinceCode,
  ) {
    return _getLocations(
      '/provinces/$provinceCode/'
      'cities-municipalities/',
    );
  }

  Future<List<PsgcLocation>>
      getBarangays(
    String municipalityCode,
  ) {
    return _getLocations(
      '/cities-municipalities/'
      '$municipalityCode/barangays/',
    );
  }

  Future<List<PsgcLocation>>
      _getLocations(
    String path,
  ) async {
    final uri = Uri.parse(
      '$_baseUrl$path',
    );

    final response = await http
        .get(uri)
        .timeout(
          const Duration(
            seconds: 15,
          ),
        );

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw Exception(
        'Unable to load address data.',
      );
    }

    final decoded =
        jsonDecode(response.body);

    if (decoded is! List) {
      throw Exception(
        'Invalid address data.',
      );
    }

    final locations = decoded
        .map(
          (item) =>
              PsgcLocation.fromJson(
            Map<String, dynamic>.from(
              item as Map,
            ),
          ),
        )
        .where(
          (location) =>
              location.code.isNotEmpty &&
              location.name.isNotEmpty,
        )
        .toList();

    locations.sort(
      (a, b) => a.name.compareTo(
        b.name,
      ),
    );

    return locations;
  }
}