# TODO

State as of 2026-10-01. URL filtering works on device (iPhone 15 Pro Max on
iOS 27.0, iPhone 11 Pro Max on iOS 26.6.1): adult sites, ad and tracker hosts, and
Apple's onboarding test URL are blocked. Xcode 27 (27A266a, iOS 27.0 SDK) is installed
and builds the app. On iOS 27 subdomains of listed domains are now blocked too.

## Next session: start here

1. Review and merge the pull request from `redesign` into `main`.
2. App Store items below; most are in App Store Connect.

## Where things are

- Branch `redesign` holds everything: the filter fixes from `fix/url-filter`, `main`
  merged in, the app redesign, and iOS 27 parent-domain matching. Pull request to
  `main` opened 2026-10-01.
- `fix/url-filter` holds the fixes alone (plus the merge of `main`) and can be deleted
  once the pull request is merged.
- `build/server-scripts/` (git-ignored) holds the server scripts, the token key patch,
  and `LiveProbeTests.swift` for querying the live PIR server from a Mac.
- `build/pmd` (git-ignored) is a venv with `pymobiledevice3` for reading device logs
  over USB.

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

- [ ] The filter comes back after the token key change once the app is opened. On the
      iPhone 15 it did (2026-09-30), but through the parsing configuration save, not
      `FilterRefresher.restartIfStopped`: the status read `invalid`, not `stopped`.
      The iPhone 11 reached `running` about 6 minutes after a new build was installed
      (2026-10-01), so `restartIfStopped` is still untested on both phones.
- [x] Clean install, as a reviewer would do it: delete the app, install, enable
      filtering, open an adult site and bbc.co.uk in Safari. Done on both phones
      2026-10-01: fresh import of all five lists (159,416 prefilter
      entries, Adult on), setup reached `running`, iOS 27 setup saved
      `ParsingEnumerateDomainHierarchy = YES`, and the probe denied listed sites, made-up
      subdomains and the onboarding test URL while allowing bbc.co.uk and apple.com.
      Safari, not force-quit first, blocked xvideos.com and loaded bbc.co.uk on both.
- [ ] Restart after a list change when the app is left immediately. Switch Adult off,
      go straight to Safari, force-quit and reopen it: the site should load. Then the
      reverse. The background task that protects this was built but not yet tested.
- [x] "Adult was off by default": not reproduced. After deleting the app on both phones
      (2026-10-01) the app group was empty and every list, Adult included, was imported
      switched on.
- [ ] Onboarding is skipped when the filter is already running.
- [ ] The paywall shows the monthly and yearly plans from App Store Connect.
- [x] Parent-domain matching on iOS 27.0 (2026-09-30): the probe denied made-up
      subdomains of listed domains (`phosphortest.doubleclick.net`,
      `phosphortest.xvideos.com`, `a.b.phosphortest.pornhub.com/video/1?x=2`) and
      allowed `phosphortest.bbc.co.uk`. Before the change `ad.doubleclick.net` was allowed.
- [x] Ads from subdomains are blocked: the probe denied six Google ad hosts, and
      bbc.co.uk showed no Google ads in a reopened Safari (2026-09-30).
- [x] Apple's onboarding test URL `www.apple.com/url-filter-test` is blocked
      (2026-09-30).
- [x] Switching a list on or off takes effect after Safari is reopened (2026-09-29).

## Build

- [x] Parent-domain matching (`FilterParsing`): on iOS 27 the app sets
      `urlParsingConfiguration` to Apple's defaults when the filter is set up and, for
      existing installs, when the app becomes active. A configuration saved by the iOS 26
      SDK build had `ParsingEnumerateDomainHierarchy = NO`, so iOS 27 matched exact
      hosts only. iOS 26.6.1 walks parent domains without it (probe on the iPhone 11,
      2026-10-01: made-up subdomains of doubleclick.net, xvideos.com, pornhub.com and
      googlesyndication.com denied, of bbc.co.uk and apple.com allowed).
- [ ] Decide what to do with `FilterProbe`. Remove it or keep it out of release builds.
- [ ] Re-enabling the filter from the dashboard goes through the whole onboarding.
      A direct button would be better.
- [ ] Pause ends only when the app is next opened, because iOS gives the app no way to
      run at a set time. Consider a notification when the pause runs out.
- [x] Commit the app redesign on top of `fix/url-filter` and open a pull request
      (2026-10-01, branch `redesign`).
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
      Safari has to be reopened after a list is changed. Not needed after first setup:
      on a clean install Safari blocked at once without being reopened (2026-10-01).

## Known behaviour, not bugs

- A running app keeps the filter it connected with. After a list change, other apps
  pick up the new filter when they are next opened.
- After the parsing configuration is first saved on an existing install, the filter
  took about five minutes to reach `running` again (fresh `/issue` and `/config` on the
  server). Lookups fail open meanwhile. This happens once per install.
- Right after an install or a restart, iOS can fail to find the extension for a few
  seconds. It succeeds on a later retry.
- The PIR auth token must be valid base64. With anything else iOS sends requests
  without a Privacy Pass token and the filter never starts, with no error naming the token.
- If the server refuses a phone's tokens, lookups fail open and the filter can stop.
  iOS does not restart it; the app does when it is opened.
- The filter extension may use 6 MB of memory at most, so the Bloom filter is built by
  the app.
- The Simulator cannot run the filter; it has no Network Extension service.
