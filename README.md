# Neo Geo Sengoku 2 Red Blood
## Open source hack to turn the game into a blood bath

## Why ?

Because I'm pissed not to find the NCI hack publically available. Because the pigeons buying NCI physical cartridges are not the kind of guys who know how to dump chips and release the roms. So instead of having an expensive stuff to show on your shelves, you will get a free hack here.

Seeing at the tileset and palettes, Sengoku 2 was never thought nor programmed to be uncensored. Color palette of current "blood" is just shared  with other parts of the tiles so a simple palette swap is far from being satisfying.

So just to summary,this hack represents a crazy amount of work, guesses and researches.

## The steps
- get the palette of every bleeding characters with MAME in debug mode, thanks to the informations grabbed on Neogeodev website. There is only one palette for each character (hopefully). This is long and tedious but does not require any intelligence.
- Easy situation, there is yet a vibrant enough red in the palette, edit and inject the modified tileset with unchanged palette.
- Moderate situation, there is no vibrant red in the tileset but there is no palette swap during the game so two colors close together can be discretely merged in the tileset to free an entry for red in the palette of the character. It would go completely unnoticed if you didn’t know.
- Fucked situation, multiple palette swap for the same character: I have to cheat and force a red in each palette and a probably modified tileset. If red is shared with another area, it must appear the less weird as possible. It's a compromise, quite rare hopefully.

## My rules
- Only human like characters and main heroes will be bleeding. Anything else (pure demonic entities) will keep their weird blood color if any.
- My ultimate goal is to make a physical MVS version by hacking a repro, just for fun.

## How ?

The old way :
- MAME in debug mode to explore the palette ram after address 0x0400000 of the 68k mapped memory. I basically hand modify the memory bytes until the tiles I want are changing color.
- Custom codes to turn C roms to png and the inverse.
- Gemini / Chatgpt in free version (the less stupid depending on the context) to make tools that would render any automation task less tedious.
- MS Paint to edit images because this is the best tool ever created.
- Spriter ressources to check for inconsistencies in colors and planning the work.

## Trivias
- Palette are stored in the P rom as it and can easily be swapped (stored in 16 bits, big endian)
- Claude Yamamoto palette (little endian): 68k memory map range: 0400200-0400210, value: 0x0010, 0x7810, 0x0C74, 0x5FC9, 0x5409, 0x1A0F, 0x1F9F, 0x0800, 0x0C00, 0x4F93, 0x0666, 0x7AAA, 0x0EEE, 0x7334, 0x4500, 0x7111

![](/Sengoku_2_rom_tests/Claude_Yamamoto_Palette.png)

- Jack Stone palette: 68k memory map range: 0400220-0400230, value: 

## Status

For the moment I'm just documenting things and gathering enough data to rebuild both the program and character roms confidently. I still wonder how to automate fully the process. I have several ideas though.

## Acknowledgments
- The [neogeodev community](https://wiki.neogeodev.org//index.php/Main_Page) in general and [Furrtek](https://github.com/furrtek) in particular. This project made on spare time was only possible because I stood on the shoulders of giants.

