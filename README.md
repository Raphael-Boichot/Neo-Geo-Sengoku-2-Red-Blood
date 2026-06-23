# Neo Geo Sengoku 2 Red Blood
## Open source hack to turn the game into a blood bath

## Why ?

Because I'm pissed not to find the NCI hack publically available. Because the buyers of NCI physical cartridges are not the kind of guys who know how to dump chips and share the roms.

Seeing at the tileset and palettes, Sengoku 2 was never thought nor programmed to be uncensored. Color palette of current "blood" is just shared with other parts of the tiles so a simple palette swap is far from being enough. There is no single magic byte in the code to shift to a blood mode.

## The steps

- get the palette of every bleeding characters with MAME in debug mode, thanks to the informations grabbed on Neogeodev website. There is only one palette for each character (hopefully). This is long and tedious but does not require any intelligence. Just play, save, hack the RAM and reload.
- Easy situation, there is yet a vibrant enough red in the palette, edit and inject the modified tileset only on the C ROMs, with unchanged palette.
- Moderate situation, there is no vibrant red in the tileset but a clever palette swap is not visually shocking, go with a palette swap in the P ROM.
- Fucked situation, multiple palette swap for the same character: I have to cheat and force a red in each palette and a probably modified tileset as well. If red is shared with another area, it must appear the less weird as possible. It's a compromise that must not change the feeling when playing the game.

## My rules
- Only human like characters and main heroes will be bleeding. Anything else (pure demonic entities) will keep their original blood color if any.
- The least effort will always be prefered because I do this on my spare time, and basically my spare time is shared between a ton of other projects and non negociable duties. All the sources been given, more patient people can probably improve the hack.
- Primary target: MVS version. AES not my priority (maybe one day).

## How ?

- MAME in debug mode to explore the palette ram after address 0x0400000 of the 68k mapped memory. I basically hand modify the memory bytes until the tiles I want are changing color. This is the only tedious step in absence of debuggers fully dedidacted to the Neo Geo.
- Custom codes to turn C ROMs to png and the inverse. Tileset is edited from a png image with the current character palette, then turned back to C ROM.
- Custom codes to swap palettes in P ROMs.
- Custom codes to generate and chain IPS scripts.
- Gemini / Chatgpt in free version (the less stupid depending on the context) to make tools that would render any automation task less tedious.
- MS Paint to edit images because this is the best tool ever created.
- Spriter ressources to check for inconsistencies in colors and planning the work.
- Rince and repeat with all characters.
- Make a final IPS script.

I want to maximize the scripting to minimize errors and be able to come back on my own.

## Trivias

- Palette are stored in the P rom as it and can easily be targeted and swapped (stored in 16 bits, big endian).
- Claude Yamamoto palette 68k memory map range: 0400200-0400210, values: [0x0010, 0x7810, 0x0C74, 0x5FC9, 0x5409, 0x1A0F, 0x1F9F, 0x0800, 0x0C00, 0x4F93, 0x0666, 0x7AAA, 0x0EEE, 0x7334, 0x4500, 0x7111];

![](/Sengoku_2_rom_tests/Claude_Yamamoto_Palette.png)

- Jack Stone palette 68k memory map range: 0400220-0400230, values: [0x0011, 0x7810, 0x0C74, 0x5FC9, 0x6640, 0x6B80, 0x6FF0, 0x3037, 0x638C, 0x3AFF, 0x0666, 0x7AAA, 0x0EEE, 0x7334, 0x4FA0, 0x7111];

![](/Sengoku_2_rom_tests/Jack_Stone_Palette.png)

- Puppet Warrior main palette 68k memory map range: 0400960-0400970, values: [0x004B, 0x1720, 0x5B62, 0x5FD8, 0x0443, 0x1887, 0x0BBA, 0x7232, 0x0565, 0x09B9, 0x6223, 0x7446, 0x677A, 0x1BBC, 0x1FFF, 0x0000];

![](/Sengoku_2_rom_tests/Puppet_Warrior_main_Palette.png)

## Status

For the moment I'm just documenting things and gathering enough data to rebuild both the program and character roms confidently. I still wonder how to automate fully the process. I have several ideas though.

## Acknowledgments
- The [neogeodev community](https://wiki.neogeodev.org//index.php/Main_Page) in general and [Furrtek](https://github.com/furrtek) in particular. This project made on spare time was only possible because I stood on the shoulders of giants.

