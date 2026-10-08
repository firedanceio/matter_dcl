import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:matter_dcl/matter_dcl.dart';
import 'package:test/test.dart';

const _feit = {
  'vendorInfo': {
    'vendorID': 5155,
    'vendorName': 'Feit Electric',
    'companyLegalName': 'Feit Electric Company Inc.',
    'companyPreferredName': 'Feit',
    'vendorLandingPageURL': 'https://www.feit.com',
  },
};
const _wiz = {
  'model': {
    'vid': 4107,
    'pid': 8580,
    'deviceTypeId': 269,
    'productName': 'WiZ P45.E27',
    'productLabel': 'WiZ P45.E27',
    'partNumber': '-',
    'supportUrl': 'https://wiz.guide/matter'
  },
};
const _signify = {
  'vendorInfo': {'vendorID': 4107, 'vendorName': 'Signify', 'companyPreferredName': 'Philips Hue'},
};

void main() {
  late int calls;
  MatterDcl client(Future<http.Response> Function(http.Request) handler) {
    calls = 0;
    return MatterDcl(
        httpClient: MockClient((r) {
          calls++;
          return handler(r);
        }),
        timeout: const Duration(milliseconds: 200));
  }

  test('parses a vendor and prefers the company preferred name', () async {
    final dcl = client((r) async {
      expect(r.url.toString(), 'https://on.dcl.csa-iot.org/dcl/vendorinfo/vendors/5155');
      return http.Response(jsonEncode(_feit), 200);
    });
    final v = await dcl.vendor(5155);
    expect(v!.vendorName, 'Feit Electric');
    expect(v.displayName, 'Feit');
    expect(v.landingPageUrl, 'https://www.feit.com');
  });

  test('parses a product', () async {
    final dcl = client((r) async => http.Response(jsonEncode(_wiz), 200));
    final p = await dcl.product(4107, 8580);
    expect(p!.displayName, 'WiZ P45.E27');
    expect(p.deviceTypeId, 269);
    expect(p.supportUrl, 'https://wiz.guide/matter');
  });

  test('404 is "not registered" and is cached', () async {
    final dcl = client((r) async => http.Response('{"code":5,"message":"not found"}', 404));
    expect(await dcl.vendor(1), isNull);
    expect(await dcl.vendor(1), isNull);
    expect(calls, 1);
  });

  test('server errors, bad JSON and timeouts return null and are retried later', () async {
    final responses = <FutureOr<http.Response> Function()>[
      () => http.Response('oops', 500),
      () => http.Response('not json', 200),
      () => Future.delayed(const Duration(seconds: 1), () => http.Response(jsonEncode(_feit), 200)),
      () => throw http.ClientException('offline'),
      () => http.Response(jsonEncode(_feit), 200),
    ];
    final dcl = client((r) async => responses[calls - 1]());
    for (var i = 0; i < 4; i++) {
      expect(await dcl.vendor(5155), isNull);
    }
    expect((await dcl.vendor(5155))!.displayName, 'Feit');
    expect(calls, 5);
  });

  test('concurrent lookups share one request', () async {
    final dcl = client((r) async => http.Response(jsonEncode(_feit), 200));
    final results = await Future.wait([dcl.vendor(5155), dcl.vendor(5155), dcl.vendor(5155)]);
    expect(results.map((v) => v!.vendorId), [5155, 5155, 5155]);
    expect(calls, 1);
  });

  test('deviceName avoids repeating the brand', () async {
    final dcl = client((r) async => r.url.path.contains('vendorinfo')
        ? http.Response(jsonEncode(_signify), 200)
        : http.Response(jsonEncode(_wiz), 200));
    expect(await dcl.deviceName(4107, 8580), 'Philips Hue WiZ P45.E27');

    final lifx = client((r) async => r.url.path.contains('vendorinfo')
        ? http.Response(
            jsonEncode({
              'vendorInfo': {'vendorID': 5155, 'vendorName': 'LIFX'}
            }),
            200)
        : http.Response(
            jsonEncode({
              'model': {'vid': 5155, 'pid': 1, 'productName': 'LIFX A19'}
            }),
            200));
    expect(await lifx.deviceName(5155, 1), 'LIFX A19');

    final none = client((r) async => http.Response('', 404));
    expect(await none.deviceName(1, 1), isNull);
  });

  test('rejects IDs outside 16 bits', () {
    final dcl = client((r) async => http.Response('', 404));
    expect(() => dcl.vendor(0x10000), throwsRangeError);
    expect(() => dcl.product(1, -1), throwsRangeError);
  });

  test('live: the real DCL knows Signify (skipped offline)', () async {
    final dcl = MatterDcl();
    final v = await dcl.vendor(0x100B);
    dcl.close();
    if (v == null) {
      markTestSkipped('DCL not reachable');
      return;
    }
    expect(v.vendorId, 0x100B);
  }, tags: 'live');
}
