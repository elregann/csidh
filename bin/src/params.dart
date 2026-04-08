// lib/src/params.dart
//
// CSIDH-512 domain parameters.
//
// Source: Castryck, Lange, Martindale, Panny, Renes —
//         "CSIDH: An Efficient Post-Quantum Commutative Group Action"
//         ASIACRYPT 2018, Section 4 & Appendix A.
//         https://eprint.iacr.org/2018/383
//
// All values are taken verbatim from the reference implementation
// (csidh-20181118) by the original authors, available at:
//         https://csidh.isogeny.org/software.html
//
// Security level: conjectured AES-128 (NIST PQC Category I).

/// Domain parameters for CSIDH over the prime field F_p where
///
///   p = 4 · ℓ₁ · ℓ₂ · … · ℓ₇₄ · f − 1,   f = 1, p ≡ 3 (mod 4)
///
/// The 74 small odd primes ℓᵢ split completely in the imaginary quadratic
/// field Q(√−p), so each ideal (ℓᵢ) factors into two conjugate ideals
/// whose classes generate the action used for key exchange.
class CsidhParams {
  CsidhParams._(); // non-instantiable — pure namespace

  // ── Prime field ──────────────────────────────────────────────────────────

  /// The 512-bit prime p = 4·ℓ₁·…·ℓ₇₄ − 1.
  ///
  /// This is the unique prime of this form that fits in 512 bits and
  /// gives a supersingular Montgomery curve E₀: y² = x³ + x over F_p
  /// (the starting curve, A = 0).
  static final BigInt p = BigInt.parse(
    '65560271521777552938595898923997456044386406938637975622552819756491987'
    '36952870995379498453882894883394474778035153188060862445203741422547088'
    '78003533019529',
  );

  // ── Starting curve ────────────────────────────────────────────────────────

  /// Montgomery coefficient of the base curve E₀: y² = x³ + Ax² + x.
  ///
  /// A = 0 corresponds to the curve y² = x³ + x, which is supersingular
  /// over F_p because p ≡ 3 (mod 4).  Its j-invariant is 1728.
  static final BigInt A0 = BigInt.zero;

  // ── Small odd primes (the "action primes") ────────────────────────────────

  /// The 74 small odd primes ℓ₁ < ℓ₂ < … < ℓ₇₄ used to generate isogenies.
  ///
  /// These are the first 74 odd primes starting at 3.  Together with the
  /// factor 4 they satisfy  4 · ∏ᵢ ℓᵢ = p + 1,  which guarantees that
  /// every ℓᵢ-isogeny can be computed using a kernel point of order ℓᵢ
  /// found entirely over F_p (no extension field required).
  ///
  /// Index i corresponds to the prime ℓᵢ₊₁  (0-based).
  static const List<int> ells = [
    3, 5, 7, 11, 13, 17, 19, 23, 29, 31,       // ℓ₁  … ℓ₁₀
    37, 41, 43, 47, 53, 59, 61, 67, 71, 73,     // ℓ₁₁ … ℓ₂₀
    79, 83, 89, 97, 101, 103, 107, 109, 113,    // ℓ₂₁ … ℓ₂₉
    127, 131, 137, 139, 149, 151, 157, 163,     // ℓ₃₀ … ℓ₃₇
    167, 173, 179, 181, 191, 193, 197, 199,     // ℓ₃₈ … ℓ₄₅
    211, 223, 227, 229, 233, 239, 241, 251,     // ℓ₄₆ … ℓ₅₃
    257, 263, 269, 271, 277, 281, 283, 293,     // ℓ₅₄ … ℓ₆₁
    307, 311, 313, 317, 331, 337, 347, 349,     // ℓ₆₂ … ℓ₆₉
    353, 359, 367, 373, 379, 383,               // ℓ₇₀ … ℓ₇₄  (n = 74)
  ];

  /// Number of action primes  (n = 74 for CSIDH-512).
  static const int n = 74;

  // ── Secret-key space ─────────────────────────────────────────────────────

  /// Bound on each secret exponent  eᵢ ∈ [−m, m].
  ///
  /// The paper recommends m = 5 for CSIDH-512 at the 128-bit security
  /// level.  The secret key is a vector e = (e₁, …, e₇₄) ∈ {−m,…,m}⁷⁴.
  ///
  /// Reference: Section 4.3 of eprint.iacr.org/2018/383.
  static const int m = 5;

  // ── Modular square-root exponent ──────────────────────────────────────────

  /// Exponent used for  x^((p+1)/4)  to compute square roots modulo p.
  ///
  /// Because p ≡ 3 (mod 4) we have  √x ≡ x^((p+1)/4) (mod p)  whenever
  /// x is a quadratic residue.  This avoids Tonelli-Shanks entirely.
  static final BigInt sqrtExp = (p + BigInt.one) >> 2;

  // ── Cofactor ──────────────────────────────────────────────────────────────

  /// Cofactor h such that  #E₀(F_p) = h · ∏ᵢ ℓᵢ  with h = 4.
  ///
  /// Used when deriving a kernel point: multiply a random x-coordinate
  /// survivor by h to kill the cofactor part before the ℓᵢ-order check.
  static const int cofactor = 4;
}
