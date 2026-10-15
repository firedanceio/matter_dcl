# matter_dcl

[![pub package](https://img.shields.io/pub/v/matter_dcl.svg)](https://pub.dev/packages/matter_dcl)

On pub.dev: [pub.dev/packages/matter_dcl](https://pub.dev/packages/matter_dcl)

Look up Matter vendors and products in the CSA **Distributed Compliance Ledger** (DCL), the public
registry behind every Matter Vendor ID and certified product. Turn `4107/8580` from a device's
discovery record into "WiZ P45.E27".

- Pure Dart: works in Flutter, on the server and on the command line
- Lookups **never throw**: unregistered IDs, timeouts and network errors all return `null`
- Results are cached, including "not registered"; failures are retried on the next call
- Concurrent lookups of the same ID share one request

## Install

```bash
dart pub add matter_dcl
```

or, in a Flutter app, `flutter pub add matter_dcl`.

## Use

```dart
import 'package:matter_dcl/matter_dcl.dart';

final dcl = MatterDcl();

final vendor = await dcl.vendor(0x100B);        // MatterVendor(0x100B, Signify)
final product = await dcl.product(0x100B, 8580); // MatterProduct(4107/8580, WiZ P45.E27)
final name = await dcl.deviceName(0x100B, 8580); // "Signify WiZ P45.E27"

dcl.close();
```

`MatterVendor` has `vendorName`, `companyPreferredName`, `companyLegalName`, `landingPageUrl` and
`displayName`. `MatterProduct` has `productName`, `productLabel`, `partNumber`, `deviceTypeId`,
`supportUrl`, `productUrl`, `userManualUrl` and `displayName`.

Options: `MatterDcl(baseUri: MatterDcl.testnet)` for the test ledger, `timeout:` (default 3 s) and
`httpClient:` to supply your own `package:http` client (handy for tests with `MockClient`).

## Things worth knowing

- **The registered vendor is often not the brand on the box.** WiZ and Philips Hue lights are
  registered under Signify; LIFX lights use Feit Electric's Vendor ID. If you can, show the
  product name.
- **IDs in the DCL API are decimal.** `0x100B` is `4107` in the URL; this package takes care of it.
- **Vendor and Product IDs come from the device**, for example its DNS-SD `VP=4107+8580` TXT record
  or its Basic Information cluster.
- The DCL REST endpoint is public and unauthenticated. Be kind to it: cache results (this client
  does) and don't look IDs up in a loop.

## Licence

Apache-2.0. Made by [Firedance](https://firedance.io).
