# TODO

State as of 2026-09-29, end of day. URL filtering works on device for the first time
(iPhone 15 Pro Max on iOS 27.0, iPhone 11 Pro Max on iOS 26.6.1).

## Where the code is

- Server scripts and the live PIR probe test are kept in `build/server-scripts/`
  (git-ignored) in the main working directory.

- Branch `fix/url-filter` holds the filter fixes, on top of `main`.
- The redesign (views, theme, website) is **uncommitted** in the main working directory,
  together with the same fixes written against the redesigned screens.
- Do not switch to `fix/url-filter` in the main working directory; it conflicts.
  To put the redesign on top of the fixes:
  `git switch -c redesign && git reset --soft fix/url-filter`, then review and commit.

## Verify on a device

- [ ] Restart after a list change when the app is left immediately. Switch Adult off,
      go straight to Safari, force-quit and reopen it: the site should load. Then the
      reverse. Filtering should be off for a couple of seconds at most. The background
      task that protects this was built but not yet tested.
- [ ] Apple's onboarding test URL `www.apple.com/url-filter-test` is blocked. It was
      added to the prefilter but not checked. The PIR database lists only the `www`
      form; iOS strips `www`, so the bare form may need adding to the database.
- [ ] Clean install, as a reviewer would do it: delete the app, install, enable
      filtering, open an adult site in Safari.
- [ ] "Adult was off by default" was seen once. Find out on which phone and whether
      the app had been deleted first. If so, the app group container survives deletion
      and carries old list settings into a fresh install.
- [ ] Onboarding is skipped when the filter is already running.
- [ ] The paywall shows the monthly and yearly plans from App Store Connect.
- [ ] The iPhone 11 Pro Max has an older build; install the current one.

## Build

- [ ] **Ads from subdomains**: a hostname-level list (StevenBlack unified hosts) is now
      bundled, entries are normalised to the form iOS looks up (no leading `www.`), and
      the server database was rebuilt to match on 2026-09-30 (159,417 keywords). The
      server answers correctly, and on 2026-09-30 the verdict probe on the iPhone 15
      (iOS 27.0) denied all six Google ad hostnames tested. Still to confirm: bbc.co.uk
      shows fewer ads in a reopened Safari.
- [ ] **After the PIR server restarts, the filter can stop and stay stopped.** The server
      creates new token keys on every start, so tokens a phone already holds are refused
      (401 "No token key found"). Seen on 2026-09-30 after the database update: the
      filter went to `stopped` and iOS did not retry. The app now restarts a stopped
      filter when it is opened (`FilterRefresher.restartIfStopped`), not yet verified.
      Server fixed on 2026-09-30: PIRService is patched with `--token-key-file`
      (`build/server-scripts/pir-token-key.patch`) and keeps its key in
      `/opt/phosphor/token-key.pem`. Verified that the key is unchanged across a restart.
      Reapply the patch if the server is ever rebuilt from upstream.
- [ ] Subdomains of listed sites are not blocked (`ad.doubleclick.net` loads although
      `doubleclick.net` is listed). Needs `NEURLFilterManager.urlParsingConfiguration`,
      which is in the iOS 27 SDK only. Install Xcode 27, then add it behind an
      `#available(iOS 27, *)` check.
- [ ] Decide what to do with `FilterProbe`. It logs filter verdicts when the app is
      launched with `PHOSPHOR_PROBE_URLS` set. Remove it or keep it out of release builds.
- [ ] Re-enabling the filter from the dashboard goes through the whole onboarding.
      A direct button would be better.
- [ ] Pause ends only when the app is next opened, because iOS gives the app no way to
      run at a set time. Consider a notification when the pause runs out.
- [ ] Commit the redesign.

## Server

- [ ] The PIR service was rebuilt from apple/pir-service-example at `c4ee860` and sits
      behind nginx, which also provides the request log. Both changes have undo scripts;
      decide whether to keep them and record the setup in the server notes.
- [ ] Evaluation keys are kept in memory and are lost when the service restarts.
      Phones recover on their own; check how long that takes.
- [ ] The auth token in git history before this branch is no longer valid. Nothing to
      do unless history is to be rewritten.

## App Store

- [ ] Paid Apps Agreement: was "Processing" after the bank account was added.
- [ ] Compliance Screening form in App Store Connect.
- [ ] Both subscriptions are "Developer Rejected" and have to be added to the next
      submission.
- [ ] Apple's relay onboarding for NE URL Filter configuration
      `b2f98894-6a27-4a1d-b050-79e23fd81022` was "pending" on 2026-09-29. App Store and
      TestFlight builds reach the PIR server only through the relay.
- [ ] Bump the build number, archive, and resubmit with a note for App Review that
      Safari has to be reopened after the filter is enabled or a list is changed.

## Known behaviour, not bugs

- A running app keeps the filter it connected with. After a list change, other apps
  pick up the new filter when they are next opened.
- Right after an install or a restart, iOS can fail to find the extension for a few
  seconds. It succeeds on a later retry.
- The PIR auth token must be valid base64. With anything else iOS sends requests
  without a Privacy Pass token and the filter never starts, with no error naming the token.
- The filter extension may use 6 MB of memory at most, so the Bloom filter is built by
  the app.
- The Simulator cannot run the filter; it has no Network Extension service.
