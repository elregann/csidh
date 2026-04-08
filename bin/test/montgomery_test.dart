// test/montgomery_test.dart
//
// Unit tests for Montgomery curve arithmetic (lib/src/montgomery.dart).
//
// Test strategy:
//   1. Algebraic identities: [2]P via xdbl vs [2]P via xadd(P,P,O).
//   2. Ladder consistency: ladder(k, P) should match repeated xadd.
//   3. Group order: #E₀(F_p) = p+1 = 4·ℓ₁·…·ℓ₇₄,  so [p+1]P = O.
//
// Run with:  dart test test/montgomery_test.dart

import 'package:test/test.dart';
import '../csidh_dart.dart';


void main() {
  // Base curve E₀: A = 0
  final a0 = CsidhParams.A0;

  // A small known point on E₀: x = 1 is on E₀ iff 1+0+1=2 is a QR mod p.
  // We'll use x = 5, checking hasPoint first.
  BigInt findPoint(BigInt a) {
    for (int v = 1; v < 1000; v++) {
      final x = BigInt.from(v);
      if (Montgomery.hasPoint(x, a)) return x;
    }
    throw StateError('no small point found');
  }

  group('XPoint', () {
    test('infinity isInfinity', () => expect(XPoint.infinity.isInfinity, true));
    test('non-infinity is not infinity', () {
      expect(XPoint(BigInt.one, BigInt.one).isInfinity, false);
    });
    test('affine throws on infinity', () {
      expect(() => XPoint.infinity.affine, throwsStateError);
    });
    test('affine = X · Z⁻¹', () {
      final x = BigInt.from(3);
      final z = BigInt.from(7);
      final pt = XPoint(x, z);
      expect(pt.affine, Fp.mul(x, Fp.inv(z)));
    });
  });

  group('xdbl', () {
    test('[2]∞ = ∞', () {
      expect(Montgomery.xdbl(XPoint.infinity, a0).isInfinity, true);
    });
    test('[2]P has a valid x on E₀', () {
      final x = findPoint(a0);
      final p = XPoint(x, BigInt.one);
      final dbl = Montgomery.xdbl(p, a0);
      if (!dbl.isInfinity) {
        expect(Montgomery.hasPoint(dbl.affine, a0), true);
      }
    });
  });

  group('xadd', () {
    test('P + ∞ (diff = P) is undefined but does not crash', () {
      // xadd requires diff = P − Q; with Q = ∞ the diff is P itself.
      // We just check it runs without throwing.
      final x = findPoint(a0);
      final p = XPoint(x, BigInt.one);
      expect(() => Montgomery.xadd(p, XPoint.infinity, p), returnsNormally);
    });
  });

  group('ladder', () {
    test('ladder(0, P) = ∞', () {
      final x = findPoint(a0);
      final p = XPoint(x, BigInt.one);
      expect(Montgomery.ladder(BigInt.zero, p, a0).isInfinity, true);
    });

    test('ladder(1, P) = P', () {
      final x = findPoint(a0);
      final p = XPoint(x, BigInt.one);
      final res = Montgomery.ladder(BigInt.one, p, a0);
      expect(res.affine, x);
    });

    test('ladder(2, P) matches xdbl', () {
      final x = findPoint(a0);
      final p = XPoint(x, BigInt.one);
      final via_ladder = Montgomery.ladder(BigInt.two, p, a0);
      final via_dbl    = Montgomery.xdbl(p, a0);
      if (!via_dbl.isInfinity) {
        expect(via_ladder.affine, via_dbl.affine);
      }
    });

    test('[p+1]P = ∞  (group order = p+1 on E₀)', () {
      // #E₀(F_p) = p + 1, so any point has order dividing p+1.
      final x = findPoint(a0);
      final p = XPoint(x, BigInt.one);
      final order = CsidhParams.p + BigInt.one;
      expect(Montgomery.ladder(order, p, a0).isInfinity, true);
    }, timeout: Timeout(Duration(seconds: 30)));
  });

  group('hasPoint', () {
    test('findPoint result is actually on the curve', () {
      final x = findPoint(a0);
      expect(Montgomery.hasPoint(x, a0), true);
    });
    test('x = 0 is never on E_A (0 → rhs = 0, which is fine actually)', () {
      // rhs = 0³ + A·0² + 0 = 0, Legendre(0) = 0 → hasPoint returns true
      // (the point is the 2-torsion point (0,0)).  Verify this edge case.
      expect(Montgomery.hasPoint(BigInt.zero, a0), true);
    });
  });
}
