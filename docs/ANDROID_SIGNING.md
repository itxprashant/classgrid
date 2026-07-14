# Android release signing

Production APKs must be signed with **one fixed release keystore** so every build
has the same certificate. Previously, release builds used each machine’s debug
key, which caused “package conflicts” when sideloading a new APK.

## One-time setup

From repo root:

```bash
chmod +x scripts/android-keystore-init.sh   # first time only
./scripts/android-keystore-init.sh
```

This creates (gitignored):

| File | Purpose |
|------|---------|
| `app/android/classgrid-release.keystore` | Release signing key |
| `app/android/key.properties` | Passwords + alias for Gradle |

**Back up both files and the passwords** (password manager, encrypted backup).
If you lose the keystore, you cannot publish updates as the same app — users
must uninstall and reinstall.

Template only (safe to commit): `app/android/key.properties.example`.

## Build & deploy

```bash
./scripts/bump-app-version.sh          # optional
./scripts/release-android-apk.sh --build
```

`--build` fails if `key.properties` is missing.

`flutter build apk --release` without the init script still works locally but
prints a warning and uses the **debug** key (not for production).

## After switching from debug-signed releases

Anyone who installed an older debug-signed APK from classgrid.devclub.in must
**uninstall ClassGrid once**, then install the new release-signed APK.

Same package (`com.devclub.classgrid`), different signature → Android blocks
in-place updates.

Force-remove if needed:

```bash
adb uninstall com.devclub.classgrid
```

## CI / other machines

Copy `classgrid-release.keystore` and `key.properties` to the build machine
securely (never commit). Paths must match `storeFile=classgrid-release.keystore`
relative to `app/android/`.

## Verify signing

```bash
apksigner verify --print-certs dist/app/classgrid.apk
```

Certificate should stay identical across releases; only `versionCode` changes.
