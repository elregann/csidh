// lib/src/montgomery.dart
//
// Montgomery curve arithmetic — x-coordinate only.
//
// We work with supersingular Montgomery curves over F_p of the form
//
//   E_A : y² = x³ + A·x² + x,   A ∈ F_p.
//
// Because CSIDH never needs the y-coordinate during the main group-action
// computation, all routines operate on projective x-coordinates  (X : Z)
// representing  x = X/Z.
//
// Coordinate system:
//   Affine x  ←→  Projective (X : Z)  with  x = X · Z⁻¹.
//   The point at infinity is represented as  (1 : 0).
//
// References:
//   [CLM+18]  Castryck et al., eprint.iacr.org/2018/383, Algorithm 1.
//   [M87]     Montgomery, "Speeding the Pollard and Elliptic Curve Methods
//             of Factorisation", Math. Comp. 48 (1987), §10.3.
//   [C17]     Costello & Hisil, ASIACRYPT 2017 — differential addition
//             and doubling formulae used verbatim here.

import '../src/field.dart';

// ── Projective x-coordinate point ────────────────────────────────────────────

/// A point on a Montgomery curve represented as a projective x-coordinate.
///
///   P = (X : Z)   means   x_P = X · Z⁻¹  (when Z ≠ 0).
///   P = (1 : 0)   is the point at infinity (identity of the group).
class XPoint {
  final BigInt x; // projective X
  final BigInt z; // projective Z

  const XPoint(this.x, this.z);

  /// The point at infinity  O = (1 : 0).
  static final XPoint infinity = XPoint(BigInt.one, BigInt.zero);

  /// Whether this represents the point at infinity.
  bool get isInfinity => z == BigInt.zero;

  /// Recover the affine x-coordinate  X · Z⁻¹ mod p.
  ///
  /// Throws [StateError] if called on the point at infinity.
  BigInt get affine {
    if (isInfinity) throw StateError('point at infinity has no affine x');
    return Fp.mul(x, Fp.inv(z));
  }

  @override
  String toString() => isInfinity ? '(∞)' : '($x : $z)';
}

// ── Montgomery differential arithmetic ────────────────────────────────────────

/// x-only differential arithmetic on Montgomery curves  E_A : y²=x³+Ax²+x.
///
/// All operations take A in affine form (a single BigInt) and points as
/// [XPoint] projective coordinates.  No y-coordinate is ever computed.
class Montgomery {
  Montgomery._(); // non-instantiable

  // ── xDBL: projective x-only doubling ────────────────────────────────────

  /// Double a point  P → [2]P  using the Montgomery doubling formula.
  ///
  /// Formula (projective, B=1):
  ///   U = (X + Z)²
  ///   V = (X − Z)²
  ///   X₂ = U · V
  ///   W = U − V
  ///   Z₂ = W · (V + ((A+2)/4) · W)
  ///
  /// Cost: 2S + 2M + 1 mul-by-constant  (S = squaring, M = multiplication).
  ///
  /// [ref: xDBL in Castryck et al. reference C, csidh.c line ~80]
  /// [ref: [M87] §10.3, equation (1)]
  static XPoint xdbl(XPoint p, BigInt a) {
    if (p.isInfinity) return XPoint.infinity;

    // a24 = (A + 2) / 4 = (A + 2) · 4⁻¹  mod p
    // Pre-computing this per call is fine in the BigInt layer;
    // the limb-based layer will cache it per curve.
    final a24 = Fp.mul(
      Fp.add(a, BigInt.two),
      Fp.inv(BigInt.from(4)),
    );

    final u = Fp.sq(Fp.add(p.x, p.z));   // (X + Z)²
    final v = Fp.sq(Fp.sub(p.x, p.z));   // (X − Z)²
    final w = Fp.sub(u, v);               // U − V
    final x2 = Fp.mul(u, v);             // X₂ = U · V
    final z2 = Fp.mul(w, Fp.add(v, Fp.mul(a24, w))); // Z₂

    return XPoint(x2, z2);
  }

  // ── xADD: projective differential addition ────────────────────────────────

