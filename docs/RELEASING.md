# Releasing Pulso

Pulso is distributed outside the Mac App Store as a DMG signed with Developer ID and notarized by Apple. Releases are built by the [Release workflow](../.github/workflows/release.yml) when a version tag is pushed. [`scripts/make-dmg.sh`](../scripts/make-dmg.sh) does the actual work, so the same steps run locally.

## Versioning

Pulso follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html). The tag sets the user-facing version (`v0.1.0` becomes `0.1.0`) and the build number is the commit count, so neither needs a manual bump. Before 1.0, minor versions may contain breaking changes. Tags with a suffix (`v0.2.0-beta.1`) are published as prereleases.

## Cutting a release

1. On an up-to-date `main`, move the `Unreleased` entries in `CHANGELOG.md` under a new heading `## [x.y.z] - YYYY-MM-DD`, leave an empty `Unreleased` section above it, and merge that change.
2. Tag and push:

   ```sh
   git tag -a vx.y.z -m "Pulso x.y.z"
   git push origin vx.y.z
   ```

3. The workflow builds the app, signs it, packs `Pulso-x.y.z.dmg`, notarizes and staples it, and publishes a GitHub release with the changelog section as notes, plus the DMG and its SHA-256.
4. Download the DMG on a Mac that has never run Pulso, open it and check that Gatekeeper accepts it without a warning.

If a run fails after the tag exists, fix the cause and rerun it from the Actions tab with **Run workflow**, giving the same tag.

## One-time setup

### Developer ID certificate

Only the Account Holder of the Apple Developer team can create one.

1. Generate a key and a certificate signing request (CSR):

   ```sh
   openssl genrsa -out developer-id.key 2048
   openssl req -new -key developer-id.key -out developer-id.csr -subj "/CN=Developer ID/O=E-Dew, LLC/C=US"
   ```

2. In the [Apple Developer portal](https://developer.apple.com/account/resources/certificates/add), choose **Developer ID Application**, select the **G2 Sub-CA**, upload the CSR and download `developerID_application.cer`.
3. Bundle the key and certificate into a `.p12` for CI:

   ```sh
   openssl x509 -inform DER -in developerID_application.cer -out developer-id.pem
   openssl pkcs12 -export -legacy -inkey developer-id.key -in developer-id.pem -out developer-id.p12
   ```

### Repository secrets

Add these in **Settings > Secrets and variables > Actions**, or with `gh secret set`:

| Secret | Value |
| --- | --- |
| `DEVELOPER_ID_P12_BASE64` | `base64 -i developer-id.p12` |
| `DEVELOPER_ID_P12_PASSWORD` | The password chosen when exporting the `.p12` |
| `ASC_KEY_ID` | App Store Connect API key ID, used by `notarytool` |
| `ASC_ISSUER_ID` | App Store Connect issuer ID |
| `ASC_KEY_P8_BASE64` | `base64 -i AuthKey_<key id>.p8` |

The API key needs the Developer role or higher. Keep the `.key`, `.p12` and `.p8` files out of the repository.

## Releasing from a Mac

With the certificate in the login keychain and the API key on disk:

```sh
ASC_KEY_ID=... ASC_ISSUER_ID=... ASC_KEY_PATH=~/path/AuthKey.p8 scripts/make-dmg.sh x.y.z
gh release create vx.y.z build/Pulso-x.y.z.dmg build/Pulso-x.y.z.dmg.sha256 --title "Pulso x.y.z" --notes-file notes.md
```

For a dry run without notarization, set `NOTARIZE=0`. If you have more than one matching certificate, set `SIGNING_IDENTITY` to the certificate's SHA-1 hash from `security find-identity -v -p codesigning`.
