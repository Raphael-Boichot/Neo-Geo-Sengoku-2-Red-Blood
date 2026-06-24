# Neo Geo Sengoku 2 Red Blood
## Open source hack to turn the game into a blood bath

## Why ?

Because I'm pissed not to find the NCI hack publically available. Because the buyers of NCI physical cartridges are not the kind of guys who know how to dump chips and share the roms.

Seeing at the tileset and palettes, Sengoku 2 was never thought nor programmed to be uncensored. Color palette of current "blood" is just shared with other parts of the tiles so a simple palette swap is far from being enough. There is no single magic byte in the code to shift to a blood mode.

## The steps

- get the palette of every bleeding characters with MAME in debug mode, thanks to the informations grabbed on Neogeodev website. There is only one palette for each character (hopefully). This is long and tedious but does not require any intelligence. Just play, save, hack the RAM and reload.
- Easy situation, there is yet a vibrant enough red in the palette and no need for palette swap, edit and inject the modified tileset only on the C ROMs, with unchanged palette.
- Moderate situation, there is no vibrant red in the tileset but a clever palette swap is not visually shocking, go with a palette swap only in the P ROM.
- Fucked situation, multiple palette swap for the same character: I have to cheat and force a red in each palette at the same position and a modified tileset as well. The mod must stay pleasant to the eye and do not deteriorate too much the initial character design. It's an artistic compromise.

## My rules
- Only human like characters and main heroes will be bleeding. Anything else (pure demonic entities) will keep their original blood color if any.
- The least effort will always be prefered because I do this on my spare time, and basically my spare time is shared between a ton of other projects and non negociable duties. All the sources been given, more patient people can probably improve the hack.

## How ?

- MAME in debug mode to explore the palette ram after address 0x0400000 of the 68k mapped memory. I basically hand modify the memory bytes until the tiles I want are changing color. This is the only tedious step in absence of scripted debuggers fully dedidacted to the Neo Geo.
- Custom codes to turn C ROMs to png and the inverse. Tileset is edited from a png image with the current character palette, then turned back to C ROM.
- Custom codes to swap palettes in P ROMs.
- Custom codes to generate and chain IPS scripts.
- Gemini / Chatgpt in free version (the less stupid depending on the context) to make tools that would render any automation task less tedious.
- MS Paint to edit images because this is the best tool ever created.
- Spriter ressources to check for inconsistencies in colors and planning the work.
- Rince and repeat with all characters.
- Make a final IPS script.

I want to maximize the scripting in order to be able to easily come back on errors / bad design later.

## Trivias

- Palette are stored in the P rom as it and can easily be targeted and swapped (stored in 16 bits, big endian).
- Claude Yamamoto palette 68k memory map range: 0400200-0400210, values: [0x0010, 0x7810, 0x0C74, 0x5FC9, 0x5409, 0x1A0F, 0x1F9F, 0x0800, 0x0C00, 0x4F93, 0x0666, 0x7AAA, 0x0EEE, 0x7334, 0x4500, 0x7111];

![](/Sengoku_2_rom_tests/Claude_Yamamoto_Palette.png)

- Jack Stone palette 68k memory map range: 0400220-0400230, values: [0x0011, 0x7810, 0x0C74, 0x5FC9, 0x6640, 0x6B80, 0x6FF0, 0x3037, 0x638C, 0x3AFF, 0x0666, 0x7AAA, 0x0EEE, 0x7334, 0x4FA0, 0x7111];

![](/Sengoku_2_rom_tests/Jack_Stone_Palette.png)

- Mike Walsh green (ninja) palette 68k memory map range: 0400240-0400250, values: [0x0012, 0x7810, 0x0C74, 0x5FC9, 0x1738, 0x5B8C, 0x3FCF, 0x4700, 0x0C00, 0x4F93, 0x0250, 0x2680, 0x0AD0, 0x6B80, 0x6FF0, 0x7111];

![](/Sengoku_2_rom_tests/Mike_Walsh_green_Palette.png)

- Crow Tengu God red (stick man) palette 68k memory map range: 0400260-0400270, values: [0x0013, 0x7810, 0x0C74, 0x5FC9, 0x0800, 0x0D00, 0x4F64, 0x6551, 0x0AA4, 0x0FF8, 0x7555, 0x7999, 0x0EEE, 0x0A80, 0x2EC0, 0x7111];

![](/Sengoku_2_rom_tests/Crow_Tengu_God_red_Palette.png)

- Kirimaru red (dogo) 68k memory map range: 0400280-0400290, values: [0x0014, 0x4332, 0x4663, 0x4995, 0x3BA6, 0x3DC9, 0x4FFC, 0x0A00 0x0F00, 0x4F90, 0x6770, 0x0AA0, 0x7FF3, 0x099A, 0x6556, 0x7111];

![](/Sengoku_2_rom_tests/Kirimaru_red_Palette.png)

- Mike Walsh blue (ninja) palette 68k memory map range: 0400240-0400250, values: [0x0015, 0x7810, 0x0C74, 0x5FC9, 0x5204, 0x5309, 0x190F, 0x4700, 0x0C00, 0x4F93, 0x0045, 0x138B, 0x29EF, 0x1DA3, 0x6FFB, 0x7111];

![](/Sengoku_2_rom_tests/Mike_Walsh_blue_Palette.png)

- Crow Tengu God green (stick man) palette 68k memory map range: 04002C0-04002D0, values: [0x0016, 0x7810, 0x0C74, 0x5FC9, 0x3040, 0x6281, 0x54E2, 0x6253, 0x52A9, 0x3AFF, 0x7555, 0x7999, 0x0EEE, 0x6870, 0x2CC0, 0x7111];

![](/Sengoku_2_rom_tests/Crow_Tengu_God_green_Palette.png)

- Kirimaru blue (dogo) 68k memory map range: 04002E0-04002F0, values: [0x0017, 0x4332, 0x4663, 0x4995, 0x3BA6, 0x3DC9, 0x4FFC, 0x000C, 0x306E, 0x10DF, 0x6770, 0x0AA0, 0x7FF3, 0x099A, 0x6556, 0x7111];

![](/Sengoku_2_rom_tests/Kirimaru_blue_Palette.png)



- Puppet Warrior blue palette 68k memory map range: 0400940-0400950, values: [0x004A, 0x0660, 0x6AA0, 0x6FF0, 0x0157, 0x029D, 0x14FF, 0x6600, 0x0A10, 0x4F20, 0x3115, 0x6348, 0x558B, 0x59BC, 0x7FFF, 0x0000];

![](/Sengoku_2_rom_tests/Puppet_Warrior_blue_Palette.png)

- Puppet Warrior gray palette 68k memory map range: 0400960-0400970, values: [0x004B, 0x1720, 0x5B62, 0x5FD8, 0x0443, 0x1887, 0x0BBA, 0x7232, 0x0565, 0x09B9, 0x6223, 0x7446, 0x677A, 0x1BBC, 0x1FFF, 0x0000];

![](/Sengoku_2_rom_tests/Puppet_Warrior_gray_Palette.png)

## Status

For the moment I'm just documenting things and gathering enough data to rebuild both the program and character roms confidently. I still wonder how to automate fully the process. I have several ideas though.

## Acknowledgments
- The [neogeodev community](https://wiki.neogeodev.org//index.php/Main_Page) in general and [Furrtek](https://github.com/furrtek) in particular. This project made on spare time was only possible because I stood on the shoulders of giants.

