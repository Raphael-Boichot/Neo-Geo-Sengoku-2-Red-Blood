# Red Blood hack for Sengoku 2, Neo Geo AES/MVS and NGCD

## Build your own (current version 1.0)
## For Neo Geo MVS / AES

Go to the dedicated [IPS scripts folder](/Working_toolchain_MVS/IPS_scripts), get a know good dump of Sengoku 2 for MAME, unzip, apply the IPS patch to corresponding files, zip the patched files, enjoy !

Summary of CRC32 you should expect before / after patching :

    File: .\roms\040-c1.c1 | Original CRC32: FAA8EA99 | Modified CRC32: 137B21F9
    File: .\roms\040-c2.c2 | Original CRC32: 87D0EC65 | Modified CRC32: 4AD35858
    File: .\roms\040-c3.c3 | Original CRC32: 24B5BA80 | Modified CRC32: 2D59C0F4
    File: .\roms\040-c4.c4 | Original CRC32: 1C9E9930 | Modified CRC32: 9AAD51A1
    File: .\roms\040-p1.p1 | Original CRC32: 6DDE02C2 | Modified CRC32: 66287B69

## For Neo Geo CD

Get the CD version compatible with the NeoSD Loader, for example [here](https://archive.org/details/fullset-for-neocd-sd-loader). Extract files from the track 1 with any way to mount the .bin file as a directory (like WinCDEmu for example, but amny othet tools may work). Patch the following files with the [dedicated IPS patches](/Working_toolchain_NGCD/IPS_scripts).

Summary of CRC32 you should expect before / after patching :

    File: .\NGCD_track_1\P040.PRG | Original CRC32: DE9334F2 | Modified CRC32: C6126BCF
    File: .\NGCD_track_1\JOUCHU.SPR | Original CRC32: 458CA60B | Modified CRC32: D4E11138
    File: .\NGCD_track_1\AREA2.SPR | Original CRC32: DFC4BFFC | Modified CRC32: 9A9DD451
    File: .\NGCD_track_1\AREA3.SPR | Original CRC32: 6812A91A | Modified CRC32: 963F01DD
    File: .\NGCD_track_1\AREA4.SPR | Original CRC32: 1BB25F6C | Modified CRC32: E0BD0AF3
    File: .\NGCD_track_1\TITLE.SPR | Original CRC32: DDA3971E | Modified CRC32: 98FAFCB3
    
The tricky part is now to rebuilt an [iso level 1 track](https://wiki.neogeodev.org/index.php/Making_an_ISO_file), only format recognized by the NGCD. The recommended way is to use mkisofs with Powershell for example :

    mkisofs -iso-level 1 -pad -N -V "YOUR_VOLUME_NAME" -o output.iso /path/to/patched/files

## Why ?

Sometimes, as a player, you get pissed. I mean really.

Sengoku 2 is one of my prefered video game. It's nervous, it's creepy, it's violent. But it's fucking **CENSORED**. The issue is that I could deal with that in my life until I heard the existence of a red blood hack. That’s a pretty good idea, I thought to myself. Let’s download the ROM (sorry, the patch, I own the original of course) and have fun!

My fun hit a wall rapidely. The blood hack was not released in the public domain. SO, armed with years of hacking Game Boy games and hardware, the marvelous Matlab software that does coffee and Neogeodev documentations, it's was just a matter of time and effort to cook a public version. Basically I began thinking doing the hack seriously in June 2026 and was able to release the first version in July 2026.

I'm just a tinkerer so code disassembly was just not on option. In the other hand I'm educated enough to hack video games in a top-down approach by diving into the RAMs / ROMs structure. Just a bootlegger job basically.

## The steps (or how being ambitious when you have no time)

Seeing at the tileset and palettes, it is clear that Sengoku 2 is not programmed to be easily uncensored like with a magic byte. Color palette of current "blood" is frequently shared with other parts of the tiles so simple palette swaps are far from being satisfying. Basically not a quick and dirty hack. Doing ambitious hacks with work and family requires some planning and building a reliable toolchain. I've sliced the hack in many sub steps in order to be able to work on it by slots of about one hour maximum and easily reverse any fucked situation.

Here are the main steps used in a nutshell:

- first get the palette number of every bleeding characters with MAME in debug mode and with a LUA script, thanks to the informations grabbed on Neogeodev website. There is only one palette for each character (hopefully) and not that many palette reordering between levels. This is long and tedious but does not require any intelligence. Just play, check the LUA outputs, look at the RAM in MAME debug mode to confirm (LUA script has false positives I was not able to fully remove), take notes and reload.
- Easy situation, there is no vibrant red in the tileset but a clever palette swap is not visually shocking, go with a palette swap and target the P ROM only.
- Moderate situation, there is yet a vibrant enough red in the palette and no need for palette swap, edit and inject the modified tileset only on the C ROMs, with unchanged palette.
- Fucked situation, multiple palette swap for the same character and non consistent color to turn to red: I have to cheat and force a red in each palette at the same position and a modified tileset as well. The mod must stay pleasant to the eye and do not deteriorate too much the initial character design. It's my artistic compromise.

## My rules

- Anything looking (even partly) human has red blood. And yes daemon fishes have legs...
- The least effort will always be prefered because I do this on my spare time, and basically my (valuable) spare time is shared between a ton of other projects and non negociable family duties. All the sources been given, more patient people can probably improve the hack.
- The game must look gore but most of all, as genuine as possible.

## Which tools ?

- MAME in debug mode and helped with LUA scripts to explore the palette RAM while playing. This is the only tedious step in absence of scripted debuggers fully dedidacted to the Neo Geo (or I guess ?).
- Custom codes to turn C ROMs to png and the inverse. Tileset is edited from a png image with the current character palette, then turned back to C ROM.
- Custom codes to swap palettes in P ROMs.
- Custom codes to generate and chain IPS scripts.
- Custom codes to convert RGB color to 16 bits Neo Geo colors.
- MS Paint to edit tilesets because this is the best tool ever created on Earth.
- Spriter ressources to check for inconsistencies in colors and planning the work.
- Custom codes to inject the MVS ROM modifications into the NGCD version.
- Rince and repeat with all characters.
- Make a final IPS script for P ROM and C ROMS.

I wanted to maximize the scripting in order to be able to easily come back on errors / bad design later. Some codes or parts of codes were made with A.I. to speed up the process (Gemini mainly, a pinch of Claude too for the most tricky parts). Basically there is no rocket science here but I must admit that A.I. was precious to circumvent the scarcity of Neo Geo dedicated editing tool (Yeah, I know, it’s evil, it kills the planet and all of that). We are clearly addressing a niche market here. 

The Neo Geo CD hack was made in parallel to the MVS version as it is not more difficult to do on any of the systems. Except that the Neo Geo CD is scarcely documented (The only interesting source is a [Neo Geo CD World article](https://www.neogeocdworld.info/html/fiche/hard.htm) by Furrtek), so I was basically on my own most of the time for the file formatting details.

## Identified flaws due to the 15 colors per tile limitation

The 15 colors limit per tile was surprisingly frustrating. The redness of blood may vary depending on the compromises made when juggling with palette swap, yet existing satisfying reds, my artistic perception but most of all, my laziness. Overall, the game is now more reddish. 

I've reused at most the existing tones present in the original palette to avoid travesting the designer intention.

It fits well with the game anyways.

## The story

Palette are stored in the P rom as it and can easily be targeted and swapped with a basic code (stored in 16 bits, big endian). Next is the whole list of (non chronogical) modifications made.

## Regular and modified palettes, main effects

Do not mind the first color rendered here, it is the transparent layer but it also contains the palette number as displayed in RAM (which was very practical for the LUA script). It is rendered as a color or transparency depending on the tool I used to render the palette strip in the repository.

## Regular and modified palettes, main characters

- Damage flickering **--> Palette swap only**

![](/Palettes/Flashing_Effect_Palette.png)

Alternate palette:

![](/Palettes/Flashing_Effect_Palette_alternate.png)

- Stream of blood (boring) **--> Palette swap only**

![](/Palettes/Stream_of_blood_Palette.png)

Alternate palette:

![](/Palettes/Stream_of_blood_Palette_alternate.png)

- Claude Yamamoto (Player 1) **--> Tileset editing only**

![](/Palettes/Claude_Yamamoto_Palette.png)

- Jack Stone (Player 2) **--> Palette swap and tileset editing**

![](/Palettes/Jack_Stone_Palette.png)

Alternate palette:

![](/Palettes/Jack_Stone_Palette_alternate.png)

- Mike Walsh green (player 1) and blue (player 2) **--> Tileset editing only**

![](/Palettes/Mike_Walsh_green_Palette.png)

![](/Palettes/Mike_Walsh_blue_Palette.png)

- Crow Tengu God red (player 1) and green (player 2) **--> Palette swap and tileset editing**

![](/Palettes/Crow_Tengu_God_red_Palette.png)

![](/Palettes/Crow_Tengu_God_green_Palette.png)

Crow Tengu (player 2) alternate palette

![](/Palettes/Crow_Tengu_God_green_Palette_alternate.png)

- Kirimaru red (player 1) and blue (player 2) **--> Palette swap and tileset editing**

![](/Palettes/Kirimaru_red_Palette.png)

![](/Palettes/Kirimaru_blue_Palette.png)

Kirimaru (player 2) alternate palette

![](/Palettes/Kirimaru_blue_palette_alternate.png)

## Regular and modified palettes, ennemies of interest

- Puppet Warrior blue, gray, blue and red (+ horse) and orange **--> Palette swap and tileset editing**

![](/Palettes/Puppet_Warrior_blue_Palette.png)

![](/Palettes/Puppet_Warrior_gray_Palette.png)

![](/Palettes/Puppet_Warrior_blue_red_Palette.png)

![](/Palettes/Puppet_Warrior_orange_Palette.png)

Puppet warriors alternate palettes

![](/Palettes/Puppet_Warrior_blue_Palette_alternate.png)

![](/Palettes/Puppet_Warrior_gray_Palette_alternate.png)

![](/Palettes/Puppet_Warrior_orange_Palette_alternate.png)

- Ninja Monk violet, gray and red **--> Palette swap and tileset editing**

![](/Palettes/Ninka_Monk_violet_Palette.png)

![](/Palettes/Ninka_Monk_gray_Palette.png)

![](/Palettes/Ninka_Monk_red_Palette.png)

Ninka monks alternate palettes

![](/Palettes/Ninka_Monk_violet_Palette_alternate.png)

![](/Palettes/Ninka_Monk_gray_Palette_alternate.png)

![](/Palettes/Ninka_Monk_red_Palette_alternate.png)

- Sword Guard white, blue, violet and brown **--> Palette swap only**

![](/Palettes/Sword_Guard_white_palette.png)

![](/Palettes/Sword_Guard_blue_palette.png)

![](/Palettes/Sword_Guard_violet_palette.png)

![](/Palettes/Sword_Guard_brown_palette.png)

Alternate palettes:

![](/Palettes/Sword_Guard_white_palette_alternate.png)

![](/Palettes/Sword_Guard_blue_palette_alternate.png)

![](/Palettes/Sword_Guard_violet_palette_alternate.png)

![](/Palettes/Sword_Guard_brown_palette_alternate.png)

- Giant red and blue **--> Palette swap and tileset editing**

![](/Palettes/Giant_red_palette.png)

![](/Palettes/Giant_blue_palette.png)

Giant blue alternate palette

![](/Palettes/Giant_blue_palette_alternate.png)

- Kunoichi violet and green **--> Palette swap and tileset editing**

![](/Palettes/Kunoichi_violet_palette.png)

![](/Palettes/Kunoichi_green_palette.png)

Alternate palettes

![](/Palettes/Kunoichi_violet_palette_alternate.png)

![](/Palettes/Kunoichi_green_palette_alternate.png)

- Axeman red and green **--> Palette swap and tileset editing**

![](/Palettes/Axeman_red_palette.png)

![](/Palettes/Axeman_green_palette.png)

Alternate palettes

![](/Palettes/Axeman_red_palette_alternate.png)

![](/Palettes/Axeman_green_palette_alternate.png)

- Spearman green and red **--> Palette swap and tileset editing**

![](/Palettes/Spearman_green_palette.png)

![](/Palettes/Spearman_red_palette.png)

Alternate palette (red)

![](/Palettes/Spearman_red_palette_alternate.png)

- Small and big fishes **--> Palette swap and tileset editing**

![](/Palettes/Small_fish_palette.png)

![](/Palettes/Big_fish_palette.png)

Alternate palette (big fish)

![](/Palettes/Big_fish_palette_alternate.png)

- Soldier **--> Palette swap and tileset editing**

![](/Palettes/Soldier_palette.png)

Alternate palette

![](/Palettes/Soldier_palette_alternate.png)

- Dragon (last level) **--> Tileset editing only**

![](/Palettes/Dragon_palette.png)

## Regular and modified palettes, bosses

Kojiro blue (Boss level 1) and green (anywhere else) **--> Palette swap and tileset editing**

![](/Palettes/Kojiro_blue_palette.png)

![](/Palettes/Kojiro_green_palette.png)

Alternate palette

![](/Palettes/Kojiro_green_palette_alternate.png)

Kitsune (Boss level 2) **--> Tileset editing only**

![](/Palettes/Kitsune_palette.png)

Yoshitsune (Boss level 3) **--> Palette swap and tileset editing**

![](/Palettes/Yoshitsune_palette.png)

Alternate palette

![](/Palettes/Yoshitsune_palette_alternate.png)

Dark Monarch and General (Bosses level 4) **--> Palette swap and tileset editing**

![](/Palettes/Dark_Monarch_palette.png)

![](/Palettes/General_palette.png)

Aternate palette (General)

![](/Palettes/General_palette_alternate.png)

Puppets (Final boss) **--> Palette swap and tileset editing**

![](/Palettes/Puppet_1_palette.png)

![](/Palettes/Puppet_2_palette.png)

Aternate palette (puppet 2)

![](/Palettes/Puppet_2_palette_alternate.png)

## Acknowledgments
- The [neogeodev community](https://wiki.neogeodev.org//index.php/Main_Page) in general and [Furrtek](https://github.com/furrtek) in particular. This project made on spare time was only possible because I stood on the shoulders of giants.
- [Matt Greer](https://www.mattgreer.dev/about/) for sharing [hacks and usefull codes](https://github.com/city41/rotary-bobble) about Neo Geo hacking and the very usefull [sprite viewer](https://neospriteviewer.mattgreer.dev/).
- [Spriter ressources](https://www.spriters-resource.com/neo_geo_ngcd/sengoku2/) for the incredible dataset that helped me a lot figuring out which tiles was where to "easily" edit in the tileset.

