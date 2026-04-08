// example/main.dart
//
// Contoh penggunaan CSIDH-512 untuk non-interactive key exchange.
//
// Jalankan dengan:  dart run example/main.dart
//
// Catatan: group action evaluation pada layer BigInt ini lambat
// (~10–60 detik tergantung hardware).  Ini normal untuk Phase 1.

import '../csidh_dart.dart';

void main() async {
  print('=== CSIDH-512 Key Exchange (Phase 1 — BigInt, variable-time) ===\n');

  // ── Key generation ────────────────────────────────────────────────────────
  print('[1] Generating secret keys...');
  final skAlice = Csidh.generateSecretKey();
  final skBob   = Csidh.generateSecretKey();

  print('    Alice e = ${skAlice.exponents.take(10).toList()}... (first 10 of 74)');
  print('    Bob   e = ${skBob.exponents.take(10).toList()}...\n');

  // ── Public key derivation ─────────────────────────────────────────────────
  print('[2] Computing public keys (e ★ E₀)...');
  final sw = Stopwatch()..start();

  final pkAlice = Csidh.publicKey(skAlice);
  final t1 = sw.elapsedMilliseconds;
  print('    Alice pk computed in ${t1}ms');

  final pkBob = Csidh.publicKey(skBob);
  final t2 = sw.elapsedMilliseconds - t1;
  print('    Bob   pk computed in ${t2}ms');

  // Print first 16 bytes of public keys
  final pkABytes = pkAlice.toBytes();
  final pkBBytes = pkBob.toBytes();
  print('\n    Alice PK (hex, first 16 B): ${_hex(pkABytes.sublist(0, 16))}');
  print('    Bob   PK (hex, first 16 B): ${_hex(pkBBytes.sublist(0, 16))}\n');

  // ── Shared secret ─────────────────────────────────────────────────────────
  print('[3] Computing shared secrets (e_A ★ PK_B, e_B ★ PK_A)...');

  final ssAlice = Csidh.sharedSecret(skAlice, pkBob);
  final t3 = sw.elapsedMilliseconds;
  print('    Alice ss computed in ${t3 - t1 - t2}ms');

  final ssBob = Csidh.sharedSecret(skBob, pkAlice);
  final t4 = sw.elapsedMilliseconds;
  print('    Bob   ss computed in ${t4 - t3}ms\n');

  // ── Verification ──────────────────────────────────────────────────────────
  final match = ssAlice == ssBob;
  print('[4] Commutativity check: ${match ? "✓ PASS" : "✗ FAIL"}');
  if (match) {
    final ssBytes = ssAlice.toBytes();
    print('    Shared secret (hex, first 16 B): ${_hex(ssBytes.sublist(0, 16))}');
  }

  print('\nTotal wall time: ${sw.elapsedMilliseconds}ms');
}

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
