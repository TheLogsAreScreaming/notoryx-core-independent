# Vendored packages

Third-party plugins kept here because the published versions no longer
build. Each keeps its original license file. None of this is meshcore-open
code.

| Package | Version | License | Why vendored |
|---|---|---|---|
| `usb_serial` | 0.5.2 | BSD-3-Clause | Its Android build uses `jcenter()`, which current Gradle removed. Only `android/build.gradle` is changed. |