  /// Add two points given their difference:  P + Q  knowing  P − Q.
  ///
  /// This is the core of the Montgomery ladder: we maintain the invariant
  ///   R₀ = [k]P,   R₁ = [k+1]P,   diff = P
  /// and advance using only xADD and xDBL.
  ///
  /// Formula (projective):
  ///   U = (Xₚ − Zₚ)(Xᵩ + Zᵩ)
  ///   V = (Xₚ + Zₚ)(Xᵩ − Zᵩ)
  ///   X₊ = Z_diff · (U + V)²
  ///   Z₊ = X_diff · (U − V)²
  ///
  /// Cost: 4M + 2S.
  ///
  /// [ref: xADD in csidh.c]
  /// [ref: [C17] Appendix A, differential addition formula]
  static XPoint xadd(XPoint p, XPoint q, XPoint diff) {
    final u = Fp.mul(Fp.sub(p.x, p.z), Fp.add(q.x, q.z));
    final v = Fp.mul(Fp.add(p.x, p.z), Fp.sub(q.x, q.z));
    final add = Fp.sq(Fp.add(u, v));           // (U + V)²
    final sub = Fp.sq(Fp.sub(u, v));           // (U − V)²
    final xOut = Fp.mul(diff.z, add);
    final zOut = Fp.mul(diff.x, sub);
    return XPoint(xOut, zOut);
  }

  // ── Montgomery ladder ─────────────────────────────────────────────────────

  /// Scalar multiplication  [k]P  using the Montgomery ladder.
  ///
  /// This is Algorithm 1 in [CLM+18] expressed as x-coordinate-only
  /// scalar multiplication.  The ladder maintains:
  ///
  ///   R₀ = [m]P,   R₁ = [m+1]P
  ///
  /// scanning bits of k from MSB to LSB.  At each step:
  ///   bit = 0:  R₁ ← R₀ + R₁,   R₀ ← [2]R₀
  ///   bit = 1:  R₀ ← R₀ + R₁,   R₁ ← [2]R₁
  ///
  /// Note: this is variable-time — the branch on `bit` leaks the scalar
  /// in a side-channel adversary model.  Constant-time (SIMBA) comes later.
  ///
  /// Returns [k]P as a projective [XPoint], or [XPoint.infinity] if k = 0.
  ///
  /// [ref: ladder() in csidh.c]
  /// [ref: [M87] §10.3.1]
  static XPoint ladder(BigInt k, XPoint p, BigInt a) {
    if (k == BigInt.zero) return XPoint.infinity;
    if (p.isInfinity)    return XPoint.infinity;

    XPoint r0 = XPoint.infinity;
    XPoint r1 = p;

    final bits = k.bitLength;
    for (int i = bits - 1; i >= 0; i--) {
      final bit = (k >> i) & BigInt.one;
      if (bit == BigInt.zero) {
        r1 = xadd(r0, r1, p);   // R₁ ← R₀ + R₁
        r0 = xdbl(r0, a);       // R₀ ← [2]R₀
      } else {
        r0 = xadd(r0, r1, p);   // R₀ ← R₀ + R₁
        r1 = xdbl(r1, a);       // R₁ ← [2]R₁
      }
    }
    return r0;
  }

  // ── Point validation ──────────────────────────────────────────────────────

  /// Check whether affine x lies on  E_A : y² = x³ + Ax² + x  over F_p.
  ///
  /// A point exists with x-coordinate `x` iff the RHS is a quadratic
  /// residue (or zero) in F_p, i.e. Legendre(rhs) ∈ {0, 1}.
  ///
  /// Used in the kernel-point sampling loop of the isogeny computation.
  ///
  /// [ref: pointOK() in csidh.c]
  static bool hasPoint(BigInt x, BigInt a) {
    // rhs = x³ + Ax² + x  =  x·(x² + Ax + 1)
    final x2  = Fp.sq(x);
    final rhs = Fp.mul(x, Fp.add(Fp.add(x2, Fp.mul(a, x)), BigInt.one));
    return Fp.legendre(rhs) >= 0; // QR or zero
  }

  // ── Curve coefficient recovery ────────────────────────────────────────────

  /// Recover the Montgomery coefficient A′ of the image curve after an
  /// ℓ-isogeny, given the 3-point formula.
  ///
  /// This is used in the Vélu-based isogeny image computation.
  /// See [isogeny.dart] for the full context.
  ///
  /// Formula (affine):
  ///   σ = Σ (xᵢ − 1/xᵢ)   for i = 0, …, (ℓ−3)/2
  ///   π = Π xᵢ
  ///   A′ = A · π^8 − 6·σ·π^4
  ///         ... [Elkies / Renes formula for Montgomery curves]
  ///
  /// In practice we use the projective kernel-sum version from Renes
  /// "Complete addition formulas for prime order elliptic curves",
  /// which avoids separate inversion.  The affine shortcut above is
  /// kept here for reference / small-prime fast paths.
  ///
  /// [ref: isog() in csidh.c, lines computing A_new]
  static BigInt recoverA(BigInt sigmaNum, BigInt sigmaDen,
                          BigInt piNum,    BigInt piDen) {
    // A′ = (A·piNum⁸ − 6·sigmaNum·piNum⁴·piDen⁴) / piDen⁸
    // … actual implementation lives in isogeny.dart; stub here for docs.
    throw UnimplementedError('use Isogeny.computeImageCurve()');
  }
}
