# Red Blood hack for Sengoku 2, Neo Geo AES / MVS and Neo Geo CD

![](/Sticker.jpg)

## Patching the Neo Geo MVS / AES game (patch 1.1)

Go to the dedicated [IPS scripts folder](/Working_toolchain_MVS/IPS_scripts), get a know good dump of Sengoku 2 for [MAME](https://www.mamedev.org/), unzip, [apply the IPS patch](https://www.marcrobledo.com/RomPatcher.js/) to corresponding files (check the CRC32 just in case), zip the patched files, enjoy !

Summary of CRC32 you should expect before / after patching:

    File: 040-c1.c1 | Original CRC32: FAA8EA99 | Modified CRC32: 837A9EE0
    File: 040-c2.c2 | Original CRC32: 87D0EC65 | Modified CRC32: 6ECB2AFD
    File: 040-c3.c3 | Original CRC32: 24B5BA80 | Modified CRC32: 327E432F
    File: 040-c4.c4 | Original CRC32: 1C9E9930 | Modified CRC32: 4C6D8667
    File: 040-p1.p1 | Original CRC32: 6DDE02C2 | Modified CRC32: 9A8925FE

Dev note: I have no plan to support other ROM formats, MAME being the most common and popular. I guess converters between formats must exist but you're on your own to do this on your particular emulator / SD loader.

## Patching the Neo Geo CD game (patch 1.1)

Get the CD version compatible with the NeoGeo CD SD Loader, for example [here](https://archive.org/details/fullset-for-neocd-sd-loader). It must be a .CUE + .BINs version. Patch the track 1 with the [dedicated IPS patch](/Working_toolchain_NGCD/IPS_scripts) and any [good IPS patcher](https://www.marcrobledo.com/RomPatcher.js/). You may of course check the CRC32 just in case.

Summary of CRC32 you should expect before / after patching:

    File: Sengoku2_Track_01.bin | Original CRC32: 6EFBFA46 | Modified CRC32: 358E1EFA

Dev note: the NeoGeo SD Loader has imposed *de facto* the default "good" Neo Neo CD format (.CUE + .BIN for each track) so I won't try targeting any other exotic one (like .ISO + .MP3). Just patching track 1 from other formats may or may not work depending on their CRC32. You can test the hack with [Raine64](https://www.emu-france.com/emulateurs/6-arcades/61-multi-games/7687-raine-64-bits/#google_vignette) before burning a CD or transfering to SD card.

## Building the whole project at once

Just run this Powershell script from the root of the project:

    Build_project.ps1

Prerequites:
- Matlab is installed (full automation with GNU Octave is possible but ultra slow)
- **/Working_toolchain_MVS/roms/** -> contains all C roms and P rom of Sengoku 2, MAME compatible version.
- **/Working_toolchain_NGCD/NGCD_track_1_files/** -> contains all .SPR and .PRG files extracted from Sengoku 2, Neo Geo SD loader compatible version.
- **/Working_toolchain_NGCD/NGCD_track_1_binary/** -> contains the binary (.bin) of track 1 from Sengoku 2 Neo Neo CD, Neo Geo SD loader compatible version. It must be named **Sengoku2_Track_01.bin** (mandatory).

Resulting hacked files will be in their respective folders:
- **/Working_toolchain_MVS/roms_out/**
- **/Working_toolchain_NGCD/NGCD_track_1_binary/**

As well as the IPS scripts for sharing:
- **/Working_toolchain_MVS/IPS_scripts/**
- **/Working_toolchain_NGCD/IPS_scripts/**

Anything fishy with the hacks ? A bloody tile is missing ? Need for help ? Open an issue !

## Click on image to see bloody action, MVS version
[ ![Click to see gameplay](/Caption.png)](https://www.youtube.com/watch?v=bVQaettOxyM)

## The story so far...

Sometimes, as a player, you get pissed. I mean really.

Sengoku 2 is one of my prefered video game. It's nervous, it's creepy, it's violent. But it's **censored**. The issue is that I could deal with that in my life until I heard the existence of a NCI red blood hack from 2023. That’s a pretty good idea, I thought to myself. Let’s download the ROM (sorry, the IPS patch, piracy is bad, very bad) and have fun!

My fun hit a wall rapidely. The blood hack was not released in the public domain, it looked like a ~~scammer~~ collector only version, released in very small quantities, and only to customers not owning an EPROM dumper or even a screwdriver. SO, armed with years of hacking Game Boy games and hardware, the marvelous Matlab software that does coffee and Neogeodev documentations, it's was just a matter of time and effort (honestly, more than expected initially) to cook a public version. I began thinking doing the hack seriously in June 2026 and was able to release the first version in July 2026. One month from idea to release basically.

I'm just a tinkerer so code disassembly was just not on option. In the other hand I'm educated enough to hack video games in a top-down approach by diving into the RAMs / ROMs structure and use debug modes of emulators. Just a bootlegger job basically.

## Why using Matlab ?

Matlab is my everyday go tool for scientific computing. My job during working hours is to solve engineering problems. Hacking video games is just another class of engineering problem I tackle when I have insomnia. Matlab considers everything as a matrix / vectors, so it is super fast when you keep that particularity in mind when programming. It has zero dependencies. Exactly what I needed here. The very shortest path from my problem to the solution.

There is a free version of Matlab called [GNU Octave](https://octave.org/) that you can try to use to run the toolchain. It will probably work but execution will be suuuuupppeeer slow (like 100x slower) compared to Matlab. Better than nothing though.

## Forewords: Neo Geo RAM palette and tilesets

Working with arcade systems is a very big relief compared to classical game systems from the 90'. Sprites, voices, music, program, and HUD are well organized and separated on different files / chips, clearly identified. No need to search for data or guess anything. The goal of the project here is to make a combo of tileset editing / palette swap. It will require modifying both the tilesets and the main program.

Neo Geo memory is easily accessible from MAME in debug mode. As far as I know, MAME stays the best way to explore Neo Geo memory and code while playing. It allows internal scripting in Lua and basically access / do anything you want within the game by manipulating memory in live.

My first approach was to simply look at the palette RAM in MAME debug mode. It is mapped from [address 0x400000 to 0x401FFF](https://wiki.neogeodev.org/index.php/68k_memory_map). Each palette is composed of 16 words (transparency + 15 colors) [coded in 5 bits per color](https://wiki.neogeodev.org/index.php/Colors). There is 256 palette available at any time during gameplay. Each tile must be assigned to a single palette but a sprite may use all the palettes available. The first 16 palettes are reserved for the fix layer (HUD), but any sprite can call any palette. I don't know if this is particular to Sengoku 2, but the transparency color (palette entry 1) also contains the palette number between 0x00 and 0xFF in its first byte. This was **super** practical to hack the game.

In the particular case of Sengoku 2, there is no huge color palette reorganization between levels. Basically capturing the memory state in attract mode is enough to have 99% of the color used. You can play with palette RAM by manually changing the colors to see any change on screen. It allows basically to build the table of sprite attributes by hand. Finding the palette of each character like this (manually, messing with values in RAM) is barely possible as you basically have to cross check something like 20 characters present at different moments of the gameplay among 256 palettes.

The good approach was to write a [Lua script](/Tools/monitor.lua) that monitors (and plot) the palette associated with everything having a sprite attribute during the whole gameplay. It appears that ALL sprites uses a single palette (that's fortunate !) and that the palette "string" appears in clear in the main program, easy to target so. Lua script has lots of false positive with palette 0x1D during boss fight, not sure why (maybe remnants of sprites not displayed in final version).

So armed with a dump of memory during gameplay, the list of all palette attributed to any sprite, I was ready to began the hack.

## The steps (or how being ambitious when you have no time / no sleep)

Seeing at the tileset and palettes, it is clear that Sengoku 2 is not programmed to be easily uncensored like with a magic byte. Color palette of current "blood" is frequently shared with other parts of the tiles so simple palette swaps are far from being satisfying. Basically not a quick and dirty hack. Doing ambitious hacks with work and family requires some planning and building a reliable toolchain. I've sliced the hack in many sub steps in order to be able to work on it by slots of about one hour maximum and easily reverse any fucked situation.

Here are the main steps used in a nutshell:

- First get the palette number of every bleeding characters with MAME in debug mode and with a Lua script, thanks to the informations grabbed on Neogeodev website. There is only one palette for each character (hopefully) and not that many palette reordering between levels. It required anyway some cross validations due to false positives with palette 0x1D.
- Easy situation, there is no vibrant red in the tileset but a clever palette swap is not visually shocking, go with a palette swap and target the P ROM only.
- Moderate situation, there is yet a vibrant enough red in the palette and no need for palette swap, edit and inject the modified tileset only on the C ROMs, with unchanged palette.
- Fucked situation, multiple palette swap for the same character and non consistent color to turn to red: I have to cheat and force a red in each palette at the same position and a modified tileset as well. The mod must stay pleasant to the eye and do not deteriorate too much the initial character design. It's my artistic compromise.
- Then for each character, repeat the process until reaching the final boss puppets.
- Build the Neo Geo CD version ~~easily and automatically~~ with blood and pain from the MVS version.
- Realize that the HUD palette with character face vignettes is no longer synchronized, that it's impossible to modify because of very strong color constraints, and having to redo part of the work from scratch.

Final adjustments (sometimes bigger than expected) were made by looking closely at gameplay footage during dev, frame by frame to spot any missing tile conversion (only way to see a single pixel missing).

## My rules

- Anything looking (even partly) human has red blood. And yes daemon fishes have human legs...
- The least effort will always be prefered because I do this on my spare time, and basically my (valuable) spare time is shared between a ton of other projects and non negociable family duties. All the sources been given, more patient people can probably improve the hack. In it's current form, it's very easy to spot an issue and correct it.
- The game must look gore but most of all, as genuine as possible. The least modification is always prefered. Apart from being a very hardcore fan of Sengoku 2 like me, you will probably not see any obvious palette swap apart from blood of course.

## Which tools ?

- MAME in debug mode and helped with Lua scripts to explore the palette RAM while playing.
- Custom codes to turn C ROMs to png and the inverse. Tileset is edited by hand from a png image with the current character palette, then turned back to C ROM.
- Custom codes to swap palettes in P ROMs.
- Custom codes to convert RGB color to 16 bits Neo Geo colors.
- MS Paint to edit tilesets because this is the best tool ever created on Earth (and it manages transparent layers). About 500 tiles have been painfully bloodified by hand, pixel per pixel, in the conversion. 
- Spriter ressources to check for inconsistencies in colors and planning the quantity of work.
- Custom NGCD converters, tileset to png and png to tileset, because encoding is different from AES / MVS.
- Custom codes to inject the MVS tileset modifications into the NGCD tileset automatically.
- Custom codes to rebuild the NGCD binary from individual .SPR and .PRG files (this was a pain, see next section).
- IPS script generator for sharing the hack easily.

As for any prject, 10% of the time was taken to edit 90% of the tileset, 90% of the time to find some lone tiles / pixels in the giant tileset.

I wanted to maximize the scripting in order to be able to easily come back on errors / bad design later. Some codes or parts of codes were made / polished / optimized with A.I. (Gemini mainly, sometimes Mistral A.I. because I'm beta tester, a pinch of Claude too for the most tricky parts). Basically there is no rocket science here but I must admit that A.I. was precious to circumvent the scarcity of Neo Geo dedicated editing tool. We are clearly addressing a very niche market here.

The Neo Geo CD hack was made in parallel to the MVS version as it is not more difficult (in fact, it was) to do on any of the systems. Except that the Neo Geo CD is scarcely documented (The only interesting source is a French [Neo Geo CD World article](https://www.neogeocdworld.info/html/fiche/hard.htm)), so I was basically on my own most of the time for the file formatting details.

## Some notes about (painfully and partially) reverse engineering the NGCD file format

First surprise, the Neo Geo CD file format is 16 bit little endian, which required adapting all the conversion tools developped for the MVS ROMs stored in big endian (but converted to little endian at the end in the 68k RAM, do not ask me why). Sprites are not stored de-interlaced compared to the MVS version. They are also stored horizontally flipped compared to MVS but it may be due to my decoder.

Starting confident after this little surprise, I initially though hacking individual files of the NGCD version contained in track 1 and rebuilding an iso from any dedicated tool would be enough. As far as I can tell, it does not work. Even the trusty [neogeodev dedicated page](https://wiki.neogeodev.org/index.php/Making_an_ISO_file) was finally not usefull / enough. Any tool gives me an .iso container too small that makes the Neo Geo CD crash. I was clearly missing something like alignement tricks / error correction / padding.

So I took the problem in reverse. Rebuilding from scratch the exact original ISO 9660 structure as expected by the Neo Geo CD was just out of question, so I tried injecting the individual hacked .SPR and .PRG files directly into the original track 1 binary as big data chunks, by searching for some header signatures. Neo Geo CD crashed again with that "rebuilt" binary, damn! The fact is that I had only like 12% matching between .PRG and .SPR injected and the binary data of track 1 on the same address range, which indicated that the files were probably at least partially splitted within the filesystem. Splitted was a weak word.

Some reader may find the latter approach incredibly naïve but for my defense, I had no idea how Neo Geo CD data tracks were organized before tackling this problem. Let's say that reverse engineering things is becoming for me as fun, if not funnier, than playing video games.

By messing with dedicated tool (and lot of trial and errors), I finally understood the fine data structure: each individual file is splitted in chunks of 2048 bytes (0x800) separated by 304 bytes (0x130) of EDC/ECC data (typically 288 bytes of checksums and other error correction stuff + 16 bytes of header for the next packet). Each sector (header, 16 bytes + payload, 2048 bytes + error correction, 288 bytes) is 2352 bytes long. There is lot of padding sectors too (zero payload but CD sector format) plus alignement / boot sectors. In brief, I should have started by reading the audio CD format specification. Chunks of data seem consecutives for a given file at first glance but at this step I could not trust anything. 

So I wrote a code to inject my hacked .SPR and .PRG files by chunks of 2048 bytes with expected gaps of 304 bytes inbetween. Which was the case, mostly. 2048 bytes is hopefully long enough to have a unique matching in the track 1 binary and target precise address range by comparison, except for redunding padding area. So the trick was to search a sequence in the binary matching a chunk of 2048 bytes from the non hacked original files to build a table of address ranges for each files, then use this address table to inject chunks of the hacked files to their respective range. Of course there is a ton of optimization and tricks to go faster (like dealing with modified chunks only, ignore padding area with low entropy, searching first the next packet 304 bytes further, etc.) but you get the idea: seek and inject 2048 byte chunks at the right place. Some tiles are redundant in several .SPR files so don't forget to take this into account. Typically most of tiles from AREA2.SPR and TITLE.SPR are redunding so chunks of data may have multiple insertion points without this being a false positive.

Cherry on top, for all the hacked chunks reinjected, the following EDC/ECC 288 bytes say that corresponding data are corrupted (of course). So the last step was to regenerate the right EDC/ECC data for each modified chunk with a (hopefully, yet existing) dedicated tool (included in the workflow).

Replace the genuine track 1 by hacked one, run it with a Neo Geo CD SD loader because it is the fastest route from hacking to real hardware for testing. Enjoy your bloody version. I guess there must be a possible workflow starting from the individual files but my solution is working. Better is the enemy of good.

## Click on image to see bloody action, Neo Geo CD version
[ ![Click to see gameplay](/Monkey.jpg)](https://www.youtube.com/watch?v=lhKzlUg3lMo)

First time I'm happy to see this little juggling fucker...

## Identified flaws

The 15 colors limit per tile was surprisingly frustrating. The redness of blood may vary depending on the compromises made when juggling with palette swap, yet existing satisfying reds (more or less brown), my artistic perception but most of all, my laziness. My goal is not to redo the entire tileset. Overall, the game is now more reddish. I reused only the existing colors to keep the designer's original vision intact. I think it fits the game really well.

# History of modifications

Do not mind the first color rendered in the next section, it is the transparent layer but it also contains the palette number as displayed in RAM (which was very practical for the LUA script). It is rendered as a color or transparency depending on the tool I used to render the palette strip in the repository.

## Regular and modified palettes, main effects

- Damage flickering **--> Palette swap only**

![](/Palettes/Flashing_Effect_Palette.png)

Alternate palette:

![](/Palettes/Flashing_Effect_Palette_alternate.png)

- Stream of blood (boring) **--> Palette swap only**

![](/Palettes/Stream_of_blood_Palette.png)

Alternate palette:

![](/Palettes/Stream_of_blood_Palette_alternate.png)

## Regular and modified palettes, main characters

The HUD has a small vignettes with characters face. It has its own palettes, but only 3 are used for the vignettes, and they are not common with the sprites palettes. Whatever the reason, game devs chose to use a single common palette for all P2 vignettes. This basically means that synchronisation of character palette and HUD palette is impossible. The compromise here is so to stay minimal with palette swap for the main characters, blood being the second palette entry (brown), except for Claude Yamamoto. Fun fact, it is closer from real blood color than pure red.

- Claude Yamamoto (Player 1) **--> Tileset editing only**

![](/Palettes/Claude_Yamamoto_Palette.png)

- Jack Stone (Player 2) **--> Tileset editing only**

![](/Palettes/Jack_Stone_Palette.png)

- Mike Walsh green (player 1) and blue (player 2) **--> Tileset editing only**

![](/Palettes/Mike_Walsh_green_Palette.png)

![](/Palettes/Mike_Walsh_blue_Palette.png)

- Crow Tengu God red (player 1) and green (player 2) **--> Tileset editing only**

![](/Palettes/Crow_Tengu_God_red_Palette.png)

![](/Palettes/Crow_Tengu_God_green_Palette.png)

- Kirimaru red (player 1) and blue (player 2) **--> Palette swap and tileset editing**

![](/Palettes/Kirimaru_red_Palette.png)

![](/Palettes/Kirimaru_blue_Palette.png)

Kirimaru (player 1 and 2) alternate palettes

![](/Palettes/Kirimaru_red_palette_alternate.png)

![](/Palettes/Kirimaru_blue_palette_alternate.png)

## Regular and modified palettes, ennemies of interest

For regular foes, palette swap was prioritized. The idea was to be the less visible as possible. I've excluded the idea to merge close colors to free a color slot in the palette. it's too demanding because ALL tiles must be modified accordingly versus like 5-10% with a clever palette swap.

- Puppet Warrior blue, gray, blue and red (+ horse) and orange **--> Palette swap and tileset editing**. Beware, the blue and red (+ horse) version of puppet master has a ton of dedicated tiles to edit compared to the other colors.

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

This one was too easy. Probably a remnant from early development stages were the game was possibly still uncensored.

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

Alternate palette (reds more vibrant)

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

## Funfact

- The Neo Geo CD version seems to contains remnants of codes from Cyber Lip, so I guess that at least some logic from Sengoku 2 P040.PRG was common with that earlier game (probably the logic to split and load levels in the tiny Neo Geo CD memory).

- The sword slashing sound is much more satisfying and violent with AES / MVS version than Neo Geo CD version. It must be not that difficult to restore.

## Final words

I am publishing these workflows in a state far from perfection, to say the least. Throughout my career and my hobbies, I have seen too many projects (good or not, this is not the point here) disappear simply because they were never shared before their authors vanished from the face of the Earth, whatever the reason (brutal death, mental illness, boredom, greed, discord... I've seen all of these). I operate on the principle that if it is not online, it does not exist. I prefer releasing a functional work that is available to everyone than chasing a perfect version that eventually will fade into obscurity rotting on a forgotten hard drive.

As it, the game is very fun and violent, I hope you will enjoy that hack.

## Acknowledgments

- The [neogeodev community](https://wiki.neogeodev.org//index.php/Main_Page) in general and [Furrtek](https://github.com/furrtek) in particular. This project made on spare time was only possible because I stood on the shoulders of giants. The Neo Geo was one of my first consoles (yes, I'm loaded) and I still have a special soft spot for this system, even though the market has become completely insane.
- [Matt Greer](https://www.mattgreer.dev/about/) for sharing [hacks and usefull codes](https://github.com/city41/rotary-bobble) about Neo Geo hacking and the very usefull [sprite viewer](https://neospriteviewer.mattgreer.dev/) that helped me a lot configuring the ROM and SPR decoders.
- [Spriter ressources](https://www.spriters-resource.com/neo_geo_ngcd/sengoku2/) for the incredible dataset that helped me a lot figuring out which tiles was where within the giant game tileset.
- [Alex Free and EDCRE](https://github.com/alex-free/edcre), which basically saved the Neo Geo CD port!

In brief, all the people / communities that rendered this project possible ! 

Below, my very first notes taken around mid june 2026, because every project starts with a scratchpad.

![](/Pen_and_paper.jpg)
