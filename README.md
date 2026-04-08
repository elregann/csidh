# csidh_dart

Pure-Dart implementation of **CSIDH-512** — a post-quantum non-interactive key exchange protocol based on commutative supersingular isogenies.

## References

| Paper | Role |
|---|---|
| Castryck, Lange, Martindale, Panny, Renes — [eprint.iacr.org/2018/383](https://eprint.iacr.org/2018/383) | Primary spec — Algorithm 1 & 2 |
| Meyer & Reith — [eprint.iacr.org/2018/782](https://eprint.iacr.org/2018/782) | A′ recovery formula, Edwards speedup |
| Meyer, Campos, Reith — [eprint.iacr.org/2018/1198](https://eprint.iacr.org/2018/1198) | Constant-time (SIMBA) — Phase 2 |

## Architecture

```
lib/src/
  params.dart        — CSIDH-512 domain parameters (p, ells, m)
  field.dart         — F_p arithmetic  (Fp.add / sub / mul / inv / sqrt)
  montgomery.dart    — x-only Montgomery curves  (xdbl, xadd, ladder)
  isogeny.dart       — Vélu ℓ-isogenies  (xisog, xeval)
  group_action.dart  — class-group action evaluation  (Algorithm 1)
  csidh.dart         — public API  (keygen, publicKey, sharedSecret)
```

## Status (Phase 1)

- [x] F_p arithmetic (BigInt, variable-time)
- [x] x-only Montgomery ladder
- [x] Vélu isogeny computation (xISOG + xEVAL)
- [x] Group action evaluation
- [x] Key generation, public key, shared secret
- [ ] Constant-time (SIMBA / dummy isogenies) — Phase 2
- [ ] Limb-based 512-bit arithmetic — Phase 2
- [ ] Full supersingularity validation — Phase 2

## Quick start

```dart
import 'package:csidh_dart/csidh_dart.dart';

final skAlice = Csidh.generateSecretKey();
final skBob   = Csidh.generateSecretKey();

final pkAlice = Csidh.publicKey(skAlice);
final pkBob   = Csidh.publicKey(skBob);

final ssAlice = Csidh.sharedSecret(skAlice, pkBob);
final ssBob   = Csidh.sharedSecret(skBob,   pkAlice);

assert(ssAlice == ssBob); // commutativity — both sides get the same curve
```