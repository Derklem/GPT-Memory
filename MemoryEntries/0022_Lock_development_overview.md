# Lock development overview

_Created: 2025-11-07T23:19:24+00:00_

**user:**

Only using words, not using any code except a section where you can produce your folder file tree, can you explain to me all of the things I would need (files folders and functions) in order to develop a mobile application on Android.  The application is intended to be installed on a child's device by a parent. That parent would install the application do an initial setup where they would create a pin select the applications they want blocked, allow accessibility, and then have their child's device subject to time limits determined by the parent. In essence the device should be a brick except for the phone and our application or any application not selected. For the purpose of your response I want you to just focus on the lock. We have most of the application built already the lock was working in the beginning but as we've developed more it is now not working no matter what we do. I'm attempting to start at the beginning with you here to have you develop a working lock in a verbal description with references so that I can share that with you without having interference or overlay from sharing code back and forth.

**assistant:**

Got it. Let’s rebuild the lock from first principles and specify exactly what must exist (files, folders, and functions), how each part interacts, which user-granted powers it relies on, and what failure modes to harden against. I’ll also call out where Android’s modern rules draw the line (so we don’t fight physics).

---

# What we’re building (scope)

A resilient “child lock” that:

- Lets the parent set a PIN and choose allowed apps.
- Keeps the device effectively bricked except for the dialer, emergency flows, the parent app, and any explicitly allowed apps.
- Survives process death and reboot.
- Works on consumer devices **without** device-owner privileges (so: no true kiosk “lock task mode,” which requires Device Owner). For enterprise-style *true* kiosk, see “Two legal paths” below. citeturn0search3

---

# Two legal paths (pick one at build time)

1) **Consumer/Play-eligible path (no Device Owner)**  
   Techniques: custom launcher (HOME), AccessibilityService monitoring, Usage Access, overlay blocker, a foreground service, and a strict allow-list UI. This is how mainstream parental-control apps do it—**with prominent disclosure** and user-granted permissions. citeturn0search12turn1search12

2) **Device-owner kiosk path (enterprise or provisioning flow only)**  
   If you can provision the child device as **Device Owner**, you can use **Lock Task Mode** to hard-lock to a set of packages. It’s rock-solid, but requires out-of-band provisioning (QR/Zero-touch/adb dpm set-device-owner) and is generally not Play-store consumer-grade. citeturn0search3turn0search11

Given your use case, I’ll lay out the **consumer path** in detail and note where kiosk differs.

---

# Minimum capabilities the lock depends on (consumer path)

- **Default HOME (custom launcher)** to present only allowed apps and intercept “home” navigation. citeturn0search2turn0search15
- **AccessibilityService** to observe app/Activity changes in real time and react when the child enters a blocked app (listen for `TYPE_WINDOW_STATE_CHANGED` et al.). citeturn0search0turn0search12
- **Usage Access** to verify current foreground app (for redundancy and analytics) via `UsageStatsManager` / `UsageEvents`. Parents must grant this in Settings (“Apps with usage access”). citeturn0search1turn1search12turn1search18
- **Overlay (“Display over other apps”)** for a full-screen interstitial shield when a blocked app is detected. (We must handle overlay restrictions around permissions screens gracefully.) citeturn0news48
- **Foreground service** for persistent process priority and a visible notification (Android 13+ requires runtime POST_NOTIFICATIONS permission; Android 14+ requires declaring the service **type**). citeturn1search11turn1search2
- **BOOT_COMPLETED receiver** to re-arm the lock on reboot (delivery occurs after first unlock on modern Android). citeturn1search1turn1search7

> Note: **Lock Task Mode** (single-/multi-app kiosk) is only allowed if you are **Device Owner**. If you can be DO, you can skip the overlay+accessibility combo and use system kiosk APIs, whitelisting the dialer and your app. citeturn0search3

---

# Folder & file tree (single-module app variant)

