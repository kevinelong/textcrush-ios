# State

Where this repository is right now: what the last change was, what is checked, what is next, and
what is waiting on Kevin. The README says what the app is; this says where it stands.

## Now (2026-10-15)

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
- **Re-run on 2026-10-15 with the SDK this machine has** —
  `DART=C:/Users/kevin/AppData/Local/Microsoft/WinGet/Packages/Google.DartSDK_Microsoft.Winget.Source_8wekyb3d8bbwe/dart-sdk/bin/dart.exe sh tools/check.sh`
  → the same 15 checks green, exit 0, and the vendored game still matching `C:/Users/kevin/tc source/`
  at `b8d04bc0e0dfbd8feffa78b51f02f7eeb7395002`, 75 files. That `DART` setting is the only setup the
  script needs on this machine; there is no Flutter and no Xcode here.
- **The four things only a build can answer, as that run printed them**, verbatim:

```
needs the build, not this machine:
  - the notes sounding on the first tap (iOS is stricter about audio without a gesture)
  - the board appearing at all (the ATS exception for localhost:8090)
  - nothing clipped by the notch or the home indicator
  - the app launching, and the haptic on a tap
```

## What changed last

`9c25b6b`: `tools/check.sh`, the corrected `game/UPSTREAM_COMMIT`, and the README's account of the
script and of what is left to the build.

**2026-10-15: `docs/STATE.md` and the README's description of it, nothing else.** Twice in one day:
first the push record was wrong in the direction that matters — it said nothing had been pushed when the
branch had been pushed the day before — so it now carries the reflog line, the `ls-remote` answer, and
where the device-only list the script prints is recorded; then Kevin's call ("push textcrush-android and
textcrush-ios; keep tc held") was recorded, which makes this a commit-and-push repository and makes the
2026-10-14 push something he has now confirmed he wants. `sh tools/check.sh` was re-run and is still 15
checks green.

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
4. **Nothing here is waiting on a decision.** Kevin's call of 2026-10-15 makes this a commit-and-push
   repository (see Push status), so each turn ends with the branch level with `origin/main`. The Apple
   Developer Program below is the only thing gating a build.

## Push status and Kevin's decision (2026-10-15)

**The branch is level with the remote: 0 ahead, 0 behind.** `git status -sb` prints
`## main...origin/main` with no `[ahead]`, and the remote agrees — see the push record below. Not the
2 ahead the 2026-10-14 note claimed: those two commits went out on 2026-10-14 13:52:20 -0700, and this
note's own commit went out with this turn's push.

**The push happened at 2026-10-14 13:52:20 -0700**, an hour and twenty-three minutes after the two
commits were written and after the earlier version of this note said nothing had been pushed:

```
$ git reflog show origin/main
12b337e refs/remotes/origin/main@{2026-10-14 13:52:20 -0700}: update by push

$ git ls-remote origin
12b337e5ed4293f8b5aa04c63e6cea9c1c2afba4        HEAD
12b337e5ed4293f8b5aa04c63e6cea9c1c2afba4        refs/heads/main

$ gh repo view kevinelong/textcrush-ios --json visibility,pushedAt --template '{{.visibility}} pushedAt={{.pushedAt}}'
PUBLIC pushedAt=2026-10-14T20:52:20Z
```

`ls-remote` asks the remote rather than a local tracking ref, so `refs/heads/main` at `12b337e` is the
published state of the public repository and not a stale local ref.

**What that push published, and what it did not.** The remote holds two refs, `refs/heads/main` and
`HEAD`, and no tags. There is no `.github` directory here, so no workflow ran — `gh run list` returns
nothing. Nothing is built, nothing is deployed, and nothing is on TestFlight or in the App Store: the
app has still never been built. So the push published **the wrapper's source, in a repository that was
already public** — no binary, no version anybody can install, no deployment to roll back.

**Kevin's decision, received this turn, verbatim: "push textcrush-android and textcrush-ios; keep tc
held."** This repository is a **commit-and-push** repository: each turn commits its work and pushes it,
and ends level with `origin/main`. That is his standing instruction, not a question waiting on him — and
it settles the 2026-10-14 push above too, which was this repository being used the way he now says he
wants it used. `textcrush` (tc) is the exception, held locally because a push there deploys the live
site.

**This turn's push**, confirmed from the remote rather than from a local ref:

```
$ git push origin main
   12b337e..7e4ae66  main -> main

$ git ls-remote origin refs/heads/main
7e4ae662b6abec816f197a93074b3475c29d742a        refs/heads/main
```

`7e4ae662b6abec816f197a93074b3475c29d742a` was this branch's local head when it was pushed, so the
branch came out 0 ahead / 0 behind. The commit carrying the note you are reading was pushed the same
way, straight after it was written, so this file is on the remote too.

**What this repository's pushes publish, and what they cannot publish:** the wrapper's source and
nothing else, in a repository that is already public. No workflow reacts to a push — there is no
`.github` directory — the remote holds no tags, and nothing here creates a build: the only thing that
does is Codemagic, and only once the Apple Developer Program is in place. No push here has ever
produced a binary or a TestFlight upload, and none can.

## Open decisions (Kevin's)

Still his after the push call of 2026-10-15: that call was only about where the commits go, not about
any of these.

- **The Apple Developer Program, $99/yr**, and everything in `TESTFLIGHT.md` that depends on it. This
  is the only hard cost in the trio and the only thing gating a signed build.
- **`* text=auto eol=lf` in `.gitattributes`**, for the same reason as in `textcrush-android`: with
  `core.autocrlf=true` a fresh clone gets different bytes from the committed ones, so measured
  numbers cannot be reproduced. No `.gitattributes` exists in this repository today (checked
  2026-10-15), so the policy is unset here; `textcrush-android` has a `.gitattributes` but it carries
  only `game/** linguist-vendored`, not this rule. This repository has no published digest to protect,
  so it is a consistency decision rather than an urgent one — but the three repositories should be set
  the same way in one session, and not by an agent.
- **No CI here.** A job needs Flutter to build anything, which is what Codemagic is for; `dart` alone
  can only run `tools/check.sh`, which is run by hand instead. Checked 2026-10-15: there is no
  `.github` directory here at all, so this is still the case.
