# Shipping to TestFlight

How this app gets to TestFlight, and what to repeat for the next project.
Written against Xcode 26.6, team `5XQK9539QT`.

## One-time, per app (App Store Connect)

1. **Register the App ID / app record** at
   [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → My Apps → **+** →
   New App. Bundle ID must match `PRODUCT_BUNDLE_IDENTIFIER` exactly
   (`com.printernizer.ios`). Pick a name, primary language, and any SKU string.
2. **Distribution certificate** — you do not need to create one by hand. With
   `CODE_SIGN_STYLE = Automatic` and your Apple ID signed in under
   Xcode → Settings → Accounts (Admin or App Manager role), Xcode mints the
   Apple Distribution certificate and provisioning profile during the first archive.

## One-time, per app (project settings)

These are the things that silently break an upload or a tester's first launch.

### App icon

The asset catalog needs a real 1024×1024 PNG **with no alpha channel** — transparency
is an automatic rejection at upload. `AppIcon.appiconset/Contents.json` must name it:

```json
{ "filename": "AppIcon-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024" }
```

Verify with `sips -g pixelWidth -g hasAlpha <file>` → expect `1024` and `hasAlpha: no`.

> The icon currently committed here is a generated placeholder (nozzle over printed
> layers). Fine for internal testing; replace it before any external or public release.

### Info.plist keys that need a real file

The target uses `GENERATE_INFOPLIST_FILE = YES`. `INFOPLIST_KEY_*` build settings can
only express **flat** strings and booleans — a nested dictionary like
`NSAppTransportSecurity` cannot be written that way. The fix is to keep both:

- `Printernizer/Resources/Info.plist` holds only the dictionary-valued keys.
- `INFOPLIST_FILE = Printernizer/Resources/Info.plist` in **both** Debug and Release.
- `GENERATE_INFOPLIST_FILE` stays `YES` — Xcode merges the `INFOPLIST_KEY_*` settings
  on top of that base file, so existing flat keys are preserved.
- The Info.plist gets a `PBXFileReference` and a group entry, but **must not** be added
  to the Resources build phase — a plist consumed via `INFOPLIST_FILE` must not also be
  copied into the bundle.

Keys this app sets:

| Key | Where | Why |
|---|---|---|
| `NSAppTransportSecurity` → `NSAllowsLocalNetworking` | Info.plist | The backend is a LAN FastAPI server over plain HTTP (`APIConfiguration` prepends `http://` to bare hosts). This permits cleartext to `.local`, unqualified hostnames, and private/link-local ranges only — public hosts still require HTTPS. Narrower and easier to justify in review than `NSAllowsArbitraryLoads`. |
| `ITSAppUsesNonExemptEncryption` = `false` | Info.plist | App uses only standard system HTTPS/crypto, which is exempt. Declaring it stops App Store Connect asking on every upload. |
| `NSLocalNetworkUsageDescription` | `INFOPLIST_KEY_*` | iOS 14+ requires it before the app may reach LAN addresses. |

No `NSBonjourServices` entry is needed: printer discovery is server-side
(`PrinterService.discoverPrinters` calls `printers/discover` on the backend), so the
app never browses mDNS itself.

Verify the merge after building — this is the step that catches a botched
`INFOPLIST_FILE` wiring, where generated keys silently vanish:

```bash
plutil -p <DerivedData>/Build/Products/Debug-iphonesimulator/Printernizer.app/Info.plist
```

Expect `NSAppTransportSecurity`, `NSCameraUsageDescription`, and
`NSLocalNetworkUsageDescription` all present together.

## Every upload

1. **Bump the build number.** `CURRENT_PROJECT_VERSION` must be unique for a given
   `MARKETING_VERSION` — App Store Connect rejects a duplicate. Bump it in both the
   Debug and Release blocks of the app target. Raise `MARKETING_VERSION` only for a
   user-visible version change.
2. **Test on a physical device first.** See the warning below.
3. Xcode → Product → Destination → **Any iOS Device (arm64)**.
   `xcodebuild` alone will not do — the simulator SDK cannot produce an uploadable archive.
4. Product → **Archive**.
5. Organizer opens → **Distribute App** → **TestFlight & App Store** → Upload.
   Leave automatic signing and symbol upload on.
6. Processing takes ~5–15 min. Then in App Store Connect → TestFlight, add the build to
   **Internal Testing** (up to 100 testers on your team, no review needed).
   External testing requires a Beta App Review, usually a day or so.

### Always test on a real device before archiving

The simulator is **exempt from the local-network permission prompt**; a physical device
is not. A build that works perfectly in the simulator can install from TestFlight and
fail to reach the server at all. Before archiving, run on a device and confirm:

- the local-network permission prompt appears on the first server call, and
- printers load over `http://<lan-ip>:8000`.

## For the next project

Reusable across your other apps, in rough order of how often they bite:

1. 1024×1024 icon, no alpha, `filename` set in `Contents.json`.
2. App record created in App Store Connect before the first upload.
3. Unique build number per upload.
4. Real-device test before archiving — especially anything touching LAN, camera,
   notifications, or background modes, all of which behave differently in the simulator.
5. `ITSAppUsesNonExemptEncryption` set so the compliance prompt stops recurring.
6. The `INFOPLIST_FILE` + `GENERATE_INFOPLIST_FILE` merge pattern, for any app needing
   dictionary-valued plist keys.

Once this flow is proven manually, it maps directly onto a fastlane `beta` lane
(`increment_build_number` → `build_app` → `upload_to_testflight`), which is the point at
which automating it across several projects starts paying off. Doing that first, before
a successful manual upload, mostly means debugging two unfamiliar systems at once.
