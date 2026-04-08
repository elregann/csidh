// lib/csidh_dart.dart
//
// Public API barrel for the csidh_dart package.
//
// Import this file to access CSIDH key exchange:
//   import 'package:csidh_dart/csidh_dart.dart';
//
// Internal implementation details (field.dart, montgomery.dart, etc.)
// are NOT re-exported and should be treated as private to the package.

export 'src/csidh.dart'       show Csidh, SecretKey, PublicKey, SharedSecret;
export 'src/params.dart'      show CsidhParams;

// Low-level exports — available for testing and TESSERA exploration,
// but not part of the stable public surface.
export 'src/field.dart'       show Fp;
export 'src/montgomery.dart'  show XPoint, Montgomery;
export 'src/isogeny.dart'     show Isogeny, IsogenyResult;
export 'src/group_action.dart' show GroupAction;
