// test/csidh_test.dart
//
// Integration tests for the CSIDH public API (lib/src/csidh.dart).
//
// The critical invariant being tested is commutativity:
//
//   e_A ★ (e_B ★ E₀)  =  e_B ★ (e_A ★ E₀)
//
// i.e. Alice and Bob arrive at the same shared curve independently.
//
// These tests run the full group action twice per test case.  On the
// BigInt variable-time layer this is slow (~5–30 s per action depending
// on hardware); hence the extended timeout annotations.
//
// Run with:  dart test test/csidh_test.dart
// To run only fast tests:  dart test test/csidh_test.dart --tags fast

import 'dart:typed_data' show Uint8List;
import 'package:test/test.dart';
import '../csidh_dart.dart';

void main() {
  group('SecretKey encoding', () {
    test('roundtrip: toBytes → fromBytes gives same exponents', () {
      final sk = Csidh.generateSecretKey();
      final sk2 = SecretKey.fromBytes(sk.toBytes());
      expect(sk2.exponents, sk.exponents);
    });

    test('all-zero key encodes and decodes correctly', () {
      final zeros = Uint8List(CsidhParams.n); // all 0x00
      final sk = SecretKey.fromBytes(zeros);
      expect(sk.exponents, List.filled(CsidhParams.n, 0));
    });

    test('out-of-range exponent throws', () {
      final bad = Uint8List(CsidhParams.n);
      bad[0] = 10; // > m = 5
      expect(() => SecretKey.fromBytes(bad), throwsArgumentError);
    });
  });

  group('PublicKey encoding', () {
    test('A₀ = 0 encodes as 64 zero bytes', () {
      final pk = PublicKey(BigInt.zero);
      expect(pk.toBytes(), Uint8List(64));
    });

    test('roundtrip: toBytes → fromBytes gives same A', () {
      final a = CsidhParams.p - BigInt.from(42);
      final pk = PublicKey(a);
      final pk2 = PublicKey.fromBytes(pk.toBytes());
      expect(pk2.a, a);
    });

    test('out-of-range A throws', () {
      // Encode p itself (= 0 mod p, but as a raw value it is out of range)
      final bytes = Uint8List(64);
      var v = CsidhParams.p;
      for (int i = 0; i < 64; i++) {
        bytes[i] = (v & BigInt.from(0xff)).toInt();
        v >>= 8;
      }
      expect(() => PublicKey.fromBytes(bytes), throwsArgumentError);
    });
  });

  group('publicKey', () {
    test('identity key (all zeros) maps E₀ to itself', () {
      // e = (0,…,0) → group action is identity → A′ = A₀ = 0
      final zeros = Uint8List(CsidhParams.n);
      final sk = SecretKey.fromBytes(zeros);
      final pk = Csidh.publicKey(sk);
      expect(pk.a, CsidhParams.A0);
    }, tags: 'fast');
  });

  group('commutativity (slow — full group action)', () {
    test('e_A ★ (e_B ★ E₀) = e_B ★ (e_A ★ E₀)', () {
      final skA = Csidh.generateSecretKey();
      final skB = Csidh.generateSecretKey();

      final pkA = Csidh.publicKey(skA);
      final pkB = Csidh.publicKey(skB);

      final ssAlice = Csidh.sharedSecret(skA, pkB);
      final ssBob   = Csidh.sharedSecret(skB, pkA);

      expect(ssAlice, ssBob,
          reason: 'commutativity violated: shared secrets differ');
    }, timeout: Timeout(Duration(minutes: 5)));
  });
}

// Re-export for tests that need Uint8List without a separate import
// ignore: unused_import
// import 'dart:typed_data' show Uint8List;
