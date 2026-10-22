#!/usr/bin/env bash
set -euo pipefail

# Export the complete AOWIS worktree, including initialized submodule source.
# A Git submodule is otherwise only a gitlink and would be absent from a ZIP.
if [[ $# -gt 1 ]]; then
    printf 'Usage: %s [output.zip]\n' "${0##*/}" >&2
    exit 2
fi
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
root="$(cd -- "$script_dir/.." && pwd -P)"
[[ "$(basename -- "$root")" == AOWIS-SERVER-SWMM ]] || {
    echo 'Expected AOWIS-SERVER-SWMM project directory.' >&2; exit 1;
}
output="${1:-$(dirname -- "$root")/swmm.zip}"
python3 - "$root" "$output" <<'PY'
import os
from pathlib import Path, PurePosixPath
import stat
import subprocess
import sys
import tempfile
import zipfile

root = Path(sys.argv[1]).resolve()
output = Path(sys.argv[2]).expanduser().absolute()
if output.suffix != '.zip' or not output.parent.is_dir():
    sys.exit('Output must be a .zip in an existing directory')


def git(directory, *args):
    try:
        return subprocess.check_output(['git', '-C', str(directory), *args], stderr=subprocess.PIPE)
    except (subprocess.CalledProcessError, FileNotFoundError) as exc:
        sys.exit(f'Unable to inspect Git worktree {directory}: {exc}')


if Path(os.fsdecode(git(root, 'rev-parse', '--show-toplevel')).strip()).resolve() != root:
    sys.exit('This tool must run inside the AOWIS-SERVER-SWMM Git worktree')

seen = set()
files = []
submodules = []


def collect(directory, prefix):
    gitlinks = set()
    for record in git(directory, 'ls-files', '--stage', '-z').split(b'\0'):
        if not record:
            continue
        metadata, name = record.split(b'\t', 1)
        if metadata.split(b' ', 1)[0] == b'160000':
            gitlinks.add(os.fsdecode(name))

    paths = git(directory, 'ls-files', '-z', '--cached', '--others', '--exclude-standard')
    for raw in paths.split(b'\0'):
        if not raw:
            continue
        name = os.fsdecode(raw)
        relative = PurePosixPath(name)
        parts = relative.parts
        if (name.startswith('/') or any(p in ('', '.', '..', '.git') for p in parts) or
            '\\' in name):
            sys.exit(f'Unsafe Git path: {name!r}')
        source = directory.joinpath(*parts)
        archive_name = '/'.join((root.name, *prefix, *parts))
        if name in gitlinks:
            if source.is_symlink() or not source.is_dir():
                sys.exit(f'Uninitialized submodule: {source}. Run git submodule update --init --recursive')
            if Path(os.fsdecode(git(source, 'rev-parse', '--show-toplevel')).strip()).resolve() != source.resolve():
                sys.exit(f'Submodule does not have its own Git worktree: {source}')
            submodules.append('/'.join((*prefix, *parts)))
            collect(source, (*prefix, *parts))
            continue
        if not source.is_file() or source.is_symlink():
            continue
        if source.resolve() == output.resolve():
            continue
        if (any(p in ('.git', '.env', '.ssh') or p.startswith('.env.') for p in parts) or
            source.suffix.lower() in ('.pem', '.key', '.p12', '.pfx') or
            source.name in ('id_rsa', 'id_ed25519')):
            continue
        # Refuse traversal via a symlinked parent directory.
        current = directory
        for part in parts[:-1]:
            current = current / part
            if current.is_symlink():
                sys.exit(f'Symlinked directory in worktree: {current}')
        if not stat.S_ISREG(source.stat().st_mode):
            continue
        if archive_name in seen:
            continue
        seen.add(archive_name)
        files.append((source, archive_name))


collect(root, ())
if not files:
    sys.exit('No project files to archive')

fd, temporary = tempfile.mkstemp(prefix='.swmm-', suffix='.zip', dir=output.parent)
os.close(fd)
try:
    with zipfile.ZipFile(temporary, 'w', compression=zipfile.ZIP_DEFLATED,
                         compresslevel=6, allowZip64=True) as archive:
        for source, name in sorted(files, key=lambda item: item[1]):
            archive.write(source, arcname=name)
    os.replace(temporary, output)
finally:
    if os.path.exists(temporary):
        os.unlink(temporary)
print(f'Created {output} ({len(files)} files; {len(submodules)} submodule(s))')
PY
