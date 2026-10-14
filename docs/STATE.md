# State

Where this repository is right now: what the last change was, what is checked, what is next, and
what is waiting on Kevin. The README says what the app is; this says where it stands.

## Now (2026-10-14)

- Branch `main`. The commit before this note is `9c25b6b` — "tools/check.sh: check what this machine
  can check, and fix the pin it found".
- **The app has never been built.** There is no `.ipa`, no tag and no release in this repository, and
  nothing on TestFlight or in the App Store. This machine has no Xcode and no Flutter, so building
  requires the one-time setup in `TESTFLIGHT.md` (Apple Developer Program, the bundle id
  `com.kevin.textcrush`, an App Store Connect API key with the App Manager role, and a Codemagic
  integration named exactly `textcrush_asc_key`).
- **Everything checkable without a Mac is checked.** `sh tools/check.sh` → 15 checks green: that
  `lib/main.dart` parses; that every analyzer finding is part of the missing-SDK cascade (the four
  unresolvable Flutter packages and what follows from them) and that the counts match the README;
  that the wrapper is the number of lines the README claims; that `codemagic.yaml` still names the
  workflow, the integration, the bundle id and the TestFlight upload; that every icon
  `Contents.json` names exists; that `Info.plist` and both storyboards parse; and that `game/source`
  is still `kevinelong/textcrush` at the recorded commit.
- **The vendored pin was wrong and is fixed.** `game/UPSTREAM_COMMIT` named
  `b8d04bc0f2d0c1c1c0b7d9b7b6d5b4b3b2b1b0af` — the first eight characters are the real commit and the
  rest was padding, so the file that answers "which upstream commit is this?" named one that does not
  exist. It now names `b8d04bc0e0dfbd8feffa78b51f02f7eeb7395002`.

## What changed last

`9c25b6b`: `tools/check.sh`, the corrected `game/UPSTREAM_COMMIT`, and the README's account of the
script and of what is left to the build.

## Next

1. **The gate, in order** (`TESTFLIGHT.md`): Apple Developer Program → register the bundle id → create
   the app record → App Store Connect API key → Codemagic integration named `textcrush_asc_key` →
   run the `ios-testflight` workflow. Nothing else here can move until that happens.
2. **On the first build and the first run, answer four things** that no check on this machine can:
   whether the game's notes sound on the first tap (iOS is stricter about audio without a gesture),
   whether the board appears at all (the ATS exception for `localhost:8090` is what permits it),
   whether anything is clipped by the notch or the home indicator, and whether the app launches and
   ticks on a tap. `tools/check.sh` prints this list at the end of every run so it does not get lost.
3. Keep `sh tools/check.sh` green as the wrapper changes: it will fail if the README's numbers drift
   from the code, which is how the two claims it now checks had already drifted.

## Awaiting Kevin's approval to push

**Nothing here has been pushed.** As of this note the branch is **2 commits ahead of `origin/main`**:

```
git log --oneline origin/main..HEAD

9c25b6b  tools/check.sh: check what this machine can check, and fix the pin it found
         (this note's own commit, on top of it)
```

Pushing this repository publishes nothing — unlike `tc`, there is no deployment behind it — but it
still waits with the other two.

## Open decisions (Kevin's)

- **The Apple Developer Program, $99/yr**, and everything in `TESTFLIGHT.md` that depends on it. This
  is the only hard cost in the trio and the only thing gating a signed build.
- **`* text=auto eol=lf` in `.gitattributes`**, for the same reason as in `textcrush-android`: with
  `core.autocrlf=true` a fresh clone gets different bytes from the committed ones, so measured
  numbers cannot be reproduced. This repository has no published digest to protect, so it is a
  consistency decision rather than an urgent one — but the three repositories should be set the same
  way in one session.
- **No CI here.** A job needs Flutter to build anything, which is what Codemagic is for; `dart` alone
  can only run `tools/check.sh`, which is run by hand instead.
