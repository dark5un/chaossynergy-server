#!/usr/bin/env bash
# secret-gate.sh — value scanner for this repo (public by default, private by rule).
# Scans tracked files (or files given as args) for credential-shaped VALUES and
# machine identifiers. Mechanism words (service.env, pass, token, api key...) are
# fine; actual secrets, IPs, hostnames, and long hex are not.
# Exemption: a line ending with 'secret-gate:ok (<reason>)' is skipped.
set -uo pipefail
PATTS=(
  'sha256:[0-9a-f]{12,}'
  '\b[0-9a-f]{40,}\b'
  '-----BEGIN [A-Z ]*PRIVATE KEY-----'
  '\b(ghp|github_pat|glpat|xox[abpsr]|sk-[A-Za-z0-9_-]{16,}|AKIA[0-9A-Z]{16})[0-9A-Za-z_-]*'
  '\b(10|172\.(1[6-9]|2[0-9]|3[01])|192\.168)\.([0-9]{1,3}\.){1,2}[0-9]{1,3}\b'
  '\b100\.([6-9][0-9]|1[0-1][0-9]|12[0-7])\.([0-9]{1,3}\.[0-9]{1,3})\b'
  '\bfd[0-9a-f]{2}:[0-9a-f:]+\b'
  '/home/[a-z0-9_-]+/'
  '\b[a-z0-9-]+\.tail[0-9a-f]+\.ts\.net\b'
  '\b(password|passwd|secret|apikey|api_key|token)[^=\n]{0,40}=\s*\S{8,}'
)
# Site-specific identifiers (hostnames, volume labels, machine names) live in an
# UNTRACKED local file — the gate must not itself publish what it guards.
LOCAL_PATTERNS='scripts/secret-gate.local'
if [ -f "$LOCAL_PATTERNS" ]; then
  while IFS= read -r lp; do [ -n "$lp" ] && PATTS+=("$lp"); done < "$LOCAL_PATTERNS"
fi
status=0
files=${@:-$(git ls-files)}
for f in $files; do
  case "$f" in scripts/secret-gate.sh) continue;; esac
  [ -f "$f" ] || continue
  for pat in "${PATTS[@]}"; do
    while IFS= read -r line; do
      content=${line#*:}; content=${content#*:}
      case "$content" in *'secret-gate:ok'*) continue;; esac
      case "$content" in *10.0.2.2*|*127.0.0.1*|*0.0.0.0*|*255.255*) continue;; esac
      echo "HIT $f: pattern [$pat]"
      echo "     ${content:0:100}"
      status=1
    done < <(grep -nP "$pat" "$f" 2>/dev/null)
  done
done
if [ $status -eq 0 ]; then echo "secret-gate: PASS ($(echo "$files" | wc -w) files)"; fi
exit $status