```text
app/
  src/
    main/
      AndroidManifest.xml

      java|kotlin/com/yourco/childlock/
        MainLauncherActivity/                 # Your custom HOME screen (allowed apps only)
        ParentSetupActivity/                  # Onboarding: PIN, permissions, allow-list
        PinGateActivity/                      # Fullscreen PIN gate for overrides
        OverlayBlockActivity/                 # Translucent/opaque blocker with taskOnHome behavior
        SettingsDisclosureActivity/           # Required transparency re: Accessibility/overlay usage

        service/
          AppGuardAccessibilityService/       # Watches window state; triggers block when needed
          ForegroundGuardService/             # Long-lived orchestrator; holds notification
          UsageWatchdog/                      # Polls UsageEvents as a backup signal path
          KeepAliveJob/                       # WorkManager/JobService to re-arm guard if killed

        launcher/
          AllowedAppAdapter/                  # Recycler adapter for allowed apps grid
          AppResolver/                        # Queries and resolves launchable activities/packages

        lock/
          LockStateController/                # “Single source of truth” for lock state machine
          BlockDecisionEngine/                # Decides if current top app is allowed/blocked
          OverlayController/                  # Shows/hides OverlayBlockActivity safely
          RecentsInterceptor/                 # Strategy to collapse recents / bounce back to HOME
          DialerExemptions/                   # Ensures emergency and phone apps always allowed

        time/
          TimeQuotaManager/                   # Enforces daily/weekly time budgets
          TimeWindowScheduler/                # Enforces schedules (bedtime/school hours)
          AlarmHooks/                         # AlarmManager hooks for windows/quota ticks

        data/
          PinVault/                           # Stores parent PIN using EncryptedSharedPreferences
          AllowedListStore/                   # Persists allow-list packages
          PolicyStore/                        # Stores toggles: overlay on/off, aggressive mode, etc.
          ConsentStore/                       # Records disclosures and parent consent timestamps

        permissions/
          PermissionNavigator/                # Deep-links to system settings (usage access, overlay)
          BatteryOptNavigator/                # Guides “ignore battery optimizations” flow
          AccessibilityNavigator/             # Routes to enable AccessibilityService

        receivers/
          BootCompletedReceiver/              # Re-arms services after reboot
          PackageChangeReceiver/              # Detects new installs/updates; auto-re-evaluate
          ScreenOnOffReceiver/                # Optional: adjust guard sensitivity on screen on/off

        util/
          ForegroundAppDetector/              # Merges Accessibility + UsageEvents signals
          NotificationHelper/                 # Builds persistent notification (Android 13+ aware)
          PhoneAppResolver/                   # Finds dialer/emergency packages across OEMs
          SafeIntentUtils/                    # Prevents task hijacking via malicious intents
          Logger/                             # Structured logging with ring buffer

      res/
        layout/                               # Minimal layouts for launcher, overlays, PIN, setup
        xml/
          accessibility_service_config.xml    # Capabilities & events subscribed by AccessibilityService
          backup_rules.xml
        values/
          strings.xml                         # Clear disclosures, parental copy
          styles.xml
        drawable/                             # Branding for notifications & overlays (light/dark)

      proguard-rules.pro
```

(We’ll keep it single-module to avoid build churn while you debug the lock. Multi-module is fine later.)

---

# What each piece does (and why it matters)

## Launcher: `MainLauncherActivity` (+ `AppResolver`, `AllowedAppAdapter`)
- Becomes the **default HOME**. This is the child’s “world.” It shows only **allowed apps** and your “Parent” button (PIN-gated).
- It handles **HOME** presses and safely routes back from blocked contexts.  
  *Reference:* Declaring HOME category makes your Activity eligible as a launcher. citeturn0search2turn0search15

## Accessibility: `AppGuardAccessibilityService`
- Listens to **`AccessibilityEvent`** (notably `TYPE_WINDOW_STATE_CHANGED`) to detect when a blocked app/activity becomes foreground. On signal, it consults `BlockDecisionEngine` and either lets it through or raises the blocker.  
  *References:* Accessibility event stream & service behavior. citeturn0search0turn0search12

## Foreground signal redundancy: `UsageWatchdog` + `ForegroundAppDetector`
- Parents grant **Usage Access**; `UsageWatchdog` queries **`UsageStatsManager`** (`UsageEvents`) at a modest cadence as a **backup** to Accessibility (OEMs sometimes throttle Accessibility or miss edge cases).  
  *References:* API + user-grant requirement. citeturn0search1turn1search12turn1search18

## Overlay blocker: `OverlayBlockActivity` + `OverlayController`
- Presents a **full-screen interstitial** (“This app is blocked”) when a disallowed app takes focus. It should be **task-aligned** with your task stack and careful around permission screens where overlays are restricted (handle the “screen overlay detected” experience with instructions).  
  *Reference:* Overlay UX implications and restrictions. citeturn0news48

