# Neo Geo Sengoku 2 Red Blood
## Open source hack to turn the game to a blood bath

## Why ?

Because I'm pissed not to find the NCI hack publically available. Because the pigeons buying NCI physical cartridge are not the kind of people who opens their fucking treasure to dump it and release the rom. So instead of having an expensive stuff to show on your shelves, you get a free hack here.

Seeing at the tileset and palette, Sengoku 2 was never thought to be uncensored so it's quite a lenghty and complicated hack.

## The steps
- get the palette of every bleeding characters with MAME in debug mode. There is only one palette for each (hopefully).
- Easy situation, there is a vibrant red in the palette, edit and inject the modified tileset with unchanged palette.
- Moderate situation, there is no red in the tileset but there is no palette swap during the game so two colors close togenther will be merged to free a slot for red in the palette of the character. It would go completely unnoticed if you didn’t know.
- Fucked situation, multiple palette swap: I have to cheat and force a red in each palette and a probably a modified tileset. If red is shared with another area, it must appear the less weird as possible.

## The rules
- Only human like characters and main heroes will be considered as blood filled. Anything else (pure demonic entities) will keep weird blood color if any.
- My ultimate goal is to make a physical MVS version by hacking a repro, just for fun.

## How ?

The old way :
- MAME in debug mode to explore the palette ram.
- Custom codes to turn C roms to png and the inverse.
- Gemini / Chatgpt (the less stupid depending on the context) to make fast tools that would take me one day to code.
- MS Paint because this is the best tool ever created.

## Trivias
- Palette are stored in the P rom as it and can easily be modified (stored in 16 bits, big endian)
- Claude Yamamoto palette : [0x0010, 0x7810, 0x0C74, 0x5FC9, 0x5409, 0x1A0F, 0x1F9F, 0x0800, 0x0C00, 0x4F93, 0x0666, 0x7AAA, 0x0EEE, 0x7334, 0x4500, 0x7111];

## Status

For the moment I'm just documenting things and gathering enough data to rebuild both the program and character roms confidently.


