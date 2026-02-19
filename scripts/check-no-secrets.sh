#!/usr/bin/env bash
set -euo pipefail

tracked=$(git ls-files)

# High-signal secret patterns only (avoid noisy placeholders from *.example files)
patterns='(AKIA[0-9A-Z]{16}|-----BEGIN (RSA|EC|OPENSSH|DSA)? ?PRIVATE KEY-----|xox[baprs]-[0-9A-Za-z-]{10,}|ghp_[0-9A-Za-z]{36,}|SUPABASE_SERVICE_ROLE_KEY\s*=\s*[^\s][^\n]+|OPENAI_API_KEY\s*=\s*[^\s][^\n]+|postgres://[^\s:]+:[^\s@]+@)'

status=0
while IFS= read -r file; do
  case "$file" in
    *example*|*.md|*.mdx|*.txt)
      continue
      ;;
  esac

  if grep -EIn "$patterns" "$file" >/dev/null; then
    echo "Potential secret found in $file"
    grep -EIn "$patterns" "$file" || true
    status=1
  fi
done <<< "$tracked"

exit ${status}