## Orchestration & resilience: `ForegroundGuardService`
- Starts after setup, runs as a **foreground service** with a persistent notification and self-healing hooks (WorkManager). On Android 14+, you **must** declare a foreground service **type**; on Android 13+ you need POST_NOTIFICATIONS at runtime.  
  *References:* FGS overview and type requirements. citeturn1search11turn1search2

## Reboot hardening: `BootCompletedReceiver`
- Receives **BOOT_COMPLETED** and re-arms the guard. On recent Android, delivery happens **after first unlock**, so also hook `ACTION_USER_UNLOCKED` if needed.  
  *References:* Broadcasts and modern boot timing nuances. citeturn1search1turn1search7

## Policy & storage: `PinVault`, `AllowedListStore`, `PolicyStore`
- `PinVault`: store PIN via **EncryptedSharedPreferences** (or Keystore-backed).  
- `AllowedListStore`: package names + activity exceptions (e.g., deep links that are okay).  
- `PolicyStore`: toggles like “aggressive overlay,” “block recents,” “respect picture-in-picture,” etc.

## Decision logic: `LockStateController` + `BlockDecisionEngine`
- **State machine** driving the lock (LOCKED, TEMP_UNLOCK, TIME_EXPIRED, SETUP, ERROR).
- Given current top package/activity, decide: **Allowed →** do nothing; **Blocked →** show overlay & bounce HOME.

## Time limits (for later in your flow): `TimeQuotaManager`, `TimeWindowScheduler`
- Quotas (minutes/day per app or global), schedules (bedtime/school hours).  
- Emit “time expired” to `LockStateController`, then treat *everything but exceptions* as blocked.

## Safety exceptions: `DialerExemptions`, `PhoneAppResolver`
- Always allow **Emergency** and standard **Dialer** UX (including call overlays), across OEM variants.

## Parent UX: `ParentSetupActivity`, `PinGateActivity`, `SettingsDisclosureActivity`
- Setup collects PIN → requests Usage Access, Accessibility, Overlay → chooses allowed apps.  
- Disclosures must clearly explain use of Accessibility and overlays for parental control purposes (Play policy).  
- `PinGateActivity` is the secure override (“5 minutes more” etc.).

---

# Required user-granted powers (and where you send them)

- **Make our launcher default HOME** (system prompt appears when launching HOME). citeturn0search2  
- **Enable Accessibility** for our service (deep-link to the specific accessibility settings entry). citeturn0search0  
- **Grant Usage Access** (send to `Settings.ACTION_USAGE_ACCESS_SETTINGS`). citeturn1search12  
- **Allow “Display over other apps”** for overlay shields (device OEM text varies). citeturn0news48  
- **Allow notifications** (Android 13+) so the foreground service’s notification is visible. citeturn1search11  
- **(Optional) Ignore battery optimizations** to reduce background kills on aggressive OEMs.

---

# Core enforcement flows

## 1) Launch interception (the “funnel”)
- Child presses HOME → **our launcher** shows only allowed apps.  
- If child tries recent-apps or deep links into a blocked app, the **AccessibilityService** sees the **window change** and triggers the decision engine. citeturn0search0

## 2) Block reaction (the “shield”)
- If **blocked**, `OverlayController` presents `OverlayBlockActivity` on top, then **navigates HOME** to our launcher (prevents interactive leakage behind the overlay).  
- Optionally animate a quick fade to prevent flicker.

## 3) Foreground watchdog (the “net”)
- `UsageWatchdog` periodically verifies the foreground package; if we ever miss an accessibility event, it **retro-blocks** within ~100–300 ms based on recent `UsageEvents`. citeturn0search1

## 4) Self-healing (the “heartbeat”)
- `ForegroundGuardService` stays alive; `KeepAliveJob` restarts guards when killed.  
- `BootCompletedReceiver` re-arms after reboot/unlock. citeturn1search1

---

# Known constraints & honest limits

- **True kiosk** (status bar suppressed, keys limited, no recents) requires **Device Owner** and **Lock Task Mode**. If you can provision as DO, use lock-task APIs and whitelist allowed apps—simpler and stronger than overlay/Accessibility. citeturn0search3
- **Overlays** can’t sit over some system permission screens; guide the user through those temporarily without the overlay, then restore. citeturn0news48
- **Foreground services** must show a **visible notification**, and new Android versions limit what can be started from boot receivers; follow the service-type rules. citeturn1search11turn1search2turn1search16

