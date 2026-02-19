#!/usr/bin/env bash
set -euo pipefail

files=$(find supabase/migrations -type f -name '*.sql' | sort)
if [[ -z "${files}" ]]; then
  echo "No SQL migration files found."
  exit 1
fi

status=0
for file in ${files}; do
  echo "Checking ${file}"

  # basic hygiene checks
  if grep -n $'\r' "${file}" >/dev/null; then
    echo "ERROR: ${file} contains CRLF line endings"
    status=1
  fi

  if ! tail -n 1 "${file}" | grep -Eq ';\s*$'; then
    echo "ERROR: ${file} does not end with semicolon"
    status=1
  fi

  if grep -n $'\t' "${file}" >/dev/null; then
    echo "ERROR: ${file} contains tab characters"
    status=1
  fi
done

exit ${status}
