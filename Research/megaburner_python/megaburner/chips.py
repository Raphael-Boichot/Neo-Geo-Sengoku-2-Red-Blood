"""Chip definitions.

Ported from Chips.java / chips/Chip.java / chips/MX29L3211.java.

To add a new chip (e.g. MX29LV320E, MX26LV6420), add another entry to
CHIPS below. Verify id/capacity/pageSize/readBlock/writeBlock against
the chip's own datasheet first - see README.md "Adding a new chip".
"""

from dataclasses import dataclass


@dataclass(frozen=True)
class Chip:
    name: str
    display_name: str
    id: str          # ASCII id string the firmware's check() command returns
    type: str
    capacity: int     # bytes
    page_size: int     # bytes per page-program cycle
    read_block: int    # bytes per read block command
    write_block: int   # bytes per write block command

    @property
    def read_block_count(self) -> int:
        """Equivalent to Chips.getReadBlockCount() -> capacity / readBlock."""
        return self.capacity // self.read_block


CHIPS = {
    "MX29L3211": Chip(
        name="MX29L3211",
        display_name="   MX29L2311 (C2F9)",
        id="C2F9",
        type="3.3v/32MBit/4MiB",
        capacity=4 * 1024 * 1024,
        page_size=128,
        read_block=4096,
        write_block=4096,
    ),
    # MX29LV320E T/B - 32Mbit (4MiB), 44-pin SOP, Macronix. Confirmed
    # against datasheet PM1575 REV 1.3 (DEC 19 2013). Requires the
    # Arduino firmware built with CHIP_MX29LV320E (see MegaBurner_arduino.ino).
    #
    # page_size=2 is NOT a streaming-chunk tweak - it's load-bearing:
    # this chip only supports standard single-word programming, unlike
    # the MX29L3211's page-buffer feature, so this must stay 2 (one
    # word) or writes will corrupt data. See MX29LV320E.h for why.
    #
    # Top-Boot and Bottom-Boot variants share the same command set and
    # only differ in the low byte of the device ID (A7h Top / A8h
    # Bottom) - hence two table entries below, id only differs.
    "MX29LV320ET": Chip(
        name="MX29LV320ET",
        display_name="   MX29LV320E Top-Boot (C2A7)",
        id="C2A7",
        type="3V/32MBit/4MiB SOP44, Top-Boot",
        capacity=4 * 1024 * 1024,
        page_size=2,
        read_block=4096,
        write_block=4096,
    ),
    "MX29LV320EB": Chip(
        name="MX29LV320EB",
        display_name="   MX29LV320E Bottom-Boot (C2A8)",
        id="C2A8",
        type="3V/32MBit/4MiB SOP44, Bottom-Boot",
        capacity=4 * 1024 * 1024,
        page_size=2,
        read_block=4096,
        write_block=4096,
    ),
}


def get_chip(name: str = "MX29L3211") -> Chip:
    try:
        return CHIPS[name]
    except KeyError as exc:
        raise ValueError(f'Unknown chip "{name}". Known chips: {", ".join(CHIPS)}') from exc
