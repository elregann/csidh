// lib/src/csidh.dart
//
// CSIDH public API — key generation, public key derivation, shared secret.
//
// This layer wraps [GroupAction.apply] into the three operations needed
// for non-interactive Diffie-Hellman key exchange:
//
//   keygen()     → SecretKey  (random e ∈ {−m,…,m}⁷⁴)
//   publicKey()  → PublicKey  (A′ = e ★ A₀,  A₀ = 0)
//   sharedKey()  → SharedKey  (A″ = e_A ★ A_B = e_B ★ A_A,  commutativity)
//
// Commutativity of the class-group action guarantees:
//   e_A ★ (e_B ★ A₀)  =  e_B ★ (e_A ★ A₀)
//
// so both parties independently arrive at the same curve coefficient A″,
// which is used as the shared secret (after hashing in a real protocol).
//
// Wire format:
//   Public key: 64 bytes, little-endian encoding of A ∈ F_p (512-bit).
//   Secret key: 74 bytes, one signed byte per exponent eᵢ ∈ [−5, 5].
//
// Reference:
//   [CLM+18]  Castryck et al., eprint.iacr.org/2018/383, §3 "The protocol".
//   Public-key encoding matches the reference implementation (csidh.c).

import 'dart:math';
import 'dart:typed_data';

import 'group_action.dart';
import 'params.dart';

// ── Key types ────────────────────────────────────────────────────────────────

/// A CSIDH-512 secret key.
///
/// Internally: a vector  e = (e₁, …, e₇₄)  with  eᵢ ∈ [−m, m],  m = 5.
/// On the wire: 74 signed bytes (Int8List).
class SecretKey {
  /// The exponent vector — do not expose outside of trusted code.
  final List<int> _e;

  SecretKey._(this._e);

  /// Parse a secret key from its wire encoding (74 signed bytes).
  factory SecretKey.fromBytes(Uint8List bytes) {
    if (bytes.length != CsidhParams.n) {
      throw ArgumentError('SecretKey must be ${CsidhParams.n} bytes');
    }
    final e = List<int>.generate(CsidhParams.n, (i) {
      final v = bytes[i].toSigned(8);
      if (v < -CsidhParams.m || v > CsidhParams.m) {
        throw ArgumentError('exponent out of range at index $i: $v');
      }
      return v;
    });
    return SecretKey._(e);
  }

  /// Encode the secret key as 74 signed bytes.
  Uint8List toBytes() {
    final out = Uint8List(CsidhParams.n);
    for (int i = 0; i < CsidhParams.n; i++) {
      out[i] = _e[i] & 0xff; // two's complement for negative values
    }
    return out;
  }

  List<int> get exponents => List.unmodifiable(_e);
}

/// A CSIDH-512 public key.
///
/// Internally: the Montgomery coefficient  A ∈ F_p  of the image curve.
/// On the wire: 64 bytes, little-endian.
///
/// [ref: §3 "Public key = A ∈ F_p, encoded as 64-byte string"]
class PublicKey {
  /// The curve coefficient  A ∈ F_p.
  final BigInt a;

  const PublicKey(this.a);

  /// Parse a public key from its 64-byte wire encoding (little-endian).
  factory PublicKey.fromBytes(Uint8List bytes) {
    if (bytes.length != 64) {
      throw ArgumentError('PublicKey must be 64 bytes');
    }
    BigInt a = BigInt.zero;
    for (int i = 0; i < 64; i++) {
      a |= BigInt.from(bytes[i]) << (8 * i);
    }
    if (a >= CsidhParams.p) {
      throw ArgumentError('public key coefficient out of range');
    }
    return PublicKey(a);
  }

  /// Encode the public key as 64 bytes (little-endian).
  ///
  /// [ref: public_key encoding in csidh.c — 64-byte little-endian BigInt]
  Uint8List toBytes() {
    final out = Uint8List(64);
    var v = a;
    for (int i = 0; i < 64; i++) {
      out[i] = (v & BigInt.from(0xff)).toInt();
      v >>= 8;
    }
    return out;
  }

  @override
  bool operator ==(Object other) => other is PublicKey && other.a == a;

