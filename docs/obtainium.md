# Automatic updates with Obtainium

[Obtainium](https://github.com/ImranR98/Obtainium) installs and updates
Android apps straight from their GitHub releases. NOTORYX Core (independent
edition) is published as GitHub releases, so Obtainium can keep it current.

## Set it up

1. Install Obtainium, then tap **Add App**.
2. **App source URL:**
   `https://github.com/TheLogsAreScreaming/notoryx-core-independent-releases`
3. Turn on **Include prereleases**. Every test build is a prerelease, so
   without this Obtainium finds nothing.
4. **Filter APKs by regular expression:** `arm64` for almost every phone, or
   `android\.apk$` for the full build (older 32-bit phones, Chromebooks).
   Without a filter Obtainium asks which file to install each time.
5. Tap **Add**, then **Install**.

If you already installed a test build by hand, Obtainium updates that copy:
both are signed with the same key.

## Why it works

- Release tags look like `v0.1.0-test.15`. Tag builds name the app after the
  tag (`0.1.0-test.15`), so the installed version matches the release and
  Obtainium only offers real updates.
- Both APKs in a release share one version code and one signing key, so you
  can switch between them.
- Obtainium refuses an update signed with a different key. The release
  certificate's SHA-256 is
  `2a3e26c01231a764fb398ef4fd844f8a0b782228013b1aba5a10c41ac3500924`.
