# TODO

State as of 2026-09-30, midday. URL filtering works on device (iPhone 15 Pro Max on
iOS 27.0, iPhone 11 Pro Max on iOS 26.6.1): adult sites, ad and tracker hosts, and
Apple's onboarding test URL are blocked. The Mac is being restarted to install Xcode 27.

## Next session: start here

1. Open Phosphor once on each phone. The server's token key was replaced on 2026-09-30,
   so the filter will have stopped; the app should restart it when opened
   (`FilterRefresher.restartIfStopped`, first real test of it). Confirm with the verdict
   probe, see "Checking the filter" below.
2. If Xcode 27 is installed, add parent-domain matching (see Build).
3. Clean-install test (see Verify on a device).

## Where things are

- Branch `fix/url-filter` on GitHub holds all filter fixes, on top of `main`. No pull
  request yet.
- The app redesign is **uncommitted** in the main working directory, together with the
  same fixes written against the redesigned screens. The website redesign was pushed
  to `main` separately.
- Do not switch to `fix/url-filter` in the main working directory; it conflicts. To put
  the redesign on top of the fixes: `git switch -c redesign && git reset --soft
  fix/url-filter`, then review and commit. To work on the branch alone, use a worktree:
  `git worktree add ../phosphor-fix fix/url-filter`.
- `build/server-scripts/` (git-ignored) in the main working directory holds the server
  scripts, the token key patch, and `LiveProbeTests.swift` for querying the live PIR
  server from a Mac.

## Checking the filter

- On a phone: launch the app with `PHOSPHOR_PROBE_URLS` set to comma-separated URLs,
  e.g. `xcrun devicectl device process launch --device <id> --terminate-existing
  --console -e '{"PHOSPHOR_PROBE_URLS":"https://xvideos.com/"}' com.nestclaw.phosphor`.
  The app logs `NEURLFilter.verdict(for:)` for each: 3 = deny, 2 = allow. The phone
  must be unlocked.
- On the server: `LiveProbeTests.swift` goes into a clone of apple/pir-service-example
  under `Tests/PIRServiceTests/`; run with `PIR_SERVER`, `PIR_TOKEN`, `PIR_USECASE`,
  `PIR_KEYWORDS` set and `swift test --filter liveProbe`.
- Server requests: `/var/log/nginx/phosphor-pir.access.log`.

## Verify on a device

- [ ] The filter comes back after the token key change once the app is opened (see
      "Next session").
- [ ] Clean install, as a reviewer would do it: delete the app, install, enable
      filtering, open an adult site and bbc.co.uk in Safari.
- [ ] Restart after a list change when the app is left immediately. Switch Adult off,
      go straight to Safari, force-quit and reopen it: the site should load. Then the
      reverse. The background task that protects this was built but not yet tested.
- [ ] "Adult was off by default" was seen once. Find out on which phone and whether
      the app had been deleted first. If so, the app group container survives deletion
      and carries old list settings into a fresh install.
- [ ] Onboarding is skipped when the filter is already running.
- [ ] The paywall shows the monthly and yearly plans from App Store Connect.
- [x] Ads from subdomains are blocked: the probe denied six Google ad hosts, and
      bbc.co.uk showed no Google ads in a reopened Safari (2026-09-30).
- [x] Apple's onboarding test URL `www.apple.com/url-filter-test` is blocked
      (2026-09-30).
- [x] Switching a list on or off takes effect after Safari is reopened (2026-09-29).

## Build

- [ ] Parent-domain matching: `ad.doubleclick.net` loads although `doubleclick.net` is
      listed, because iOS matches exact hostnames. Needs
      `NEURLFilterManager.urlParsingConfiguration`, iOS 27 SDK only. With Xcode 27
      installed, add it behind an `#available(iOS 27, *)` check.
- [ ] Decide what to do with `FilterProbe`. Remove it or keep it out of release builds.
- [ ] Re-enabling the filter from the dashboard goes through the whole onboarding.
      A direct button would be better.
- [ ] Pause ends only when the app is next opened, because iOS gives the app no way to
      run at a set time. Consider a notification when the pause runs out.
- [ ] Commit the app redesign on top of `fix/url-filter` and open a pull request.
- [x] Hostname-level ads list (StevenBlack unified hosts) bundled, entries normalised
      without `www.`, `Tools/build-pir-database.py` keeps the server database in step.
      Coverage of 30 common ad and tracker hosts went from 3 to 26.

## Server

- [x] The PIR service keeps its Privacy Pass token key across restarts: patched with
      `--token-key-file` (`build/server-scripts/pir-token-key.patch`), key in
      `/opt/phosphor/token-key.pem`. Verified 2026-09-30. Reapply the patch if the
      service is ever rebuilt from upstream.
- [x] Database rebuilt 2026-09-30 from the bundled lists: 159,417 keywords, 4 shards.
      Rebuild with `Tools/build-pir-database.py` then
      `build/server-scripts/pir-update-database.sh` whenever the lists change.
- [ ] Evaluation keys are kept in memory and are lost when the service restarts.
      Phones re-upload them; check how long lookups fail after a restart.
- [ ] The service runs apple/pir-service-example `c4ee860` plus the token key patch,
      behind nginx (which provides the request log). Record the setup in the server
      notes (`/root/SERVER-MAP.md`).
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
- If the server refuses a phone's tokens, lookups fail open and the filter can stop.
  iOS does not restart it; the app does when it is opened.
- The filter extension may use 6 MB of memory at most, so the Bloom filter is built by
  the app.
- The Simulator cannot run the filter; it has no Network Extension service.
