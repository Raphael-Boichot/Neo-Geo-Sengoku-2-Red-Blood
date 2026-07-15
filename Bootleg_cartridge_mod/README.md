# Making a Cartridge for real

## Do this at your own risk, design currently not validated on my side !

## Steps

- Buy an [Aliexpress repro](https://github.com/Raphael-Boichot/Teardown-of-Neo-Geo-MVS-repros). PRG board always come in one version, CHA may come in two versions.
- Variant 1 is populated with MX26L6420 chip for C ROMS. This chip is impossible to reprogram with el cheapo programmers like the GQ-4x4 or the XGECU T48. On the other hand, the nearly pin compatible MX29LV320 is quite well supported. You of course need a SOP 44 to DIP 44 adapter to flash it. You just need to cut trace to pin 1 and place a bodge wire between pin 1 and VCC to force the chip in read mode.
- The variant 2 is populated with M27C322 one time programmable EPROM but with a very baroque footprint impossible to source. Remoce that shit and reverse back to variant 1, then apply the preceding mod.

That's it. I have no idea if this work for the moment, but on paper, it should.

## Tower of power: GQ-4x4->ADP054 adaptet->DIP 44 to SOP 44 adapter

[](/Bootleg_cartridge_mod/Tower_of_power.jpg)

## The principle: in theory, it should work

[](/Bootleg_cartridge_mod/Drop_in_replacement.png)

## Bootleg PRG board: mount that MX29F1615 on socket and flash it!

[](/Bootleg_cartridge_mod/PRG_top.jfif)

## Bootleg CHA board variant 1: Drop the chip, cut a trace an solder a bodge wire

[](/Bootleg_cartridge_mod/Variant1_CHA_top.jfif)

## Bootleg CHA board variant 2: Reverse back to variant 1 and apply the mod

[](/Bootleg_cartridge_mod/Variant2_CHA_top.jfif)


