#!/bin/sh
# Everything about this project that can be checked on a machine that is not a Mac.
#
#   sh tools/check.sh
#
# There is no Xcode and no Flutter here, so the app cannot be built, run or signed - but a surprising
# amount of this repository is prose about itself: the wrapper's size, what the analyzer said, which
# upstream commit the game was vendored from, the Codemagic wiring, the icon set, the plists. Every
# one of those was written down once, by hand, and nothing re-checked them afterwards; the line count
# had already drifted by 200 lines and the recorded upstream commit did not exist.
#
# What is deliberately NOT here: anything only the build can answer. The audio on the first tap, the
# ATS exception that lets the WebView load localhost, the safe area, and whether the app runs at all
# are listed at the end of this output and are answered by the first Codemagic build and the first run
# on a device - not by a claim in a README.
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
export MSYS_NO_PATHCONV=1

TC=${TC:-$(cd "$ROOT/.." && pwd)/tc}
# git -C wants C:/..., not /c/...
TC=$(cygpath -m "$TC")

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

FAILED=0

ok() {
    echo "  ok    $1"
}

bad() {
    echo "  FAIL  $1"
    FAILED=1
}

echo "the wrapper parses"

if dart format --output=none lib/main.dart > "$TMP/format.txt" 2>&1; then
    ok "dart format parses lib/main.dart"
else
    bad "dart format does not parse lib/main.dart"
    cat "$TMP/format.txt"
fi

echo
echo "what the analyzer says, against what the README says it says"

# dart analyze exits non-zero when it finds anything, which is the expected case here.
dart analyze --format machine lib/main.dart > "$TMP/analyze.txt" 2>&1 || true

# python is a Windows binary here: it cannot open an MSYS /tmp/... path
python - "$ROOT" "$(cygpath -m "$TMP/analyze.txt")" <<'PY' || FAILED=1
import re
import sys

root, findings_path = sys.argv[1], sys.argv[2]

# Every finding must be one of these. They are the cascade from the four package imports that cannot
# resolve without a Flutter SDK: an unknown base class cannot be extended, its members cannot be
# overridden, and a const expression built from an unknown type is not constant. A code outside this
# set is something new in the file, which is the thing worth hearing about.
CASCADE = {
    "URI_DOES_NOT_EXIST",
    "UNDEFINED_CLASS",
    "UNDEFINED_METHOD",
    "UNDEFINED_IDENTIFIER",
    "UNDEFINED_FUNCTION",
    "UNDEFINED_SUPER_MEMBER",
    "CREATION_WITH_NON_TYPE",
    "CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE",
    "EXTENDS_NON_CLASS",
    "SUPER_FORMAL_PARAMETER_WITHOUT_ASSOCIATED_NAMED",
    "OVERRIDE_ON_NON_OVERRIDING_MEMBER",
}

PACKAGES = [
    "package:flutter/foundation.dart",
    "package:flutter/material.dart",
    "package:flutter/services.dart",
    "package:flutter_inappwebview/flutter_inappwebview.dart",
]

findings = []
for line in open(findings_path, encoding="utf-8"):
    line = line.strip()
    if not line:
        continue
    parts = line.split("|")
    if len(parts) < 8:
        continue
    severity, _type, code, _file, _line, _col, _len, message = parts[:8]
    findings.append((severity, code, message))

failed = 0
issues = len(findings)
errors = sum(1 for f in findings if f[0] == "ERROR")
warnings = sum(1 for f in findings if f[0] == "WARNING")

unexpected = sorted({code for _s, code, _m in findings} - CASCADE)
if unexpected:
    print("  FAIL  findings that are not part of the missing-SDK cascade: %s" % ", ".join(unexpected))
    for severity, code, message in findings:
        if code in unexpected:
            print("        %s: %s" % (code, message))
    failed = 1
else:
    print("  ok    every finding is part of the missing-SDK cascade (%d codes)" % len(CASCADE))

# the message is: Target of URI doesn't exist: 'package/....dart'. The apostrophe in "doesn't" is the
# first one in the line, so a general '...' pattern pairs it with the opening quote of the URI and
# finds nothing after that; the URI is matched by the shape of the message instead.
def imported(message):
    found = re.search(r"exist: '([^']+)'", message)
    return found.group(1) if found else ""


uris = sorted(imported(m) for s, c, m in findings if c == "URI_DOES_NOT_EXIST")
if uris == sorted(PACKAGES):
    print("  ok    the four unresolvable imports are the four Flutter packages")
else:
    print("  FAIL  unresolvable imports are %s" % uris)
    failed = 1

# the README wraps its sentences, so the claims are matched against it as one line
readme = re.sub(r"\s+", " ",
                open("%s/README.md" % root, encoding="utf-8").read(), flags=re.S)

claimed = re.search(r"\*\*(\d+) issues \((\d+) errors, (\d+) warnings\)\*\* under Dart ([0-9.]+)", readme)
if not claimed:
    print("  FAIL  the README states no analyzer count to check against")
    failed = 1
else:
    want_issues, want_errors, want_warnings, want_sdk = (
        int(claimed.group(1)), int(claimed.group(2)), int(claimed.group(3)), claimed.group(4))
    if (issues, errors, warnings) == (want_issues, want_errors, want_warnings):
        print("  ok    the analyzer reports the %d issues (%d errors, %d warnings) the README claims"
              % (issues, errors, warnings))
    else:
        print("  FAIL  the README claims %d issues (%d errors, %d warnings); this SDK reports %d "
              "(%d errors, %d warnings). Update the README."
              % (want_issues, want_errors, want_warnings, issues, errors, warnings))
        failed = 1