---

# Failure modes you must harden against

- **Accessibility disabled** → detect and prompt parent immediately; show degraded lock (launcher-only) until restored. citeturn0search0
- **Usage access revoked** → continue using Accessibility path; prompt to re-enable. citeturn1search12
- **Overlay permission revoked** → fall back to quick HOME bounce + launcher-only; prompt to re-enable. citeturn0news48
- **Process kills / Doze** → rely on the foreground service, WorkManager re-arm, and boot receivers. citeturn1search11turn1search1
- **Reboot** → BOOT_COMPLETED + USER_UNLOCKED flow re-starts guard. citeturn1search1turn1search7
- **Emergency calls** → never block; ensure dialer & emergency UI are whitelisted (`DialerExemptions`).

---

# Test matrix (minimum)

1) **Stock Pixel** (latest Android) with: a) all permissions granted, b) each permission toggled off.  
2) **Samsung** (aggressive background policy) for process-kill resilience.  
3) **Edge cases**: PIP media apps, permission dialogs, in-call screen, notification shade drag, split-screen attempts.  
4) **Reboots**: locked before reboot → remains locked after unlock.  
5) **Time windows**: crossing bedtime boundaries while a game is foreground.

---

# Where “references” land in this design

- Accessibility events and service duties (what we rely on to detect foreground activity). citeturn0search0turn0search12  
- UsageStats/UsageEvents and the “Usage Access” grant. citeturn0search1turn1search12turn1search18  
- Launcher HOME intent categories and intent-filter behavior. citeturn0search2turn0search15  
- Lock task mode (for the Device-Owner variant). citeturn0search3  
- Overlay behavior and user impact. citeturn0news48  
- Foreground service requirements on modern Android. citeturn1search11turn1search2  
- Boot receivers and modern delivery timing. citeturn1search1turn1search7

---

# Why your current lock “stopped working” (likely culprits)

From experience with teams that had a working lock which later degraded as the app grew:

- **The launcher stopped being the default HOME** (manifest or category changes), so HOME can escape you. citeturn0search15
- **AccessibilityService lost a capability** in its XML (events mask, feedbackType), so you’re missing `TYPE_WINDOW_STATE_CHANGED`. citeturn0search0
- **Usage Access was revoked** by the user/system; your backup detector went blind. citeturn1search12
- **Overlay permission revoked** → your shield never appears. citeturn0news48
- **Foreground service not correctly declared (type on Android 14+)** → the OS throttles/kills the guard. citeturn1search2
- **BOOT_COMPLETED assumptions** broken (service start limits on modern Android; only after unlock). citeturn1search16turn1search7

---

# If you *can* be Device Owner (optional kiosk notes)

- Provision device as **Device Owner** → enable **Lock Task Mode** → whitelist allowed apps (dialer, your app).  
- Greatly reduces the need for overlay/Accessibility.  
- This is the enterprise way; see the official guide for DPCs. citeturn0search3

---

If you want, I can map this exactly onto your existing package names and reconcile it with your current modules; for now this is the clean, interference-free blueprint of what must exist and why it works under today’s Android rules.

**user:**

I just went to you and had you tell you what you're doing. LOL here it is. Here’s a tight, copy-pasteable briefing for the other instance:


---

What we built (current architecture)

Path: Consumer / Play-eligible (no Device Owner / no LockTask).

Key pieces

app-child module (UI + device hooks)

MainActivity – starts/ends a timed session and launches settings screens.

BlocklistActivity – manages blocked / allowed packages via Prefs.

PinUnlockActivity – full-screen gate to end a session using a parent PIN.

ForegroundGuardService – foreground service to keep the protection “hot” during a session (notification + persistence).

LockScreenReceiver – receives a “blocked app” broadcast and opens PinUnlockActivity.


core-lock module (headless lock logic)

GuardAccessibilityService – watches app switches and enforces the block during a session.

LockGate / LockController / LockState – pure logic: “Should this package be blocked right now?”

BootReceiver & SessionBroadcastReceiver – restore/reflect state.

Prefs (in com.timeout.common) – single store for session end time + block/allow lists.



