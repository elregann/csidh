// test/field_test.dart
//
// Unit tests for F_p arithmetic (lib/src/field.dart).
//
// Test vectors are derived from:
//   - Basic arithmetic identities over the CSIDH-512 prime.
//   - Cross-checked against the Python reference in JJChiDguez/sibc
//     (csidh-20181118 / gfp.py) using p = CsidhParams.p.
//
// Run with:  dart test test/field_test.dart

import 'package:test/test.dart';
import '../csidh_dart.dart';


void main() {
  final p = CsidhParams.p;

  // Shorthand aliases matching the paper notation
  final zero = BigInt.zero;
  final one  = BigInt.one;
  final two  = BigInt.two;

  group('Fp.add', () {
    test('0 + 0 = 0', () => expect(Fp.add(zero, zero), zero));
    test('1 + 0 = 1', () => expect(Fp.add(one, zero), one));
    test('wraps around p: (p−1) + 2 = 1', () {
      expect(Fp.add(p - one, two), one);
    });
    test('commutativity: a+b = b+a', () {
      final a = p - BigInt.from(42);
      final b = BigInt.from(1337);
      expect(Fp.add(a, b), Fp.add(b, a));
    });
  });

  group('Fp.sub', () {
    test('0 − 0 = 0', () => expect(Fp.sub(zero, zero), zero));
    test('1 − 1 = 0', () => expect(Fp.sub(one, one), zero));
    test('wraps: 0 − 1 = p−1', () => expect(Fp.sub(zero, one), p - one));
    test('a − a = 0 for large a', () {
      final a = p - BigInt.from(7);
      expect(Fp.sub(a, a), zero);
    });
  });

  group('Fp.mul', () {
    test('0 × k = 0', () => expect(Fp.mul(zero, BigInt.from(999)), zero));
    test('1 × k = k', () {
      final k = BigInt.from(12345);
      expect(Fp.mul(one, k), k);
    });
    test('commutativity', () {
      final a = BigInt.from(31337);
      final b = BigInt.from(271828);
      expect(Fp.mul(a, b), Fp.mul(b, a));
    });
    test('distributivity: a(b+c) = ab+ac', () {
      final a = BigInt.from(17);
      final b = BigInt.from(13);
      final c = BigInt.from(11);
      expect(Fp.mul(a, Fp.add(b, c)), Fp.add(Fp.mul(a, b), Fp.mul(a, c)));
    });
  });

  group('Fp.inv', () {
    test('inv(1) = 1', () => expect(Fp.inv(one), one));
    test('inv(0) = 0 (convention)', () => expect(Fp.inv(zero), zero));
    test('a · inv(a) = 1 for small a', () {
      for (final v in [2, 3, 5, 7, 17, 257]) {
        final a = BigInt.from(v);
        expect(Fp.mul(a, Fp.inv(a)), one, reason: 'failed for a=$v');
      }
    });
    test('a · inv(a) = 1 for large a near p', () {
      final a = p - BigInt.from(13);
      expect(Fp.mul(a, Fp.inv(a)), one);
    });
  });

  group('Fp.sq', () {
    test('sq(0) = 0', () => expect(Fp.sq(zero), zero));
    test('sq(1) = 1', () => expect(Fp.sq(one), one));
    test('sq(a) = mul(a, a)', () {
      final a = BigInt.from(314159265);
      expect(Fp.sq(a), Fp.mul(a, a));
    });
  });

  group('Fp.sqrt', () {
    test('sqrt(1) = 1', () => expect(Fp.sqrt(one), one));
    test('sqrt(0) = 0', () => expect(Fp.sqrt(zero), zero));
    test('sqrt(sq(k))² = sq(k)', () {
      final k = BigInt.from(42);
      final k2 = Fp.sq(k);
      final root = Fp.sqrt(k2);
      expect(root, isNotNull);
      expect(Fp.sq(root!), k2);
    });
    test('returns null for non-residue', () {
      // Find a non-residue by brute force (small values)
      BigInt? nr;
      for (int v = 2; v < 1000; v++) {
        final a = BigInt.from(v);
        if (Fp.legendre(a) == -1) { nr = a; break; }
      }
      expect(nr, isNotNull, reason: 'could not find non-residue');
      expect(Fp.sqrt(nr!), isNull);
    });
  });

  group('Fp.legendre', () {
    test('legendre(0) = 0', () => expect(Fp.legendre(zero), 0));
    test('legendre(1) = 1', () => expect(Fp.legendre(one), 1));
    test('legendre(sq(k)) = 1', () {
      expect(Fp.legendre(Fp.sq(BigInt.from(7))), 1);
    });
  });

  group('Fp.neg', () {
    test('neg(0) = 0', () => expect(Fp.neg(zero), zero));
    test('a + neg(a) = 0', () {
      final a = BigInt.from(12345678);
      expect(Fp.add(a, Fp.neg(a)), zero);
    });
  });
}