lines = len(open("%s/lib/main.dart" % root, encoding="utf-8").read().splitlines())
stated = re.search(r"\*\*The whole wrapper is `lib/main\.dart`\*\* \((\d+) lines\)", readme)
if not stated:
    print("  FAIL  the README states no line count to check against")
    failed = 1
elif int(stated.group(1)) == lines:
    print("  ok    lib/main.dart is the %d lines the README claims" % lines)
else:
    print("  FAIL  the README says %s lines; lib/main.dart is %d. Update the README."
          % (stated.group(1), lines))
    failed = 1

sys.exit(1 if failed else 0)
PY

echo
echo "the Codemagic wiring"

if grep -qF 'ios-testflight:' codemagic.yaml; then
    ok "codemagic.yaml defines the ios-testflight workflow"
else
    bad "codemagic.yaml does not define the ios-testflight workflow"
fi

if grep -qF 'app_store_connect: textcrush_asc_key' codemagic.yaml; then
    ok "the integration is textcrush_asc_key, the name TESTFLIGHT.md tells you to use"
else
    bad "codemagic.yaml's app_store_connect integration is not textcrush_asc_key"
fi

if grep -qF 'bundle_identifier: com.kevin.textcrush' codemagic.yaml; then
    ok "the bundle id is com.kevin.textcrush"
else
    bad "codemagic.yaml's bundle_identifier is not com.kevin.textcrush"
fi

if grep -qF 'submit_to_testflight: true' codemagic.yaml; then
    ok "the workflow uploads to TestFlight"
else
    bad "the workflow does not upload to TestFlight"
fi

if grep -qF 'flutter build ipa' codemagic.yaml; then
    ok "the workflow builds a signed .ipa"
else
    bad "the workflow does not build an .ipa"
fi

echo
echo "the icon set and the plists"

python - "$ROOT" <<'PY' || FAILED=1
import json
import os
import sys
import xml.dom.minidom

root = sys.argv[1]
failed = 0

base = os.path.join(root, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
contents = json.load(open(os.path.join(base, "Contents.json"), encoding="utf-8"))
entries = contents.get("images", [])
missing = [e["filename"] for e in entries
           if e.get("filename") and not os.path.isfile(os.path.join(base, e["filename"]))]
if entries and not missing:
    print("  ok    the icon set has every file its Contents.json names (%d entries)" % len(entries))
else:
    print("  FAIL  Contents.json names %d entr(ies) and %d are missing: %s"
          % (len(entries), len(missing), missing[:5]))
    failed = 1

for relative in ["ios/Runner/Info.plist",
                 "ios/Runner/Base.lproj/LaunchScreen.storyboard",
                 "ios/Runner/Base.lproj/Main.storyboard"]:
    path = os.path.join(root, relative)
    try:
        xml.dom.minidom.parse(path)
    except Exception as problem:
        print("  FAIL  %s does not parse: %s" % (relative, problem))
        failed = 1
    else:
        print("  ok    %s parses" % relative)

sys.exit(1 if failed else 0)
PY

echo
echo "the vendored game"

COMMIT=$(sed -n '1p' game/UPSTREAM_COMMIT | tr -d '\r\n')

if [ ! -d "$TC/.git" ]; then
    bad "no textcrush checkout at $TC - set TC=/path/to/textcrush"
elif ! git -C "$TC" cat-file -e "$COMMIT^{commit}" 2>/dev/null; then
    bad "game/UPSTREAM_COMMIT names $COMMIT, which is not a commit in $TC"
else
    git -C "$TC" ls-tree -r --name-only "$COMMIT" source > "$TMP/upstream-files"
    mkdir -p "$TMP/upstream"
    while IFS= read -r file; do
        case $file in
            source/*) target=${file#source/} ;;
            *) continue ;;
        esac
        mkdir -p "$TMP/upstream/$(dirname "$target")"
        git -C "$TC" cat-file blob "$COMMIT:$file" > "$TMP/upstream/$target"
    done < "$TMP/upstream-files"

    # line endings are compared away: which side has CR is an artifact of how the copy was made
    strip_cr() {
        from=$1
        to=$2
        mkdir -p "$to"
        (cd "$from" && find . -type f) | while IFS= read -r file; do
            mkdir -p "$to/$(dirname "$file")"
            tr -d '\r' < "$from/$file" > "$to/$file"
        done
    }
    strip_cr "$ROOT/game/source" "$TMP/vendored"
    strip_cr "$TMP/upstream" "$TMP/upstream-plain"

    if diff -r "$TMP/vendored" "$TMP/upstream-plain" > "$TMP/game.diff" 2>&1; then
        ok "game/source matches $TC source/ at $COMMIT, $(find "$TMP/vendored" -type f | wc -l | tr -d ' ') files"
    else
        bad "game/source does not match $TC source/ at $COMMIT"
        sed -n '1,20p' "$TMP/game.diff"
    fi
fi

echo
echo "needs the build, not this machine:"
echo "  - the notes sounding on the first tap (iOS is stricter about audio without a gesture)"
echo "  - the board appearing at all (the ATS exception for localhost:8090)"
echo "  - nothing clipped by the notch or the home indicator"
echo "  - the app launching, and the haptic on a tap"

echo
if [ "$FAILED" -ne 0 ]; then
    echo "something above does not match what this repository says about itself"
    exit 1
fi

echo "everything checkable on this machine matches what this repository says about itself"
