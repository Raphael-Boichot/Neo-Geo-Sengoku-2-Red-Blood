# Making a cartridge for real, WIP

## Do this at your own risk, design currently not validated on my side !

A bootleg costs about 70€ shipped on Aliexpress, this is the price of trusting somebody who knows nothing in electronics if you lost your money! This is not a straighforward mod as bootleggers take a perverse pleasure in recycling the worst possible chips in terms of compatibility or footprint.

## Steps

- Buy an [Aliexpress Sengoku 2 repro](https://github.com/Raphael-Boichot/Teardown-of-Neo-Geo-MVS-repros). Modding a genuine Sengoku 2 MVS / AES is not an option if you are of sound mind. PRG board always come in one version, CHA may come in two versions.
- Variant 1 is populated with two MX26L6420 chips for C ROMs. This chip is just impossible to reprogram with el cheapo programmers like the GQ-4x4 or the XGECU T48 (only possibility is to [read it by tricking the programmer](https://www.arcade-projects.com/threads/making-a-mx26l6420-adapter-top3000-for-naomi-cart-converts.16086/)). You are cheap so you will just remove them with hot air and trash them. On the other hand, the nearly pin compatible MX29LV320 is quite well supported and common. You of course need a SOP 44 to DIP 44 adapter to flash it. You just need to cut trace to pin 1 and place a bodge wire between pin 1 and VCC to force the chip in read mode. **For the moment I have no idea how the ROM files must be organized on the remaining 4 MBytes of the low bank, must investigate.**
- The variant 2 is populated with M27C322 one time programmable EPROM but with a very baroque footprint impossible to source (compact DIP or something like this, completely obsolete, sockets impossible to find). Remove that shit with hot air and reverse back to variant 1 with bridges, then apply the preceding procedure.
- Flashing the PRG board just requires removing P1 and mounting in on socket and it's a pain in the arse without desoldering pump but I guess you know what you are doing, right ?

**I still need to read the MX26L6420 to understand how the 4 MAME roms are flashed on the two chips and confirm that the mod is doable with MX29LV320 chips.**

## Tower of power required: GQ-4x4->ADP-054 adapter->DIP 44 to SOP 44 adapter

![](/Bootleg_cartridge_mod/Tower_of_power.jpg)

## The principle: in theory, it ~~should~~ must work

![](/Bootleg_cartridge_mod/Drop_in_replacement.png)

Pin 1 of the MX26L6420 (C ROMs) is triggered by a LS143 to access data up to 4 MBytes, I guess for bankswitching bigger games, the CHA board being a universal bootleg platform. Here on the MX29LV320 (4 MBytes), nothing is supposed to be bankswitched because pin 1 must always be HIGH to put the chip in read mode. So only way to do this is to cut the trace between the LS174 and pin 1 and connect pin 1 to VCC (3.3V here). Hopefully, all pins 1 of C ROMs are at the same level so you can make connection where you want. Rapid testing on the cartridge showed that Sengoku 2 never tries to access the high bank (A21 stays always low).

## Bootleg PRG board: mount that MX29F1615 on socket and flash it!

![](/Bootleg_cartridge_mod/PRG_top.jfif)

## Bootleg CHA board variant 1: drop the chip, cut a trace and solder a bodge wire

![](/Bootleg_cartridge_mod/Variant1_CHA_top.jfif)

## Bootleg CHA board variant 2: Reverse back to variant 1 and apply the mod

![](/Bootleg_cartridge_mod/Variant2_CHA_top.jfif)

Mod not working ? Take the chips back from the garbage and restore your initial configuration, it should work again if the chips were not burnt during desoldering. 
