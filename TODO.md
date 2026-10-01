# TODO

State as of 2026-10-01. URL filtering works on device (iPhone 15 Pro Max on
iOS 27.0, iPhone 11 Pro Max on iOS 26.6.1): adult sites, ad and tracker hosts, and
Apple's onboarding test URL are blocked. Xcode 27 (27A266a, iOS 27.0 SDK) is installed
and builds the app. On iOS 27 subdomains of listed domains are now blocked too.

## Next session: start here

1. Test the paywall and trial with local StoreKit (see Subscription below).
2. App Store Connect: change the prices (see App Store).
3. Commit the subscription gating, new prices and site copy (uncommitted on `main`).

## Where things are

- Everything up to the redesign and iOS 27 parent-domain matching is on `main` (pull
  request #3, merged 2026-10-01). `fix/url-filter` and `redesign` can be deleted.
- Launch posts for after approval are in `marketing/launch/` (git-ignored, local only).
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

- [x] `FilterRefresher.restartIfStopped` restarted a stopped filter on the iPhone 11
      (2026-10-01). Opening the app again during the minutes the filter takes to start
      restarted it each time and kept it down, so restarts now wait 10 minutes.
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
- [x] Onboarding is skipped when the filter is already running. It never was: the
      status reads `invalid` right after loading and `starting` for minutes after an
      update. Fixed 2026-10-01 to wait for the status and accept `starting`; verified on
      both phones.
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

## Subscription

Filtering requires Phosphor Premium (decided 2026-10-01): annual $12.99 (listed first, so
it is the default), monthly $1.99, 7-day free trial on both, no lifetime plan.

- `SubscriptionGate` switches the filter off when there is no subscription or trial and
  back on after a purchase. It runs when the app becomes active, after a purchase, and
  from a background app refresh task (`com.nestclaw.phosphor.subscription-check`) so it
  also catches people who never open the app.
- `SubscriptionReminders` (local notifications): 2 days before a trial ends, with the
  renewal price; 2 days before a cancelled subscription ends; "Protection paused" when it
  ends. Permission is asked right after a purchase.
- Setup's "Enable filtering" opens the paywall first. The dashboard shows "Protection
  paused" or "Filtering is off" with a button to the paywall.
- Dev builds: launch with `PHOSPHOR_ASSUME_SUBSCRIBED=1` to treat the app as subscribed
  (persists; `=0` turns it off). Both test phones have it on (2026-10-01). Release builds
  ignore it.
- Local StoreKit testing: the Xcode scheme uses `Phosphor/Resources/Phosphor.storekit`
  when run with ⌘R. Set Editor › Subscription Renewal Rate to "1 second = 1 day" to see
  a trial end in 7 seconds; Debug › StoreKit › Manage Transactions to expire or delete.
  Turn the debug override off first, or the gate never pauses.

- [x] Gate verified on the iPhone 11 (2026-10-01): with no subscription the filter
      paused and xvideos.com was allowed; with the override it resumed and blocked again.
- [x] Annual purchase with local StoreKit switched the filter back on (2026-10-01).
- [x] Refund with local StoreKit: on reopening, the app paused the filter and showed
      "Protection paused" (2026-10-01).
- [x] Buying again after the refund: StoreKit's `currentEntitlements` kept returning
      the refunded purchase, so the app stayed paused although the purchase succeeded.
      `SubscriptionManager.currentEntitlement()` now also checks `Transaction.latest(for:)`
      per plan; after that the Renew card went and the filter turned back on
      (2026-10-01). The paywall now closes only when access is really active.
- [x] Cancel (auto-renew off) and let the period run out: on reopening, filtering
      paused and the paywall came up (iPhone 15, "1 Renewal Every 30 Seconds",
      2026-10-01). The earlier "nothing happens" was the app running on the iPhone 11,
      which has the debug override on.
- [x] Reminders with local StoreKit (2026-10-01): StoreKit marks the trial
      (offer introductory, free trial), permission was granted, the trial reminder was
      scheduled 2/7 of the period before the end and "Protection paused" was sent
      when the filter paused. Nothing popped up because the iPhone 15 had a Focus mode
      on (iOS logged "suppressed, delay delivery"); they go to Notification Center.
      Subscription and reminder messages are logged at notice level so they can be
      read from the phone's log over USB (`pymobiledevice3 syslog collect`, then
      `/usr/bin/log show --archive ... --predicate 'subsystem == "com.nestclaw.phosphor"'`).
- [ ] Check FilterStartingCard on a device: the steps and timer while starting, and the
      "Restart filter" help after 10 minutes.
- [ ] After a reinstall from Xcode (2026-10-01) iOS tried to start the filter before it
      could find the extension ("identities [] / no matching extension found"), the
      start failed and iOS did not retry; the filter stayed `stopped` until the app was
      opened. Check whether an App Store or TestFlight update does the same to a real
      user's filter.
- [ ] Custom paywall (replaced SubscriptionStoreView 2026-10-01 for layout and the
      duplicate policy links): test a purchase, Restore, and a user not eligible for
      the trial ("Subscribe" and no trial line).
- [ ] Background refresh actually pauses a lapsed filter without the app being opened.
      Hard to force; Xcode's Debug › Simulate Background Fetch helps.
- [ ] The dashboard has no block counts: nothing in the app records them and iOS does
      not report blocks to apps (iOS 27's `reportEndpoint` sends reports to a server).
      The "Real-time blocking dashboard" claim was removed from the paywall, site and
      README. Decide what the dashboard should show instead of the empty block stats.

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
- [ ] Change the prices: yearly (`com.nestclaw.phosphor.yearly`) $12.99, monthly
      (`com.nestclaw.phosphor.monthly`) $1.99, each with a 1-week free trial as the
      introductory offer. Check the App Store description and promotional text for old
      prices.
- [ ] App Review note: filtering requires a subscription; start the free trial with
      the sandbox account, then allow the filter when iOS asks.
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
