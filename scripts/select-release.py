#!/usr/bin/env python3
"""Select the newest stable Chamilo 3 release with a verified asset digest."""

import json
import re
import sys


def select(releases, current):
    current_version = tuple(map(int, current.split('.')))
    choices = []
    for release in releases:
        match = re.fullmatch(r'v(3)\.(0|[1-9]\d*)\.(0|[1-9]\d*)', release.get('tag_name', ''))
        if not match or release.get('draft') or release.get('prerelease'):
            continue
        version = tuple(map(int, match.groups()))
        if version <= current_version:
            continue
        name = f'chamilo-{version[0]}.{version[1]}.{version[2]}.zip'
        for asset in release.get('assets', []):
            digest = asset.get('digest') or ''
            if asset.get('name') == name and asset.get('state') == 'uploaded' and re.fullmatch(r'sha256:[0-9a-f]{64}', digest):
                choices.append((version, digest.removeprefix('sha256:')))
    return max(choices, default=None)


def main():
    if len(sys.argv) not in (2, 3) or any(not re.fullmatch(r'3\.(0|[1-9]\d*)\.(0|[1-9]\d*)', value) for value in sys.argv[1:]):
        sys.exit('Usage: select-release.py CURRENT_3_X_VERSION [REQUESTED_VERSION] < releases.json')
    pages = json.load(sys.stdin)
    releases = [release for page in pages for release in page]
    if len(sys.argv) == 3:
        releases = [release for release in releases if release.get('tag_name') == 'v' + sys.argv[2]]
    selected = select(releases, sys.argv[1])
    if selected:
        version, digest = selected
        print('.'.join(map(str, version)), digest)


if __name__ == '__main__':
    main()
