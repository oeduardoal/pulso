# Releasing Pulso

Pulso is distributed outside the Mac App Store, signed with a Developer ID certificate and notarized by Apple. This is the manual process; automate it once it has been run a few times.

## Versioning

Pulso follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html):

- `MARKETING_VERSION` in `project.yml` is the user-facing version (`0.1.0`).
- `CURRENT_PROJECT_VERSION` is the build number. Increase it by one for every build you upload or publish, including betas.
- Before 1.0, minor versions may contain breaking changes.

## Prerequisites

- An Apple Developer Program membership with a **Developer ID Application** certificate in your keychain.
- A notarization profile stored in the keychain:

  ```sh
  xcrun notarytool store-credentials pulso-notary \
    --apple-id <apple-id> --team-id <team-id> --password <app-specific-password>
  ```

## Steps

1. **Prepare.** On an up-to-date `main`, move the `Unreleased` entries in `CHANGELOG.md` under a new heading `## [x.y.z] - YYYY-MM-DD`. Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml`. Commit as `Release x.y.z`.

2. **Archive.**

   ```sh
   xcodegen generate
   xcodebuild -project Pulso.xcodeproj -scheme Pulso -configuration Release \
     -archivePath build/Pulso.xcarchive archive \
     CODE_SIGN_IDENTITY="Developer ID Application" DEVELOPMENT_TEAM=<team-id>
   ```

3. **Export the signed app.** Create `build/ExportOptions.plist` with `method` set to `developer-id` and your `teamID`, then:

   ```sh
   xcodebuild -exportArchive -archivePath build/Pulso.xcarchive \
     -exportOptionsPlist build/ExportOptions.plist -exportPath build/export
   ```

4. **Notarize and staple.**

   ```sh
   ditto -c -k --keepParent build/export/Pulso.app build/Pulso.zip
   xcrun notarytool submit build/Pulso.zip --keychain-profile pulso-notary --wait
   xcrun stapler staple build/export/Pulso.app
   ditto -c -k --keepParent build/export/Pulso.app build/Pulso-x.y.z.zip
   ```

5. **Verify** on a Mac that has never run the build:

   ```sh
   spctl --assess --type execute --verbose build/export/Pulso.app
   ```

   It must report `source=Notarized Developer ID`. Launch the app and check the panel in both languages.

6. **Tag and publish.**

   ```sh
   git tag -a vx.y.z -m "Pulso x.y.z"
   git push origin main vx.y.z
   ```

   Create a GitHub release from the tag, paste the changelog section as the notes and attach `Pulso-x.y.z.zip` with its SHA-256 (`shasum -a 256 build/Pulso-x.y.z.zip`).
