// Copyright 2026 Firedance Multimedia LLC
// SPDX-License-Identifier: Apache-2.0

/// A Matter vendor as registered in the DCL.
class MatterVendor {
  /// The 16-bit Vendor ID (VID).
  final int vendorId;

  /// The registered vendor name, e.g. "Feit Electric".
  final String vendorName;

  /// The name the company prefers to be shown as, e.g. "Feit". May be empty.
  final String companyPreferredName;

  /// The company's legal name. May be empty.
  final String companyLegalName;

  /// The vendor's website. May be empty.
  final String landingPageUrl;

  const MatterVendor({
    required this.vendorId,
    required this.vendorName,
    this.companyPreferredName = '',
    this.companyLegalName = '',
    this.landingPageUrl = '',
  });

  /// The best name to show people: the preferred name when set, otherwise the vendor name.
  String get displayName => companyPreferredName.trim().isNotEmpty ? companyPreferredName.trim() : vendorName.trim();

  static MatterVendor? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final info = json['vendorInfo'];
    if (info is! Map<String, dynamic>) return null;
    final id = info['vendorID'];
    final name = info['vendorName'];
    if (id is! int || name is! String) return null;
    return MatterVendor(
      vendorId: id,
      vendorName: name,
      companyPreferredName: _str(info['companyPreferredName']),
      companyLegalName: _str(info['companyLegalName']),
      landingPageUrl: _str(info['vendorLandingPageURL']),
    );
  }

  @override
  String toString() => 'MatterVendor(0x${vendorId.toRadixString(16).toUpperCase().padLeft(4, '0')}, $displayName)';
}

/// A Matter product model as registered in the DCL.
class MatterProduct {
  final int vendorId;

  /// The 16-bit Product ID (PID).
  final int productId;

  /// The registered product name, e.g. "WiZ P45.E27".
  final String productName;

  /// A shorter label for the product. May be empty or the same as [productName].
  final String productLabel;

  /// The manufacturer part number. Often "-" or empty.
  final String partNumber;

  /// The Matter device type, e.g. 0x010D (269) for an extended color light.
  final int? deviceTypeId;

  /// Support page for the product. May be empty.
  final String supportUrl;

  /// Product page. May be empty.
  final String productUrl;

  /// User manual. May be empty.
  final String userManualUrl;

  const MatterProduct({
    required this.vendorId,
    required this.productId,
    required this.productName,
    this.productLabel = '',
    this.partNumber = '',
    this.deviceTypeId,
    this.supportUrl = '',
    this.productUrl = '',
    this.userManualUrl = '',
  });

  /// The best name to show people: the label when set, otherwise the product name.
  String get displayName => productLabel.trim().isNotEmpty ? productLabel.trim() : productName.trim();

  static MatterProduct? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final m = json['model'];
    if (m is! Map<String, dynamic>) return null;
    final vid = m['vid'];
    final pid = m['pid'];
    final name = m['productName'];
    if (vid is! int || pid is! int || name is! String) return null;
    final type = m['deviceTypeId'];
    return MatterProduct(
      vendorId: vid,
      productId: pid,
      productName: name,
      productLabel: _str(m['productLabel']),
      partNumber: _str(m['partNumber']),
      deviceTypeId: type is int ? type : null,
      supportUrl: _str(m['supportUrl']),
      productUrl: _str(m['productUrl']),
      userManualUrl: _str(m['userManualUrl']),
    );
  }

  @override
  String toString() => 'MatterProduct($vendorId/$productId, $displayName)';
}

String _str(Object? v) => v is String ? v : '';
