#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ $# -gt 1 || ( $# -eq 1 && "$1" != --dry-run ) ]]; then
    echo "Usage: $0 [--dry-run]" >&2
    exit 1
fi
payload=$(mktemp)
trap 'rm -f "$payload"' EXIT
python3 - <<'PYTHON' > "$payload"
import json
import re
from pathlib import Path

inputs = json.loads(Path('config/sidestore-inputs.json').read_text())
if set(inputs) != {'ipa_release', 'ipa_sha256'}:
    raise SystemExit('Expected only ipa_release and ipa_sha256 inputs')
if not isinstance(inputs['ipa_release'], str) or not re.fullmatch(r'[a-zA-Z0-9][a-zA-Z0-9._-]*', inputs['ipa_release']):
    raise SystemExit('Set ipa_release to the unpublished base release tag first')
if not isinstance(inputs['ipa_sha256'], str) or not re.fullmatch(r'[a-fA-F0-9]{64}', inputs['ipa_sha256']):
    raise SystemExit('Set ipa_sha256 to the inspected base IPA SHA-256 first')
print(json.dumps({'ref': 'sidestore', 'inputs': inputs}))
PYTHON
if [[ "${1:-}" == --dry-run ]]; then
    cat "$payload"
else
    gh api repos/danzola01/SCInsta/actions/workflows/buildapp.yml/dispatches --method POST --input "$payload"
fi
