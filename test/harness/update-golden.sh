#!/usr/bin/env bash
# Seule voie de régénération des références. Son diff part en revue.
set -euo pipefail
exec "$(dirname "${BASH_SOURCE[0]}")/run-scenario.sh" "${1:?usage: update-golden.sh <scenario>}" --update-golden
