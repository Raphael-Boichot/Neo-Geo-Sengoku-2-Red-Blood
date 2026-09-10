# MegaBurner - Python port (command-line only)

Host-side driver for the Arduino Mega "MegaBurner" EEPROM programmer,
ported from the (hardware-confirmed working) Java `SerialHelper.java`.
The Arduino firmware itself (`MegaBurner.ino` / `MX29L3211.cpp`) is
unchanged — this only replicates the same serial protocol from Python.

No GUI. One dependency: **pyserial**.

## Setup

```
pip install -r requirements.txt
```
(or just `pip install pyserial` — it's the only dependency)

## Quick test (the main thing you asked for)

Open `test_megaburner.py`, edit the **CONFIGURATION** block at the top
(at minimum, set `COM_PORT` to your board's port), then run:

```
python test_megaburner.py
```

It will, in order, with a progress bar/spinner for each step:

1. List available serial ports (sanity check).
2. Connect.
3. Check the chip ID against what's expected for `CHIP_NAME`.
4. Erase the whole chip.
5. Prepare test data — either your own ROM file (`USE_RANDOM_DATA =
   False`, reads `ROM_FILE`) or freshly generated random data
   (`USE_RANDOM_DATA = True`, default). Either way it's saved to
   `WRITTEN_FILE` so you always have exactly what was written.
6. Write that data to the chip.
7. Read the same range back and save it to `READBACK_FILE`.
8. Compare CRC32 of written vs. read-back data and print a clear
   **TEST PASSED** / **TEST FAILED** verdict (and exits with code 0/1).

All three files (`ROM_FILE` if used, `WRITTEN_FILE`, `READBACK_FILE`)
live next to the script itself, regardless of your current working
directory when you run it.

Every step has a generous but finite timeout, so if the hardware stops
responding partway through, the script fails with a clear error message
instead of hanging forever — important since the whole point is to be
able to walk away and come back later.

## Project layout

| File                     | Purpose                                              |
|---------------------------|-------------------------------------------------------|
| `megaburner/driver.py`     | `MegaBurner` class — connect/check/erase/write/read_range/verify. Protocol logic ported 1:1 from `SerialHelper.java`. |
| `megaburner/chips.py`      | Chip definition table (id, capacity, page/block sizes). |
| `megaburner/fileio.py`     | Load/save ROM files, random test-data generator.       |
| `megaburner/progress.py`   | Plain stdlib console progress bar + spinner (no extra deps). |
| `megaburner/exceptions.py` | `CommException`.                                       |
| `test_megaburner.py`       | The all-in-one hardware test script described above.   |

## Using the driver directly (for your own scripts later)

```python
from megaburner import MegaBurner

mb = MegaBurner("MX29L3211")
mb.connect("COM5")
print(mb.check())              # e.g. 'C2F9'
mb.erase()
mb.write(some_bytes)
readback = mb.read_range(len(some_bytes))
mb.disconnect()
```

`MegaBurner` is also a context manager: `with MegaBurner("MX29L3211") as mb: ...` closes the port automatically.

## Supported chips

| Chip | Host `CHIP_NAME` | Arduino `#define` (in `MegaBurner_arduino.ino`) | Notes |
|------|-------------------|--------------------------------------------------|-------|
| MX29L3211 | `"MX29L3211"` | `CHIP_MX29L3211` | Has a real page-buffer program feature; `page_size=128`. |
| MX29LV320E Top-Boot | `"MX29LV320ET"` | `CHIP_MX29LV320E` | Standard single-word program only; `page_size=2` is load-bearing, don't change it. |
| MX29LV320E Bottom-Boot | `"MX29LV320EB"` | `CHIP_MX29LV320E` (same build as Top-Boot) | Same firmware as Top-Boot — only the expected id differs. |

The Arduino side needs a matching firmware build for whichever chip is
physically connected (one `#define` at the top of
`MegaBurner_arduino.ino`, reflash after switching) — the two chips
aren't command-compatible (different unlock addresses, different
program/status-polling behavior), so this isn't just a host-side table
edit for a new chip in general. See `MX29LV320E.h` for the specific
differences from MX29L3211 and why each one was necessary.

## Adding another chip (e.g. MX26LV6420)

1. Get the chip's actual command-set table from its datasheet — don't
   assume it matches MX29L3211 or MX29LV320E. Confirm at minimum:
   unlock addresses, whether it has a page-buffer program feature or
   only single-word program, and how busy/done status is polled
   (fixed address vs. the address being written).
2. Add a chip driver (`.h`/`.ino` pair) on the Arduino side implementing
   whatever that chip's sequences actually are — `MX29LV320E.h`/`.ino`
   are the template to copy and adjust.
3. Add a `#define CHIP_...` block to `MegaBurner_arduino.ino`.
4. Add a `Chip(...)` entry to `megaburner/chips.py` with the right id,
   capacity, and `page_size` (this must match what the chip driver
   actually implements, not be picked independently).

## Protocol reference (unchanged from the Java app)

| Host sends            | Meaning                                                | Device replies |
|-------------------------|-----------------------------------------------------------|-----------------|
| `C`                    | Check chip ID                                              | 4 ASCII hex chars, e.g. `C2F9` |
| `R<block>,<size>`       | Read one block                                              | `<size>` raw bytes |
| `E`                    | Erase whole chip                                            | `%` when done (can take a while) |
| `W<offset>,<page>,<n>`  | Write `n` bytes at `offset`                                 | `&` when ready, then `n` raw bytes are sent, then `%` when done |
