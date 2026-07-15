# Making a cartridge for real

## Do this at your own risk, design currently not validated on my side !

A bootleg costs about 70€ shipped on Aliexpress, this is the price of trusting somebody who knows nothing in electronics if you lost your money !

## Steps

- Buy an [Aliexpress repro](https://github.com/Raphael-Boichot/Teardown-of-Neo-Geo-MVS-repros). Modding a genuine Senoku 2 MVS / AES is not an option if you are of sound mind. PRG board always come in one version, CHA may come in two versions.
- Variant 1 is populated with two MX26L6420 chips for C ROMS. This chip is just impossible to reprogram with el cheapo programmers like the GQ-4x4 or the XGECU T48. You will just remove them with hot air and trash them. On the other hand, the nearly pin compatible MX29LV320 is quite well supported. You of course need a SOP 44 to DIP 44 adapter to flash it. You just need to cut trace to pin 1 and place a bodge wire between pin 1 and VCC to force the chip in read mode. Flash with the ROMS interlaced by byte (two ROMS -> one chip), solder back, that's it.
- The variant 2 is populated with M27C322 one time programmable EPROM but with a very baroque footprint impossible to source (compact DIP or something like this, completely obsolete). Remove that shit with hot air and reverse back to variant 1, then apply the preceding procedure.
- Flashing the PRG board just requires removing P1 and mounting in on socket and it's a pain in the arse but I guess you know what you are doing, right ?

That's it. I have no idea if this work for the moment, but there is no reason it shouldn't.

## Tower of power: GQ-4x4->ADP054 adapter->DIP 44 to SOP 44 adapter

![](/Bootleg_cartridge_mod/Tower_of_power.jpg)

## The principle: in theory, it ~~should~~ must work

![](/Bootleg_cartridge_mod/Drop_in_replacement.png)

## Bootleg PRG board: mount that MX29F1615 on socket and flash it!

![](/Bootleg_cartridge_mod/PRG_top.jfif)

## Bootleg CHA board variant 1: drop the chip, cut a trace and solder a bodge wire

![](/Bootleg_cartridge_mod/Variant1_CHA_top.jfif)

## Bootleg CHA board variant 2: Reverse back to variant 1 and apply the mod

![](/Bootleg_cartridge_mod/Variant2_CHA_top.jfif)


