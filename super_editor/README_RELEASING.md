# Releasing Super Editor
Super Editor maintains two active branches and releases: `main` and `stable`.

The `main` branch tracks Flutter's `master` branch. The `stable` branch tracks Flutter's `stable` branch.

New releases should be cut for both branches at the same time (unless other factors dictate otherwise).

Releases based on `main` should end with `-dev.X`, e.g. `v0.2.1-dev.1`.

Releases based on `stable` should use standard versioning, e.g., `v0.2.1`.

To release `main`:

1. Checkout the tip of the `main` branch
2. Increment the build version in the pubspec, e.g., `v0.2.1-dev.1` -> `v0.2.2-dev.1`
3. Update the `CHANGELOG.md` to describe the important changes in this release. Take this opportunity to add descriptions for both the `-dev` release and the standard release.
4. Use a PR to merge the `CHANGELOG.md` and version update into `main`.
5. Pull the latest version of `main` from `origin`, which should now be ready to publish.
6. Follow official instructions to publish a new version to pub.dev: https://dart.dev/tools/pub/publishing#publishing-your-package
7. Tag the commit that was published with the version, e.g., "v0.2.2-dev.1", and push that tag to `origin`

To release `stable`:

1. Follow instructions above to release to `main`.
2. Create a branch off of `stable` called something like `release-stable`.
3. Cherry pick the commit from `main` with the `CHANGELOG.md` and build version change.
4. Remove the `-dev.X` from the build version in the pubspec, e.g., `v0.2.2-dev.1` => `v0.2.2`.
5. Use a PR to merge these changes into `stable`.
6. Pull the latest version of `stable` from `origin`, which should now be ready to publish. 
7. Follow official instructions to publish a new version to pub.dev: https://dart.dev/tools/pub/publishing#publishing-your-package
8. Tag the commit that was published with the version, e.g., "v0.2.2", and push that tag to `origin`