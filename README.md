# macOS External Drive Auto-Sync

Automatically syncs folders from your Mac to an external SSD (or anything really) using `rsync` and `launchd`. The sync runs whenever the drive is connected — no manual steps required.

---

## How It Works

- `launchd` watches `/Volumes` for changes (drive connects/disconnects)
- When triggered, `fileSync.sh` runs and checks if your SSD is mounted
- If mounted, it rsyncs your configured folders to the SSD
- If not mounted, it exits silently
- `ThrottleInterval` prevents the sync looping every few seconds (see gotchas below)
- A log is kept at `~/scripts/sync.log`, pruned automatically to 500 lines

---

## Requirements

- macOS (tested on Ventura / Sonoma)
- `rsync` (included with macOS)
- `/bin/bash` with **Full Disk Access** enabled

---

## Setup

### 1. Clone or download this repo

```bash
git clone https://github.com/casualnomad/macOS-External-Drive-Auto-Sync.git
cd macOS-External-Drive-Auto-Sync
```

### 2. Create the scripts directory and copy the script

```bash
mkdir -p ~/scripts
cp fileSync.sh ~/scripts/fileSync.sh
chmod +x ~/scripts/fileSync.sh
```

### 3. Configure the script

Open `~/scripts/fileSync.sh` and edit the configuration section at the top:

```bash
DRIVE_NAME="External Storage"          # Must match your drive name exactly as shown in Finder
BASE="/Volumes/$DRIVE_NAME/"           # Destination base path on the SSD
```

Then update the sync pairs to match your folders:

```bash
SOURCES=(
    "$HOME/Desktop".      # Modify Source and Destination as required
    "$HOME/Documents"   
    "$HOME/Downloads"    
)

DESTINATIONS=(
    "$BASE/Desktop"
    "$BASE/Documents"
    "$BASE/Downloads"
)
```

`SOURCES[0]` maps to `DESTINATIONS[0]`, and so on. Comment out pairs with `#` to disable them.

### 4. Grant Full Disk Access

Go to **System Settings → Privacy & Security → Full Disk Access** and add:

| Binary | Path |
|--------|------|
| bash | `/bin/bash` |

> **Tip:** In any macOS file picker, press **Cmd+Shift+G** to type a path directly — useful for navigating to `/bin/` and `/usr/bin/` which aren't browsable normally.

### 5. Test the script manually

With your SSD plugged in:

```bash
bash ~/scripts/fileSync.sh
cat ~/scripts/fileSync.log
```

Make sure files appeared on the external drive before continuing.

### 6. Install the launchd agent

Open `com.user.syncssd.plist` and replace `YOURUSERNAME` with your actual macOS username:

```bash
whoami  # prints your username
```

Copy it to LaunchAgents and load it:

```bash
cp com.user.syncssd.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.user.syncssd.plist
```

Verify it loaded:

```bash
launchctl list | grep syncssd
```

---

## Testing

Unplug your external drive, plug it back in, wait ~15 seconds, then check:

```bash
cat ~/scripts/fileSync.log
```

Watch it live:

```bash
tail -f ~/scripts/fileSync.log
```

---

## Understanding the Log Output

A typical successful sync looks like this:

```
Fri 27 Feb 2026 23:54:06 NZDT: ========== Sync started ==========
Fri 27 Feb 2026 23:54:06 NZDT: Syncing /Users/USERNAME/Desktop/ -> /Volumes/ExternalStorage/Desktop/
Transfer starting: 70 files
./
newfile.zip
sent 607682031 bytes  received 48 bytes  174315733 bytes/sec
total size is 1927817524  speedup is 3.17
Fri 27 Feb 2026 23:54:06 NZDT: OK — /Users/USERNAME/Desktop/
Fri 27 Feb 2026 23:54:06 NZDT: ========== Sync complete ==========
```

| Field | Meaning |
|-------|---------|
| `Transfer starting: 70 files` | Total files scanned |
| `newfile.zip` | Only this file actually changed |
| `sent 607MB` | Size of changed files transferred |
| `total size is 1.9GB` | Total size of your folder |
| `speedup is 3.17` | rsync was 3x faster than a full copy (low = big file transferred) |
| `speedup is 228,410` | rsync skipped almost everything — nothing changed |

A high speedup means delta sync is working perfectly. A low speedup means a large file was actually transferred.

---

## Useful Commands

```bash
# Unload the agent (disable)
launchctl unload ~/Library/LaunchAgents/com.user.syncssd.plist

# Reload after making changes to the plist
launchctl unload ~/Library/LaunchAgents/com.user.syncssd.plist
launchctl load ~/Library/LaunchAgents/com.user.syncssd.plist

# Run sync manually
bash ~/scripts/fileSync.sh

# Watch log live
tail -f ~/scripts/fileSync.log

# Check drives currently mounted
ls /Volumes/

# Check launchd agent status
launchctl list | grep syncssd
```

---

## Gotchas

**Sync runs in an infinite loop every 10 seconds**

This happens because the sync client is writing files to the destinstaion, which triggers changes to `/Volumes`, which re-triggers launchd, which runs rsync again, forever. The `ThrottleInterval` key in the plist prevents this by enforcing a minimum delay between runs. Default is 600 seconds (10 minutes). Adjust in the plist:

```xml
<key>ThrottleInterval</key>
<integer>600</integer>
```

**Permission errors — "Operation not permitted"**

Make sure `/bin/bash` has Full Disk Access permissions. Missing any one of them causes this error, even if the others are granted.

**Drive format — exFAT or FAT32**

NOTE: This has only been tested with APFS volumes. If your external drive is formatted as exFAT or FAT32, rsync may fail on permission-related flags. Add these flags to the rsync command in the script:

```bash
rsync -av --delete --no-perms --no-owner --no-group \
```

Check your drive format in **Disk Utility** — APFS or Mac OS Extended won't have this issue.

---

## What Gets Excluded

The script automatically skips:

- `.DS_Store` — macOS metadata
- `.localized` — macOS localisation files
- `*.tmp` — temporary files
- `.Spotlight-V100` — Spotlight index
- `.Trashes` — Trash folder

Add more exclusions in `fileSync.sh` by adding `--exclude='pattern'` lines to the rsync command.
