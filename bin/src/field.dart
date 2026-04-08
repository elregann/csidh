// lib/src/field.dart
//
// Field arithmetic over F_p  (the prime field of CSIDH-512).
//
// This file implements the six fundamental operations on elements of
//   F_p = Z / pZ,   p = CsidhParams.p  (512-bit prime, p ≡ 3 mod 4).
//
// Implementation strategy (Phase 1 — correctness first):
//   • All values are Dart native BigInt.
//   • Every operation reduces the result with a single `mod p` call.
//   • No constant-time guarantees — this is the variable-time
//     proof-of-concept matching the original Castryck et al. C code.
//
// Reference:
//   Castryck et al., eprint.iacr.org/2018/383, Appendix A.
//   The C reference uses GMP mp_limb_t arithmetic; we replicate the
//   mathematical behaviour exactly, not the bit-level representation.
//
// Each function carries a short tag in its doc-comment indicating which
// C function in the reference implementation it corresponds to, e.g.
//   // [ref: fp_add]

import '../src/params.dart';

/// Arithmetic in the prime field  F_p = Z/pZ.
///
/// All inputs must already be in the range [0, p).
/// All outputs are normalised to the same range.
class Fp {
  Fp._(); // non-instantiable — pure namespace

  static final BigInt _p = CsidhParams.p;

  // ── Core operations ───────────────────────────────────────────────────────

  /// Addition in F_p.
  ///
  ///   result = (a + b) mod p
  ///
  /// [ref: fp_add]  C equivalent: mp_add then conditional subtract.
  static BigInt add(BigInt a, BigInt b) => (a + b) % _p;

  /// Subtraction in F_p.
  ///
  ///   result = (a − b) mod p
  ///
  /// Dart's `%` operator always returns a non-negative result for positive
  /// moduli, so no explicit conditional add is needed (unlike C).
  ///
  /// [ref: fp_sub]
  static BigInt sub(BigInt a, BigInt b) => (a - b) % _p;

  /// Multiplication in F_p.
  ///
  ///   result = (a · b) mod p
  ///
  /// [ref: fp_mul]  C equivalent: schoolbook or Karatsuba + Montgomery
  /// reduction.  We rely on Dart's BigInt for both the product and the
  /// modular reduction.
  static BigInt mul(BigInt a, BigInt b) => (a * b) % _p;

  /// Squaring in F_p.
  ///
  ///   result = a² mod p
  ///
  /// Identical to mul(a, a) in cost for BigInt; a dedicated path will
  /// matter when we move to limb-based arithmetic.
  ///
  /// [ref: fp_sq]
  static BigInt sq(BigInt a) => (a * a) % _p;

  /// Modular inverse in F_p via Fermat's little theorem.
  ///
  ///   result = a^(p−2) mod p
  ///
  /// Valid for all a ≠ 0.  Calling inv(0) returns 0 (field convention
  /// used in projective-coordinate implementations; callers that cannot
  /// guarantee a ≠ 0 should check explicitly).
  ///
  /// Cost: one modular exponentiation (~512 squarings + additions).
  ///
  /// [ref: fp_inv]  The reference uses GMP's mpz_invert; Fermat gives the
  /// same result and is simpler in a BigInt setting.
  static BigInt inv(BigInt a) {
    if (a == BigInt.zero) return BigInt.zero;
    return a.modPow(_p - BigInt.two, _p);
  }

  /// Modular exponentiation in F_p.
  ///
  ///   result = base^exp mod p
  ///
  /// Delegates to Dart's BigInt.modPow (constant-time in Dart VM? — not
  /// guaranteed; this is the variable-time layer regardless).
  ///
  /// [ref: mpz_powm in GMP]
  static BigInt pow(BigInt base, BigInt exp) => base.modPow(exp, _p);

  /// Square root in F_p using the Tonelli–special shortcut.
  ///
  ///   result = a^((p+1)/4) mod p,   valid iff p ≡ 3 (mod 4)
  ///
  /// Returns null if `a` is not a quadratic residue (i.e. a^((p−1)/2) ≠ 1).
  ///
  /// Because p ≡ 3 (mod 4) the exponent (p+1)/4 is an integer and the
  /// formula gives the square root directly — no Tonelli-Shanks iteration.
  ///
  /// [ref: fp_sqrt — not present in Castryck et al. reference C; used
  ///  internally by the x-only Montgomery routines for y-coordinate recovery
  ///  and point sampling via Elligator (future layer).]
  static BigInt? sqrt(BigInt a) {
    final root = pow(a, CsidhParams.sqrtExp);
    // Verify: root² ≡ a (mod p)
    if (sq(root) != a % _p) return null;
    return root;
  }

  // ── Utility ───────────────────────────────────────────────────────────────

  /// Normalise an arbitrary integer into [0, p).
  ///
  /// Useful after external arithmetic that may produce negative values or
  /// values ≥ p.
  static BigInt norm(BigInt a) => a % _p;

  /// Legendre symbol: is `a` a quadratic residue mod p?
  ///
  ///   +1  → QR (square root exists and a ≠ 0)
  ///    0  → a ≡ 0 (mod p)
  ///   −1  → non-residue
  ///
  /// Computed as a^((p−1)/2) mod p.
  ///
  /// Used in the kernel-point sampling loop: we need to find an x such
  /// that  x³ + Ax² + x  is a quadratic residue in F_p.
  static int legendre(BigInt a) {
    final ls = pow(a, (_p - BigInt.one) >> 1);
    if (ls == BigInt.zero) return 0;
    if (ls == BigInt.one) return 1;
    return -1; // ls == p - 1
  }

  /// Check equality of two field elements (both assumed normalised).
  static bool eq(BigInt a, BigInt b) => a == b;

  /// Return the additive inverse  (−a mod p).
  static BigInt neg(BigInt a) => a == BigInt.zero ? BigInt.zero : _p - a;
}
