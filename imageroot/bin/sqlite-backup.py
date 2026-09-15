#!/usr/bin/env python3

#
# Copyright (C) 2026 Nethesis S.r.l.
# SPDX-License-Identifier: GPL-3.0-or-later
#

#
# Consistent copy of a live SQLite database, using the online backup API.
# Run under `podman unshare`: the volume files belong to a sub-uid.
#

import os
import sqlite3
import sys

src, dst = sys.argv[1], sys.argv[2]

if not os.path.exists(src):
    print(f"{src} does not exist yet: nothing to dump", file=sys.stderr)
    sys.exit(0)

if os.path.exists(dst):
    os.unlink(dst)

source = sqlite3.connect(src, timeout=60)
destination = sqlite3.connect(dst)
with destination:
    source.backup(destination)
destination.close()
source.close()
os.chmod(dst, 0o600)
