# Neo Geo Sengoku 2 Red Blood
## Open source hack to turn the game into a blood bath

## Current state: WIP

- Documenting the process
- Writing the toolchain
- Nothing to play with apart from Matlab codes

## Why ?

Because I'm pissed not to find the NCI hack publically available. Because the buyers of NCI physical cartridges are not the kind of guys who know how to dump chips and share the roms.

Seeing at the tileset and palettes, it is clear that Sengoku 2 was never thought nor programmed to be easily uncensored. Color palette of current "blood" is just shared with other parts of the tiles so simple palette swaps are far from being enough. There is no single magic byte in the code to shift to a blood mode.

## The steps

- get the palette of every bleeding characters with MAME in debug mode and with a LUA script, thanks to the informations grabbed on Neogeodev website. There is only one palette for each character (hopefully). This is long and tedious but does not require any intelligence. Just play, save, check the LUA outputs, hack the RAM, take notes and reload.
- Easy situation, there is no vibrant red in the tileset but a clever palette swap is not visually shocking, go with a palette swap only in the P ROM only.
- Moderate situation, there is yet a vibrant enough red in the palette and no need for palette swap, edit and inject the modified tileset only on the C ROMs, with unchanged palette.
- Fucked situation, multiple palette swap for the same character: I have to cheat and force a red in each palette at the same position and a modified tileset as well. The mod must stay pleasant to the eye and do not deteriorate too much the initial character design. It's an artistic compromise.

## My rules

- Only human like characters and main heroes will be bleeding. Anything else (pure demonic entities) will keep their original blood color if any.
- The least effort will always be prefered because I do this on my spare time, and basically my spare time is shared between a ton of other projects and non negociable family duties. All the sources been given, more patient people can probably improve the hack.

## How ?

- MAME in debug mode and helped with LUA scripts to explore the palette ram while playing. This is the only tedious step in absence of scripted debuggers fully dedidacted to the Neo Geo (or I guess ?).
- Custom codes to turn C ROMs to png and the inverse. Tileset is edited from a png image with the current character palette, then turned back to C ROM.
- Custom codes to swap palettes in P ROMs.
- Custom codes to generate and chain IPS scripts.
- MS Paint to edit tilesets because this is the best tool ever created.
- Spriter ressources to check for inconsistencies in colors and planning the work.
- Rince and repeat with all characters.
- Make a final IPS script.

I want to maximize the scripting in order to be able to easily come back on errors / bad design later. Some codes or parts of codes were made with A.I. to speed up the process.

## Identified flaws due to the 15 colors per tile limitation

- The redness of blood may vary depending on the compromises made when juggling with palette swap, yet existing satisfying reds, my artistic perception but most of all, my laziness.

## The story

Palette are stored in the P rom as it and can easily be targeted and swapped (stored in 16 bits, big endian). Next is the whole list of (non chronogical) modifications made.

## Regular palettes, main characters

- Stream of blood (boring) **--> DONE**

![](/Palettes/Stream_of_blood_Palette.png)

Alternate palette:

![](/Palettes/Stream_of_blood_Palette_alternate.png)

- Claude Yamamoto (Player 1) **--> TO DO**

![](/Palettes/Claude_Yamamoto_Palette.png)

- Jack Stone (Player 2) **--> TO DO**

![](/Palettes/Jack_Stone_Palette.png)

- Mike Walsh green (player 1) and blue (player 2) **--> TO DO**

![](/Palettes/Mike_Walsh_green_Palette.png)

![](/Palettes/Mike_Walsh_blue_Palette.png)

- Crow Tengu God red (player 1) and green (player 2) **--> TO DO**

![](/Palettes/Crow_Tengu_God_red_Palette.png)

![](/Palettes/Crow_Tengu_God_green_Palette.png)

- Kirimaru red (player 1) and blue (player 2) **--> TO DO**

![](/Palettes/Kirimaru_red_Palette.png)

![](/Palettes/Kirimaru_blue_Palette.png)

## Regular palettes, ennemies of interest

- Puppet Warrior blue, gray, blue and red (+ horse) and orange **--> TO DO**

![](/Palettes/Puppet_Warrior_blue_Palette.png)

![](/Palettes/Puppet_Warrior_gray_Palette.png)

![](/Palettes/Puppet_Warrior_blue_red_Palette.png)

![](/Palettes/Puppet_Warrior_orange_Palette.png)

- Ninja Monk violet, gray and red **--> TO DO**

![](/Palettes/Ninka_Monk_violet_Palette.png)

![](/Palettes/Ninka_Monk_gray_Palette.png)

![](/Palettes/Ninka_Monk_red_Palette.png)

- Sword Guard white, blue, violet and brown **--> DONE**

![](/Palettes/Sword_Guard_white_palette.png)

![](/Palettes/Sword_Guard_blue_palette.png)

![](/Palettes/Sword_Guard_violet_palette.png)

![](/Palettes/Sword_Guard_brown_palette.png)

Alternate palettes:

![](/Palettes/Sword_Guard_white_palette_alternate.png)

![](/Palettes/Sword_Guard_blue_palette_alternate.png)

![](/Palettes/Sword_Guard_violet_palette_alternate.png)

![](/Palettes/Sword_Guard_brown_palette_alternate.png)

- Giant Blue and red **--> TO DO**

![](/Palettes/Giant_blue_palette.png)

![](/Palettes/Giant_red_palette.png)

- Kunoichi violet and green **--> TO DO**

![](/Palettes/Kunoichi_violet_palette.png)

![](/Palettes/Kunoichi_green_palette.png)

- Axeman red and green **--> TO DO**

![](/Palettes/Axeman_red_palette.png)

![](/Palettes/Axeman_green_palette.png)

- Spearman red and green **--> TO DO**

![](/Palettes/Spearman_red_palette.png)

![](/Palettes/Spearman_green_palette.png)

- Small and big fishes **--> TO DO**

![](/Palettes/Small_fish_palette.png)

![](/Palettes/Big_fish_palette.png)

- Soldier **--> TO DO**

![](/Palettes/Soldier_palette.png)

- Dragon (last level) **--> TO DO**

![](/Palettes/Dragon_palette.png)

## Regular palettes, bosses

Kojiro blue (Boss level 1) and green (anywhere else) **--> TO DO**

![](/Palettes/Kojiro_blue_palette.png)

![](/Palettes/Kojiro_green_palette.png)

Kitsune (Boss level 2) **--> TO DO**

![](/Palettes/Kitsune_palette.png)

Yoshitsune (Boss level 3) **--> TO DO**

![](/Palettes/Yoshitsune_palette.png)

General and Dark Monarch (Bosses level 4) **--> TO DO**

![](/Palettes/General_palette.png)

![](/Palettes/Dark_Monarch_palette.png)

Puppets (Final boss) **--> TO DO**

![](/Palettes/Puppet_1_palette.png)

![](/Palettes/Puppet_2_palette.png)

## Acknowledgments
- The [neogeodev community](https://wiki.neogeodev.org//index.php/Main_Page) in general and [Furrtek](https://github.com/furrtek) in particular. This project made on spare time was only possible because I stood on the shoulders of giants.
- [Matt Greer](https://www.mattgreer.dev/about/) for sharing [hacks and usefull codes](https://github.com/city41/rotary-bobble) about Neo Geo hacking and the very usefull [sprite viewer](https://neospriteviewer.mattgreer.dev/).
- [Spriter ressources](https://www.spriters-resource.com/neo_geo_ngcd/sengoku2/) for the incredible dataset that helped me a lot figuring out which tiles to edit in the tileset.