Flow (intended)

1. Parent starts session → Prefs.setEnd(..) + start ForegroundGuardService.


2. GuardAccessibilityService sees app switches; if package ∈ blocked and now < endAt, it blocks by bouncing user and/or launching the PIN gate.


3. Parent enters PIN → PinUnlockActivity verifies via PinManager, calls Prefs.setEnd(0) and stops ForegroundGuardService.




---

What works now

UI: Session duration picker; quick-pick chips; Change PIN dialog; Blocklist UI.

System dialogs: Accessibility settings launcher works; Blocklist UI works.

Accessibility service: Can be enabled and is running.



---

What’s breaking (compile-time)

1. Unresolved resource in ForegroundGuardService

R.drawable.ic_timeout doesn’t exist → compilation error.

Fix: use a built-in icon for now (e.g., android.R.drawable.stat_sys_warning) or add a small vector in app-child/src/main/res/drawable/ic_timeout.xml.



2. Cross-module references from core-lock to app-child

GuardAccessibilityService in core-lock referenced classes in app-child (com.timeout.child.*, PinUnlockHandler, LockGate mismatch), causing “Unresolved reference” when core-lock compiles.

Principle: core-lock must not depend on app-child UI. It should signal via a broadcast intent, and LockScreenReceiver (in app-child) opens PinUnlockActivity.



3. Manifest merge blew up earlier

Caused by a malformed manifest tag and mismatched service class names. We corrected the structure; keep the service names consistent with the packages that actually contain them.





---

What’s breaking (runtime / behavior)

“Lock doesn’t engage.” Likely because the Accessibility path is not reaching the UI gate. Two common causes:

1. GuardAccessibilityService tries to call app-child classes directly (failing silently or never firing).
Fix: From core-lock, send sendBroadcast(Intent("com.timeout.BLOCKED_APP").putExtra("pkg", …)).
LockScreenReceiver (app-child) handles this and starts PinUnlockActivity.


2. LockGate logic not reading the same Prefs end-time / lists used by the UI.
Fix: Ensure both modules use the same Prefs API and keys. The decision should be strictly:
now < endAt && pkg in blocked && pkg !in whitelist.





---

Minimal, surgical fixes to get us green

1. Fix the icon compile error (now).
In ForegroundGuardService.kt, change the small icon line to:

.setSmallIcon(android.R.drawable.stat_sys_warning)

(or drop in a proper vector ic_timeout.xml and use that.)


2. Decouple core-lock → app-child.

In GuardAccessibilityService (core-lock): remove any imports/usages of com.timeout.child.*.

When a block is needed, broadcast:

sendBroadcast(
  Intent("com.timeout.BLOCKED_APP")
    .putExtra("blocked_package", pkg)
)

In LockScreenReceiver (app-child): start PinUnlockActivity on that action (you already have this receiver; keep exported=true).



3. Make the service names consistent.

We are using com.timeout.child.ForegroundGuardService (lives in app-child).

In PinUnlockActivity, import/stop that class:

import com.timeout.child.ForegroundGuardService

and call stopService(Intent(this, ForegroundGuardService::class.java)).



4. Confirm a single source of truth for session + lists.

Both modules call the same Prefs.setEnd / getEnd, getBlocked / getWhitelist.



5. Device enablement checklist (for consumer path).

Accessibility: ON for TimeOut.

Usage Access: ON (if your LockGate checks usage / foreground app through UsageStats).

Overlay/Draw over other apps: ON if you show any overlays.

Battery: Exempt from battery optimizations for reliability.

Foreground service: We start it on session begin.





---

If you want, I can also give you the exact 10–15 lines to drop into GuardAccessibilityService to emit the broadcast, plus the LockScreenReceiver snippet that opens PinUnlockActivity.

**assistant:**

Perfect. Your briefing is solid. Let’s convert it into a crisp, code-free implementation plan that (a) gets you compiling, (b) restores the lock path, and (c) hardens the seams so it doesn’t regress again.

---

# Outcome you want (single sentence)
When a session is active and the child opens a blocked package, the **headless lock logic** (core-lock) detects it and **signals** the **UI module** (app-child), which immediately raises the PIN gate and returns the device to your launcher/home—until the parent ends the session with a valid PIN.

---

# The minimal contracts (do these first)