  @override
  int get hashCode => a.hashCode;
}

/// A CSIDH shared secret (the raw curve coefficient after both actions).
///
/// In a complete protocol this would be hashed (e.g. SHA-3) before use.
/// We expose the raw form here to allow testing and custom KDF integration.
class SharedSecret {
  /// Raw Montgomery coefficient of the shared curve.
  final BigInt a;
  const SharedSecret(this.a);

  /// Encode as 64 bytes (same format as [PublicKey]).
  Uint8List toBytes() => PublicKey(a).toBytes();

  @override
  bool operator ==(Object other) => other is SharedSecret && other.a == a;
}

// ── Main CSIDH API ────────────────────────────────────────────────────────────

/// CSIDH-512 non-interactive key exchange.
///
/// Usage:
/// ```dart
/// final alice = Csidh.generateSecretKey();
/// final bob   = Csidh.generateSecretKey();
///
/// final pkAlice = Csidh.publicKey(alice);
/// final pkBob   = Csidh.publicKey(bob);
///
/// final ssAlice = Csidh.sharedSecret(alice, pkBob);
/// final ssBob   = Csidh.sharedSecret(bob,   pkAlice);
///
/// assert(ssAlice == ssBob); // commutativity
/// ```
class Csidh {
  Csidh._(); // non-instantiable

  // ── Key generation ────────────────────────────────────────────────────────

  /// Generate a random CSIDH-512 secret key.
  ///
  /// Samples each eᵢ uniformly from  {−m, −m+1, …, m}  (m = 5).
  ///
  /// Uses [Random.secure] (CSPRNG) for key material.
  ///
  /// [ref: key generation described in [CLM+18] §3]
  static SecretKey generateSecretKey() {
    final rng = Random.secure();
    final e = List<int>.generate(
      CsidhParams.n,
      (_) => rng.nextInt(2 * CsidhParams.m + 1) - CsidhParams.m,
    );
    return SecretKey._(e);
  }

  // ── Public key derivation ─────────────────────────────────────────────────

  /// Derive the public key  A′ = e ★ A₀  from a secret key.
  ///
  /// [A₀] = 0 is the base curve  E₀ : y²=x³+x  (j-invariant 1728).
  ///
  /// This is a group-action evaluation starting from the base curve;
  /// it takes ~100 ms on a modern desktop in the BigInt layer.
  ///
  /// [ref: [CLM+18] §3, "Alice computes  A_A = [e_A] ★ E₀"]
  static PublicKey publicKey(SecretKey sk) {
    final aImage = GroupAction.apply(CsidhParams.A0, sk._e);
    return PublicKey(aImage);
  }

  // ── Shared secret derivation ──────────────────────────────────────────────

  /// Compute the shared secret  A″ = e_self ★ A_other.
  ///
  /// Correctness relies on commutativity of the group action:
  ///   e_A ★ (e_B ★ A₀) = e_B ★ (e_A ★ A₀)
  ///
  /// In a real protocol, pass [SharedSecret.toBytes] through a KDF
  /// (e.g. HKDF-SHA3-256) before using as a symmetric key.
  ///
  /// [ref: [CLM+18] §3, "Bob computes  A″ = [e_B] ★ A_A"]
  static SharedSecret sharedSecret(SecretKey sk, PublicKey theirPublicKey) {
    final aShared = GroupAction.apply(theirPublicKey.a, sk._e);
    return SharedSecret(aShared);
  }

  // ── Public key validation ─────────────────────────────────────────────────

  /// Validate a public key (check A ∈ [0, p) and E_A is supersingular).
  ///
  /// Full supersingularity check is expensive; for Phase 1 we only verify
  /// that A is in range.  A complete check follows [CLM+18] §3 footnote 8.
  ///
  /// [ref: validate() in csidh.c — checks the group order via scalar mult]
  static bool validatePublicKey(PublicKey pk) {
    // Range check: A ∈ [0, p)
    if (pk.a < BigInt.zero || pk.a >= CsidhParams.p) return false;
    // TODO(phase2): add full supersingularity check via #E_A(F_p) = p+1 test.
    return true;
  }
}
