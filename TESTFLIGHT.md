# Text Crush → TestFlight

Everything that can be prepared without an Apple account is done. What remains needs **your** Apple
identity and a one-time Codemagic signup — all of it in a browser, no Mac. Do these in order.

| Thing | Value |
|---|---|
| Bundle ID | `com.kevin.textcrush` |
| Codemagic integration name (must match `codemagic.yaml`) | `textcrush_asc_key` |
| API key role | **App Manager** |
| Workflow to run | `ios-testflight` |
| App name in App Store Connect | Text Crush (or "Text Crush — word board") |

### 1. Apple Developer Program — $99/yr

Enrol at <https://developer.apple.com/programs/> (needs an Apple ID; activation takes roughly a day
or two). This is the only hard cost.

### 2. Register the bundle ID

App Store Connect → Certificates, Identifiers & Profiles → Identifiers → **+** → App IDs → App.
Description "Text Crush", bundle ID **`com.kevin.textcrush`** (explicit).

### 3. Create the app record

App Store Connect → Apps → **+** → New App: platform iOS, the bundle ID from step 2, any SKU. This is
the container TestFlight fills.

### 4. App Store Connect API key

Users and Access → Integrations → **App Store Connect API** → **+** → role **App Manager**. Download
the **.p8** (you get one chance), and note the **Issuer ID** and **Key ID**.

### 5. Codemagic

- Sign up at <https://codemagic.io> with the Git host this repository is on.
- Team settings → Integrations → **App Store Connect** → add the key from step 4, named
  **`textcrush_asc_key`** (it must match `integrations.app_store_connect` in `codemagic.yaml`).
- Add this repository, pick the **`ios-testflight`** workflow, **Start build**.

Codemagic creates the distribution certificate and provisioning profile from that key, runs
`tools/copy-web-assets.sh`, builds and signs the `.ipa`, and uploads it. No manual certificate work.

### 6. TestFlight

App Store Connect → your app → TestFlight. The build appears after processing (~5–15 minutes). Add
yourself as an **internal tester** (instant, no review) and install it with the TestFlight app.

A **public link** or external testers trigger a light Beta App Review. A bundled, fully offline
WebView app is defensible as "more than a website" — the game is content-complete with no live site
behind it — but have that answer ready if Apple asks under guideline 4.2.

### Before or instead of all this

The same game is already installable for free from the web:
<https://kevinelong.github.io/textcrush/>. Open it in Safari on the phone, then Share → **Add to Home
Screen**. It runs offline afterwards. TestFlight is only worth the account if you want a store-style
native presence.
