---
name: Music Sort
description: >
  Moves recently downloaded music (last 2 hours) from ~/Downloads to ~/Music,
  organized into Artist/Album directory structure. Use when the user asks to
  sort, organize, categorize, move, or file music from Downloads. Triggers:
  "organize my music", "sort my downloads", "move music to Music folder",
  "categorize my downloads", "sort recent music".
---

# Music Sort Skill

When invoked, run the Python script below immediately using the Bash tool
without asking the user for confirmation. Do not modify the script unless
the user asks you to customize behavior.

After running, summarize what was moved (artist/album groupings and track
counts). If any files were skipped or had ambiguous metadata, call them out so
the user can decide.

## Script

```python
#!/usr/bin/env python3
import json
import os
import re
import shutil
import subprocess
import time

DOWNLOADS = os.path.expanduser("~/Downloads")
MUSIC = os.path.expanduser("~/Music")
AUDIO_EXTS = {".mp3", ".flac", ".m4a", ".ogg", ".opus", ".wav", ".aac", ".wma", ".ape", ".alac"}
CUTOFF = time.time() - 2 * 3600  # 2 hours ago

def sanitize(name: str) -> str:
    """Remove/replace characters invalid in directory names."""
    name = name.strip()
    name = re.sub(r'[<>:"/\\|?*\x00-\x1f]', '_', name)
    name = name.rstrip('. ')
    return name or "Unknown"

def get_metadata(path: str) -> dict:
    """Return {'artist': ..., 'album': ...} via ffprobe, or empty dict on failure."""
    try:
        result = subprocess.run(
            ["ffprobe", "-v", "quiet", "-print_format", "json", "-show_format", path],
            capture_output=True, text=True, timeout=10
        )
        data = json.loads(result.stdout)
        tags = {k.lower(): v for k, v in data.get("format", {}).get("tags", {}).items()}
        artist = tags.get("artist") or tags.get("album_artist")
        album = tags.get("album")
        if artist and album:
            return {"artist": artist.strip(), "album": album.strip()}
    except Exception:
        pass
    return {}

# Common filename patterns:
#   Artist - Album - ##-## Track.ext
#   Artist - Album - ## Track.ext
#   Artist - Album - Track.ext
FILENAME_RE = re.compile(
    r'^(?P<artist>.+?)\s+-\s+(?P<album>.+?)\s+-\s+(?:\d{2}-\d{2}|\d{2,3})\s*.+$',
    re.IGNORECASE
)
FILENAME_RE_SIMPLE = re.compile(
    r'^(?P<artist>.+?)\s+-\s+(?P<album>.+?)\s+-\s+.+$',
    re.IGNORECASE
)

def parse_filename(filename: str) -> dict:
    """Try to infer artist/album from filename."""
    stem = os.path.splitext(filename)[0]
    for pattern in (FILENAME_RE, FILENAME_RE_SIMPLE):
        m = pattern.match(stem)
        if m:
            return {"artist": m.group("artist").strip(), "album": m.group("album").strip()}
    return {}

def find_recent_music() -> list[str]:
    files = []
    for entry in os.scandir(DOWNLOADS):
        if not entry.is_file():
            continue
        ext = os.path.splitext(entry.name)[1].lower()
        if ext not in AUDIO_EXTS:
            continue
        if entry.stat().st_mtime >= CUTOFF:
            files.append(entry.path)
    return sorted(files)

moved = []
skipped = []

for path in find_recent_music():
    filename = os.path.basename(path)
    info = get_metadata(path) or parse_filename(filename)

    if not info:
        skipped.append({"file": filename, "reason": "no metadata or recognizable filename pattern"})
        continue

    artist_dir = sanitize(info["artist"])
    album_dir = sanitize(info["album"])
    dest_dir = os.path.join(MUSIC, artist_dir, album_dir)
    os.makedirs(dest_dir, exist_ok=True)

    dest = os.path.join(dest_dir, filename)
    if os.path.exists(dest):
        skipped.append({"file": filename, "reason": f"already exists at {dest}"})
        continue

    shutil.move(path, dest)
    moved.append({
        "file": filename,
        "source": "metadata" if get_metadata(path) == {} else "metadata/filename",
        "dest": os.path.join(artist_dir, album_dir),
    })

# Output report
print(f"\n=== Music Sort Report ===")
print(f"Moved:   {len(moved)} file(s)")
print(f"Skipped: {len(skipped)} file(s)")

if moved:
    print("\nMoved:")
    by_dest = {}
    for m in moved:
        by_dest.setdefault(m["dest"], []).append(m["file"])
    for dest, files in sorted(by_dest.items()):
        print(f"  {dest}/")
        for f in files:
            print(f"    {f}")

if skipped:
    print("\nSkipped:")
    for s in skipped:
        print(f"  {s['file']}: {s['reason']}")
```

## How to run it

Use the Bash tool to execute the script directly:

```bash
python3 << 'SCRIPT'
<paste script content here>
SCRIPT
```

Or save it to a temp file and run it. Either approach is fine.

## Behavior notes

- Only files modified in the **last 2 hours** are processed.
- Metadata (via ffprobe) takes priority over filename parsing.
- Filename parsing expects the pattern: `Artist - Album - [track#] Title.ext`
- Destination: `~/Music/{Artist}/{Album}/filename.ext`
- Duplicate files (same name already exists at destination) are skipped, not overwritten.
- Report what was moved, grouped by Artist/Album.
