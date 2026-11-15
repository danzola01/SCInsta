#!/usr/bin/env python3
"""Remove embedded app extensions from an IPA without extracting it."""

import argparse
import copy
import os
from pathlib import Path, PurePosixPath
import shutil
import tempfile
import zipfile


def is_extension(name):
    parts = PurePosixPath(name).parts
    return (len(parts) >= 3 and parts[0] == 'Payload'
            and parts[1].endswith('.app')
            and any(part.endswith('.appex') for part in parts[2:]))


def check(path):
    with zipfile.ZipFile(path) as archive:
        extensions = sorted({part for name in archive.namelist()
                             if is_extension(name)
                             for part in PurePosixPath(name).parts[2:]
                             if part.endswith('.appex')})
    if extensions:
        raise ValueError('Embedded app extensions remain: ' + ', '.join(extensions))


def strip(source, destination):
    if source.resolve() == destination.resolve():
        raise ValueError('Input and output must differ')
    destination.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(suffix='.ipa', dir=destination.parent)
    os.close(fd)
    try:
        with zipfile.ZipFile(source) as original, zipfile.ZipFile(temporary, 'w') as output:
            output.comment = original.comment
            for entry in original.infolist():
                if is_extension(entry.filename):
                    continue
                with original.open(entry) as reader, output.open(copy.copy(entry), 'w') as writer:
                    shutil.copyfileobj(reader, writer, length=1024 * 1024)
        check(Path(temporary))
        os.replace(temporary, destination)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('destination', type=Path, nargs='?')
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    if args.check:
        if args.destination:
            parser.error('--check takes only a source')
        try:
            check(args.source)
        except ValueError as error:
            parser.exit(1, f'{error}\n')
        print('Verified: no embedded app extensions')
    else:
        if not args.destination:
            parser.error('destination is required unless using --check')
        strip(args.source, args.destination)
        print(f'Created extension-free IPA: {args.destination}')


if __name__ == '__main__':
    main()
