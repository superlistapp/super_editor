# Releasing Super Editor

Follow these steps to release new versions of Super Editor:

1. Checkout the tip of the `main` branch
2. Update the `CHANGELOG.md` to describe the important changes in this release
3. Merge the `CHANGELOG.md` update into `main` and ensure you're at the new tip of `main`
4. Follow official instructions to publish a new version to pub.dev: https://dart.dev/tools/pub/publishing#publishing-your-package
5. Tag the commit that was published with the version, e.g., "v0.1.0", and push that tag to `origin`