1) **One broadcast action string** (used by both modules)  
   - Name: `com.timeout.BLOCKED_APP`  
   - Extras required:  
     - `blocked_package` → the package name that triggered the block  
     - `reason` → short enum-ish string like `time_active`, `policy_blocked`, `unknown` (helpful for telemetry)

2) **Single source of truth for session state**  
   - Keys shared by both modules (use exactly the same names):  
     - `session_end_epoch_ms`  
     - `blocked_packages` (set)  
     - `whitelisted_packages` (set)  
     - `pin_salt` / `pin_hash` (PinVault)  
   - Read/write only through your common Prefs API (in `com.timeout.common`). No duplicate getters in either module.

3) **Accessibility event scope (high level, not code)**  
   - Service must subscribe to **window state changes** and **window content changes**.  
   - Foreground resolution order: Accessibility event → (fallback) recent `UsageEvents`.  
   - On any ambiguity, default to **blocked** during an active session (fail-closed).

4) **UI module owns all UI**  
   - **core-lock never starts Activities**. It only **broadcasts** `com.timeout.BLOCKED_APP`.  
   - **app-child** receives that broadcast and is the **only** place that starts `PinUnlockActivity`.

---

# Folder/file tree (authoritative, current shape)

```text
app/
  src/
    main/
      AndroidManifest.xml
      java|kotlin/com/timeout/child/
        MainActivity/
        BlocklistActivity/
        PinUnlockActivity/
        LockScreenReceiver/           # handles com.timeout.BLOCKED_APP and opens PinUnlockActivity
        ForegroundGuardService/       # persistent notification + keep-hot orchestration
        ... (adapters, setup screens)
      res/
        drawable/                     # ensure ic_timeout.xml exists OR use a system icon temporarily
        layout/
        xml/
        values/
core-lock/
  src/
    main/
      AndroidManifest.xml
      java|kotlin/com/timeout/lock/
        GuardAccessibilityService/    # detects foreground app changes; decides block/allow
        LockController/               # reads Prefs; exposes isSessionActive(), isBlocked(pkg)
        LockGate/                     # pure decision, no Android UI references
        LockState/                    # small enum/state holder
        BootReceiver/
        SessionBroadcastReceiver/
        UsageWatchdog/                # optional fallback using UsageEvents
common/
  src/
    main/
      java|kotlin/com/timeout/common/
        Prefs/                        # single API used by both modules for all policy/session data
        PinVault/                     # hashed, salted PIN storage
        Logging/
```

---

# Surgical fixes (no code, just exact actions)

## A) Compile break: missing small icon
- In `ForegroundGuardService` you reference `R.drawable.ic_timeout`.  
- Do **one** of the following (pick now, swap later):  
  - Drop a tiny vector named **`ic_timeout.xml`** into `app-child/res/drawable/`.  
  - Or temporarily change the service notification to use a **system small icon** you know exists.
- Rebuild and confirm the **compile** is green before moving on.

## B) Cross-module dependency violation (core-lock → app-child)
- Move or delete **every** import from `com.timeout.child.*` inside **core-lock**.  
- Where `GuardAccessibilityService` previously reached into UI, replace that behavior with:  
  - **Emit the broadcast** `com.timeout.BLOCKED_APP` with the two extras above.  
- In **app-child**, ensure `LockScreenReceiver` is **enabled and exported**, listens for `com.timeout.BLOCKED_APP`, and **starts `PinUnlockActivity`**.  
- Confirm **module dependencies** are one-way:  
  - `app-child` **may** depend on `core-lock` and `common`.  
  - `core-lock` depends only on `common`.  
  - `core-lock` **must not** depend on `app-child`.

## C) Manifest alignment (names must match classes on disk)
- In **core-lock manifest**: declare `GuardAccessibilityService` with its exact package and the correct `accessibilityservice` XML reference; add `BootReceiver` and (if used) `SessionBroadcastReceiver`.  
- In **app-child manifest**: declare `LockScreenReceiver`, `PinUnlockActivity`, and `ForegroundGuardService` with their exact packages.  
- Verify the **AccessibilityService XML** (in `res/xml` of the **core-lock** module) includes the right event types and capabilities; the manifest must reference **that** file.

