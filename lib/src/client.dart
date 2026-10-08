// Copyright 2026 Firedance Multimedia LLC
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

/// Reads vendor and product records from the CSA Distributed Compliance Ledger (DCL), the public
/// registry of Matter Vendor IDs and certified products.
///
/// Lookups never throw: an unregistered ID, a timeout, a network error or an unexpected response
/// all return `null`, so a lookup can't become a new way for your app to fail. Results, including
/// "not registered", are cached for the life of the client; failures are not, so a later call
/// retries.
///
/// ```dart
/// final dcl = MatterDcl();
/// final vendor = await dcl.vendor(0x1423);              // LIFX
/// final product = await dcl.product(0x100B, 8580);      // WiZ P45.E27
/// dcl.close();
/// ```
class MatterDcl {
  /// The public, unauthenticated DCL REST endpoint for the production ledger.
  static final Uri mainnet = Uri.parse('https://on.dcl.csa-iot.org');

  /// The test ledger, which also holds test-net vendors and products.
  static final Uri testnet = Uri.parse('https://on.test-net.dcl.csa-iot.org');

  final Uri baseUri;
  final Duration timeout;
  final http.Client _http;
  final bool _ownsClient;

  final Map<int, MatterVendor?> _vendors = {};
  final Map<(int, int), MatterProduct?> _products = {};
  final Map<Object, Future<Object?>> _inFlight = {};

  MatterDcl({Uri? baseUri, this.timeout = const Duration(seconds: 3), http.Client? httpClient})
      : baseUri = baseUri ?? mainnet,
        _http = httpClient ?? http.Client(),
        _ownsClient = httpClient == null;

  /// The vendor registered under [vendorId], or `null` if it isn't registered or the lookup failed.
  Future<MatterVendor?> vendor(int vendorId) {
    _checkId(vendorId, 'vendorId');
    if (_vendors.containsKey(vendorId)) return Future.value(_vendors[vendorId]);
    return _once(('v', vendorId), () async {
      final result = await _get('/dcl/vendorinfo/vendors/$vendorId', MatterVendor.fromJson);
      if (result.cacheable) _vendors[vendorId] = result.value;
      return result.value;
    });
  }

  /// The product registered as [vendorId]/[productId], or `null` if it isn't registered or the
  /// lookup failed.
  Future<MatterProduct?> product(int vendorId, int productId) {
    _checkId(vendorId, 'vendorId');
    _checkId(productId, 'productId');
    final key = (vendorId, productId);
    if (_products.containsKey(key)) return Future.value(_products[key]);
    return _once(('p', vendorId, productId), () async {
      final result = await _get('/dcl/model/models/$vendorId/$productId', MatterProduct.fromJson);
      if (result.cacheable) _products[key] = result.value;
      return result.value;
    });
  }

  /// A short name for a device, e.g. "LIFX A19", from whatever the DCL knows:
  /// vendor and product, just one of them, or `null` if neither is registered.
  Future<String?> deviceName(int vendorId, int productId) async {
    final (vendor, product) = await (this.vendor(vendorId), this.product(vendorId, productId)).wait;
    final v = vendor?.displayName;
    final p = product?.displayName;
    if (v == null || v.isEmpty) return (p == null || p.isEmpty) ? null : p;
    if (p == null || p.isEmpty) return v;
    // Products often repeat the brand ("WiZ P45.E27"); don't say it twice.
    return p.toLowerCase().startsWith(v.toLowerCase()) ? p : '$v $p';
  }

  /// Forgets cached results.
  void clearCache() {
    _vendors.clear();
    _products.clear();
  }

  /// Closes the HTTP client if this instance created it.
  void close() {
    if (_ownsClient) _http.close();
  }

  // Concurrent lookups of the same ID share one request.
  Future<T> _once<T>(Object key, Future<T> Function() run) {
    final pending = _inFlight[key];
    if (pending != null) return pending.then((v) => v as T);
    // Block body on purpose: `remove` returns this future, and whenComplete would wait on it.
    final future = run().whenComplete(() {
      _inFlight.remove(key);
    });
    _inFlight[key] = future;
    return future;
  }

  Future<({T? value, bool cacheable})> _get<T>(String path, T? Function(Object?) parse) async {
    try {
      final res = await _http.get(baseUri.resolve(path)).timeout(timeout);
      // 404 means "not registered": a real answer, so cache it.
      if (res.statusCode == 404) return (value: null, cacheable: true);
      if (res.statusCode < 200 || res.statusCode >= 300) return (value: null, cacheable: false);
      final parsed = parse(jsonDecode(res.body));
      return (value: parsed, cacheable: parsed != null);
    } catch (_) {
      return (value: null, cacheable: false);
    }
  }

  static void _checkId(int id, String name) {
    if (id < 0 || id > 0xFFFF) throw RangeError.range(id, 0, 0xFFFF, name);
  }
}
