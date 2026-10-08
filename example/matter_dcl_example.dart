import 'package:matter_dcl/matter_dcl.dart';

Future<void> main() async {
  final dcl = MatterDcl();
  print(await dcl.vendor(0x1423)); // LIFX
  print(await dcl.product(0x100B, 8580)); // WiZ P45.E27
  print(await dcl.deviceName(0x100B, 8580));
  dcl.close();
}
