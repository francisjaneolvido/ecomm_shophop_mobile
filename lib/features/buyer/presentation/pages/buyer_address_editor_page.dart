import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shophop/core/config/api_config.dart';
import 'package:shophop/shared/registration/steps/address_step.dart';

/// Edits the Buyer's single default delivery address shared with web checkout.
/// Existing orders retain their saved delivery snapshots.
class BuyerAddressEditorPage extends StatefulWidget {
  const BuyerAddressEditorPage({super.key, required this.token});

  final String token;

  @override
  State<BuyerAddressEditorPage> createState() => _BuyerAddressEditorPageState();
}

class _BuyerAddressEditorPageState extends State<BuyerAddressEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _street = TextEditingController();
  final _phone = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _regionCode;
  String _regionName = '';
  String? _provinceCode;
  String _provinceName = '';
  String? _cityCode;
  String _cityName = '';
  String? _barangayCode;
  String _barangayName = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _street.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/buyer/address'),
        headers: {'Accept': 'application/json', 'Authorization': 'Bearer ${widget.token}'},
      ).timeout(const Duration(seconds: 25));
      final payload = jsonDecode(response.body);
      if (response.statusCode != 200 || payload is! Map || payload['data'] is! Map) {
        throw Exception(payload is Map ? payload['message'] ?? 'Cannot load address.' : 'Cannot load address.');
      }
      final data = Map<String, dynamic>.from(payload['data'] as Map);
      if (!mounted) return;
      setState(() {
        _regionCode = data['region_code']?.toString();
        _regionName = data['region_name']?.toString() ?? '';
        _provinceCode = data['province_code']?.toString();
        _provinceName = data['province_name']?.toString() ?? '';
        _cityCode = data['municipality_code']?.toString();
        _cityName = data['municipality_name']?.toString() ?? '';
        _barangayCode = data['barangay_code']?.toString();
        _barangayName = data['barangay_name']?.toString() ?? '';
        _street.text = data['street_address']?.toString() ?? '';
        _phone.text = data['contact_no']?.toString() ?? '';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'Could not load your address. Check your internet or sign in again. ($e)'; });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_regionCode == null || _provinceCode == null || _cityCode == null || _barangayCode == null ||
        _regionName.isEmpty || _provinceName.isEmpty || _cityName.isEmpty || _barangayName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose a region, city/municipality and barangay.')));
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/buyer/address'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode({
          'region_code': _regionCode,
          'region_name': _regionName,
          'province_code': _provinceCode,
          'province_name': _provinceName,
          'municipality_code': _cityCode,
          'municipality_name': _cityName,
          'barangay_code': _barangayCode,
          'barangay_name': _barangayName,
          'street_address': _street.text.trim(),
          'contact_no': _phone.text.trim(),
        }),
      ).timeout(const Duration(seconds: 25));
      final payload = jsonDecode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        String message = payload is Map ? (payload['message']?.toString() ?? 'Unable to save address.') : 'Unable to save address.';
        if (payload is Map && payload['errors'] is Map) {
          final errors = payload['errors'] as Map;
          final first = errors.values.isNotEmpty ? errors.values.first : null;
          if (first is List && first.isNotEmpty) message = first.first.toString();
        }
        throw Exception(message);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Default delivery address saved.')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); });
    } finally {
      if (mounted) setState(() { _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Default delivery address')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _regionCode == null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _load, child: const Text('Try again')),
                  ]),
                ))
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(18),
                    children: [
                      const Text('Update your default delivery address. Previous orders will not change.'),
                      const SizedBox(height: 18),
                      AddressStep(
                        streetAddressController: _street,
                        provinceCode: _provinceCode,
                        municipalityCode: _cityCode,
                        barangayCode: _barangayCode,
                        onRegionChanged: (code, name) { _regionCode = code; _regionName = name; },
                        onProvinceChanged: (code, name) { _provinceCode = code; _provinceName = name; },
                        onMunicipalityChanged: (code, name) { _cityCode = code; _cityName = name; },
                        onBarangayChanged: (code, name) { _barangayCode = code; _barangayName = name; },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Contact number (09XXXXXXXXX)', border: OutlineInputBorder()),
                        validator: (value) => RegExp(r'^09\d{9}$').hasMatch((value ?? '').trim())
                            ? null : 'Enter a valid 11-digit Philippine mobile number.',
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Save delivery address'),
                      ),
                    ],
                  ),
                ),
    );
  }
}
