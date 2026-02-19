#!/usr/bin/env bash
set -euo pipefail

# Scan tracked files, excluding docs/examples where placeholder keys may appear.
tracked=$(git ls-files)

patterns='(AKIA[0-9A-Z]{16}|-----BEGIN (RSA|EC|OPENSSH|DSA)? ?PRIVATE KEY-----|xox[baprs]-[0-9A-Za-z-]{10,}|ghp_[0-9A-Za-z]{36,}|SUPABASE_SERVICE_ROLE_KEY\s*=\s*[^r]|OPENAI_API_KEY\s*=\s*[^r])'

status=0
while IFS= read -r file; do
  case "$file" in
    *example*|*.md|*.mdx|*.txt|*.json)
      ;;
    *)
      if grep -EIn "$patterns" "$file" >/dev/null; then
        echo "Potential secret found in $file"
        grep -EIn "$patterns" "$file" || true
        status=1
      fi
      ;;
  esac
done <<< "$tracked"

exit ${status}
