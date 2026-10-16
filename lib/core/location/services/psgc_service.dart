import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shophop/core/location/models/psgc_location.dart';

/// Shared Philippines location service.  Retains existing 9-digit PSGC codes
/// so Buyer/Seller/Rider APIs and legacy saved addresses stay compatible.
class PsgcService {
  static const baseUrl = 'https://psgc.gitlab.io/api';
  static const ncrCode = '130000000';
  static const nirCode = '180000000';
  static const nirName = 'Negros Island Region (NIR)';
  static const ncrName = 'National Capital Region (NCR)';
  static const nirProvinces = {'Negros Occidental', 'Negros Oriental', 'Siquijor'};

  static final Map<String, Future<List<PsgcLocation>>> _cache = {};

  Future<List<PsgcLocation>> getRegions() async {
    final remote = await _getLocations('/regions/');
    return [...remote.where((item) => item.code != nirCode).map((item) {
        if (item.code == ncrCode) return const PsgcLocation(code: ncrCode, name: ncrName);
        final prefix = item.regionLabel;
        return PsgcLocation(code: item.code,
            name: prefix != null && prefix.isNotEmpty &&
                    prefix != item.name && !item.name.contains(prefix)
                ? '$prefix (${item.name})' : item.name);
      }), const PsgcLocation(code: nirCode, name: nirName)]
      ..sort((a,b) => a.name.compareTo(b.name));
  }

  Future<List<PsgcLocation>> getProvinces() => _getLocations('/provinces/');

  Future<List<PsgcLocation>> getProvincesByRegion(String regionCode) async {
    if (regionCode == ncrCode) return [];
    final all = await getProvinces();
    if (regionCode == nirCode) {
      return all.where((p) => nirProvinces.contains(p.name)).toList();
    }
    return all.where((p) => p.regionCode == regionCode).toList();
  }

  Future<String?> getRegionForProvince(String provinceCode) async {
    if (provinceCode == ncrCode) return ncrCode;
    if (provinceCode == nirCode) return nirCode;
    final all = await getProvinces();
    for (final province in all) {
      if (province.code == provinceCode) {
        return nirProvinces.contains(province.name) ? nirCode : province.regionCode;
      }
    }
    return null;
  }

  Future<List<PsgcLocation>> getMunicipalities(String provinceCode) =>
      _getLocations('/provinces/$provinceCode/cities-municipalities/');

  Future<List<PsgcLocation>> getCitiesByRegion(String regionCode) =>
      _getLocations('/regions/$regionCode/cities-municipalities/');

  Future<List<PsgcLocation>> getBarangays(String cityCode) =>
      _getLocations('/cities-municipalities/$cityCode/barangays/');

  Future<List<PsgcLocation>> _getLocations(String path) =>
      _cache.putIfAbsent(path, () async {
        try {
          final response = await http.get(Uri.parse('$baseUrl$path'))
              .timeout(const Duration(seconds: 20));
          if (response.statusCode < 200 || response.statusCode >= 300) {
            throw Exception('Location service unavailable.');
          }
          final decoded = jsonDecode(response.body);
          final values = decoded is List ? decoded
              : decoded is Map ? decoded['data'] : null;
          if (values is! List) throw Exception('Unexpected location data.');
          final result = values.map((item) =>
              PsgcLocation.fromJson(Map<String, dynamic>.from(item as Map)))
              .where((loc) => loc.code.isNotEmpty && loc.name.isNotEmpty)
              .toList()..sort((a,b) => a.name.compareTo(b.name));
          return result;
        } catch (_) {
          _cache.remove(path); // allow retry when phone gets connectivity
          rethrow;
        }
      });
}
