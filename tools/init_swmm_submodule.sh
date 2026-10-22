#!/usr/bin/env bash
set -euo pipefail

# A ZIP patch cannot install a Git gitlink. Run this once after applying the
# first integration patch, then commit .gitmodules and the submodule gitlink.
SWMM_URL='https://github.com/aowis-org/pyStormwater-Management-Model.git'
SWMM_COMMIT='27dc6990cda8bce21f6c16ddae631b37e7510ffc'

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
[[ "$(basename -- "$root")" == 'AOWIS-SERVER-SWMM' ]] || {
    echo 'Must be located in AOWIS-SERVER-SWMM.' >&2; exit 1;
}
[[ "$(git -C "$root" rev-parse --show-toplevel 2>/dev/null)" == "$root" ]] || {
    echo 'Initialize a Git repository before adding the solver submodule.' >&2; exit 1;
}

if git -C "$root" ls-files --stage -- external/swmm | grep -q '^160000 '; then
    echo 'Existing submodule detected; initializing it.'
    git -C "$root" submodule update --init --recursive -- external/swmm
else
    if [[ -e "$root/external/swmm" || -L "$root/external/swmm" ]]; then
        echo 'external/swmm exists but is not a registered Git submodule; refusing to overwrite it.' >&2
        exit 1
    fi
    git -C "$root" submodule add "$SWMM_URL" external/swmm
fi

actual_url="$(git -C "$root/external/swmm" remote get-url origin)"
if [[ "$actual_url" != "$SWMM_URL" ]]; then
    printf 'Unexpected solver origin: %s\nExpected: %s\n' "$actual_url" "$SWMM_URL" >&2
    exit 1
fi
if ! git -C "$root/external/swmm" cat-file -e "${SWMM_COMMIT}^{commit}" 2>/dev/null; then
    git -C "$root/external/swmm" fetch --no-tags origin "$SWMM_COMMIT"
fi
git -C "$root/external/swmm" -c advice.detachedHead=false checkout --detach "$SWMM_COMMIT"
git -C "$root" add -- .gitmodules external/swmm
printf 'Pinned external/swmm to %s\n' "$(git -C "$root/external/swmm" rev-parse HEAD)"
echo 'Commit .gitmodules and external/swmm together with the integration files.'
