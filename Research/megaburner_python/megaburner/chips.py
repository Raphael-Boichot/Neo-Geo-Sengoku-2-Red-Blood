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
}


def get_chip(name: str = "MX29L3211") -> Chip:
    try:
        return CHIPS[name]
    except KeyError as exc:
        raise ValueError(f'Unknown chip "{name}". Known chips: {", ".join(CHIPS)}') from exc