## D) Foreground service and notifications (modern Android rules)
- Ensure `ForegroundGuardService` declares a **foreground service type** that matches what it actually does (e.g., “mediaProjection”, “dataSync”, etc.—pick the honest one you’re using).  
- On Android 13+, your first run path must **request posting notifications**; otherwise the FGS notification may be suppressed and the OS will be eager to kill you.  
- Verify your **notification channel** exists before starting the FGS.

## E) One-time setup checklist (for the parent flow)
- **Accessibility ON** for your service.  
- **Usage Access ON** if you rely on `UsageWatchdog` fallback or any stats.  
- **Battery optimization exemption** requested (present the system screen; user must accept).  
- **Notifications allowed** (Android 13+).  
- **Overlay permission** only if your UX uses overlays (your current flow uses a full-screen Activity, which is safer).

---

# Lock engagement, end-to-end (what must happen in order)

1) **Session begins**  
   - `Prefs.session_end_epoch_ms` set to a time in the future.  
   - `ForegroundGuardService` started and remains **foreground** with a visible notification.

2) **Detection happens**  
   - `GuardAccessibilityService` is **enabled** by the OS.  
   - On any **window state change**, resolve the **current top package**; if uncertain, consult `UsageWatchdog`’s recent event.  
   - Ask `LockGate` → if `now < session_end_epoch_ms` **and** package ∈ blocked **and** package ∉ whitelist → **blocked**.

3) **Signal crosses module boundary**  
   - **core-lock** broadcasts `com.timeout.BLOCKED_APP` with extras.  
   - **app-child**’s `LockScreenReceiver` receives it and immediately starts `PinUnlockActivity` (task-safe flags, singleTop pattern, etc. in your code).

4) **UI enforces**  
   - `PinUnlockActivity` is full-screen, immersive, not dismissible via back.  
   - Valid PIN → `Prefs.session_end_epoch_ms = 0` and **stop** `ForegroundGuardService`.  
   - Invalid PIN → remain on gate.  
   - On backgrounding, the Activity should re-assert if the session is still active.

---

# Regression traps and how to guard them (no code, just rules)

- **“Silent escape” via recents**: ensure the gate returns the user to your launcher/home after dismissal paths; your receiver should also collapse into home after unlock failure.  
- **Service killed**: rely on the **foreground service**, plus a periodic **WorkManager** ping that verifies session state and revives the guard if required.  
- **Permission drift**: on your `MainActivity` and settings screens, **live-check** Accessibility and Usage Access; if either is off while a session is active, show a non-dismissable prompt to restore.  
- **Mismatched keys**: write a tiny internal “prefs integrity test” screen that reads and prints: end time, current time, blocked size, whitelist size, and “wouldBlock(package)” for a typed package. (Human-readable only; no code here—just add it to your app for your own validation.)

---

# Verification plan (five quick runs)

1) **Compile-only**: with the icon fix in place, both modules assemble and the manifest merge is clean.  
2) **Cold start**: grant permissions, start a 5-minute session, open a known blocked app → **PIN gate** appears within a blink.  
3) **Session end**: enter correct PIN → session ends, guard service stops, blocked app opens normally.  
4) **Kill the app**: swipe away your process while session is active → the **broadcast path** still triggers the gate when a blocked app comes forward (FGS + Accessibility still active).  
5) **Reboot**: after reboot and first unlock, the **BootReceiver** -> guard resuming path restores enforcement if the previous session end time is still in the future.

---

# Likely root cause of your “it used to work” failure (mapped to your notes)

- The **UI reach-through** from `core-lock` into `app-child` created brittle, cross-module coupling. As refactors landed, class/package names drifted, breaking the invocation path; the service kept running but the **gate was never launched**.  
- The **missing small icon** then blocked builds, hiding the deeper wiring issue.  
- Once you enforce the **broadcast contract** and align manifests, the lock path becomes simple and inspectable (detect → decide → broadcast → UI handles).

---

# Hand-off notes for the other instance
- You already have all the code you need; just re-establish the **contracts** above and remove the cross-module imports.  
- If you choose to add overlays later, do it in **app-child** only; `core-lock` should remain headless.  
- If you later provision **Device Owner**, you can replace the broadcast+gate with **LockTask** flows—but keep the broadcast in place as a diagnostic channel; it’s invaluable.

---

If you want me to, I can walk through your current manifests and class names line-by-line (staying verbal) and point to the exact places to rename, move, or delete so you can apply the fixes in under an hour.

