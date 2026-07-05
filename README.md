# Neo Geo Sengoku 2 Red Blood
## Open source hack to turn the game into a blood bath

## Current state: WIP

- Documenting the process
- Writing the toolchain
- Nothing to play with apart from Matlab codes

## Why ?

Sometimes you get pissed. I mean really.

Sengoku 2 is one of my prefered video game. It's nervous, it's creepy, it's violent. But it's fucking **CENSORED**. The issue is that I could deal with that in my life until I heard the existence of a red blood hack. That’s a pretty good idea, I thought to myself. Let’s download the ROM and have fun!

My fun hit a wall rapidely. The NCI blood hack was a "scammers only" version not released in the public domain and VERY expensive for what it is (probably a 40€ revamped Aliexpress cartridge). Who knows, scammers have no screwdriver nor EPROM programmer anyways.

SO, armed with years of hacking Game Boy games and hardware, the marvelous Matlab software that does coffee and Neogeodev documentations, it's was just a matter of time and effort to cook a public version. Basically I began thinking doing the hack seriously in June 2026 and was able to release the first version in July 2026.

Seeing at the tileset and palettes, it is clear that Sengoku 2 is not programmed to be easily uncensored like with a magic byte. Color palette of current "blood" is frequently shared with other parts of the tiles so simple palette swaps are far from being satisfying.

I'm just a tinkerer so code disassembly was just not on option. In the other hand I'm educated enough to hack video games in a top-down approach by diving into the RAMs / ROMs structure. Just a bootlegger job basically.

## The steps (or how being ambitious when you have no time)

Doing ambitious hacks with work and family requires some planning and building a reliable toolchain. I've sliced the hack in many sub steps in order to be able to work on it by slots of about one hour maximum and easily reverse any fucked situation.

Here are the main steps used in a nutshell:

- first get the palette number of every bleeding characters with MAME in debug mode and with a LUA script, thanks to the informations grabbed on Neogeodev website. There is only one palette for each character (hopefully) and not that many palette reordering between levels. This is long and tedious but does not require any intelligence. Just play, check the LUA outputs, look at the RAM in MAME debug mode to confirm (LUA script has false positives I was not able to fully remove), take notes and reload.
- Easy situation, there is no vibrant red in the tileset but a clever palette swap is not visually shocking, go with a palette swap and target the P ROM only.
- Moderate situation, there is yet a vibrant enough red in the palette and no need for palette swap, edit and inject the modified tileset only on the C ROMs, with unchanged palette.
- Fucked situation, multiple palette swap for the same character and non consistent color to turn to red: I have to cheat and force a red in each palette at the same position and a modified tileset as well. The mod must stay pleasant to the eye and do not deteriorate too much the initial character design. It's my artistic compromise.

## My rules

- Anything looking (even partly) human has red blood. And yes daemon fishes have legs...
- The least effort will always be prefered because I do this on my spare time, and basically my (valuable) spare time is shared between a ton of other projects and non negociable family duties. All the sources been given, more patient people can probably improve the hack.

## which tools ?

- MAME in debug mode and helped with LUA scripts to explore the palette RAM while playing. This is the only tedious step in absence of scripted debuggers fully dedidacted to the Neo Geo (or I guess ?).
- Custom codes to turn C ROMs to png and the inverse. Tileset is edited from a png image with the current character palette, then turned back to C ROM.
- Custom codes to swap palettes in P ROMs.
- Custom codes to generate and chain IPS scripts.
- Custom codes to convert RGB color to 16 bits Neo Geo colors.
- MS Paint to edit tilesets because this is the best tool ever created on Earth.
- Spriter ressources to check for inconsistencies in colors and planning the work.
- Rince and repeat with all characters.
- Make a final IPS script for P ROM and C ROMS.

I wanted to maximize the scripting in order to be able to easily come back on errors / bad design later. Some codes or parts of codes were made with A.I. to speed up the process (Gemini mainly, a pinch of Claude too for the most tricky parts). Basically there is no rocket science here but I must admit that A.I. was precious to circumvent the scarcity of Neo Geo dedicated editing tool (Yeah, I know, it’s evil, it kills the planet and all of that). We are clearly addressing a niche market here. 

The Neo Geo CD hack was made in parallel to the MVS version as it is not more difficult to do on any of the systems. Except that the Neo Geo CD is scarcely documented so I was basically on my own most of the time.

## Identified flaws due to the 15 colors per tile limitation

The 15 colors limit per tile was surprisingly frustrating. The redness of blood may vary depending on the compromises made when juggling with palette swap, yet existing satisfying reds, my artistic perception but most of all, my laziness. Overall, the game is now more reddish. 

I've reused at most the existing tones present in the original palette to avoid travesting the designer intention.

It fits well with the game anyways.

## The story

Palette are stored in the P rom as it and can easily be targeted and swapped with a basic code (stored in 16 bits, big endian). Next is the whole list of (non chronogical) modifications made.

Do not mind the first color, it is the transparent layer but it contains the palette number (which was very practical). It is rendered as a color or transparency depending on the tool I used to render the palette strip.

## Regular and modified palettes, main effects

- Flashing effect when hit (boring) **--> DONE**

![](/Palettes/Flashing_Effect_Palette.png)

Alternate palette:

![](/Palettes/Flashing_Effect_Palette_alternate.png)

## Regular and modified palettes, main characters

- Stream of blood (boring) **--> DONE**

![](/Palettes/Stream_of_blood_Palette.png)

Alternate palette:

![](/Palettes/Stream_of_blood_Palette_alternate.png)

- Claude Yamamoto (Player 1) **--> Palette: DONE, Tilset: TO DO**

![](/Palettes/Claude_Yamamoto_Palette.png)

- Jack Stone (Player 2) **--> Palette: DONE, Tilset: TO DO**

![](/Palettes/Jack_Stone_Palette.png)

Alternate palette:

![](/Palettes/Jack_Stone_Palette_alternate.png)

- Mike Walsh green (player 1) and blue (player 2) **--> TO DO**

![](/Palettes/Mike_Walsh_green_Palette.png)

![](/Palettes/Mike_Walsh_blue_Palette.png)

- Crow Tengu God red (player 1) and green (player 2) **--> TO DO**

![](/Palettes/Crow_Tengu_God_red_Palette.png)

![](/Palettes/Crow_Tengu_God_green_Palette.png)

Crow Tengu (player 2) alternate palette

![](/Palettes/Crow_Tengu_God_green_Palette_alternate.png)

- Kirimaru red (player 1) and blue (player 2) **--> TO DO**

![](/Palettes/Kirimaru_red_Palette.png)

![](/Palettes/Kirimaru_blue_Palette.png)

Kirimaru (player 2) alternate palette

![](/Palettes/Kirimaru_blue_palette_alternate.png)

## Regular and modified palettes, ennemies of interest

- Puppet Warrior blue, gray, blue and red (+ horse) and orange **--> TO DO**

![](/Palettes/Puppet_Warrior_blue_Palette.png)

![](/Palettes/Puppet_Warrior_gray_Palette.png)

![](/Palettes/Puppet_Warrior_blue_red_Palette.png)

![](/Palettes/Puppet_Warrior_orange_Palette.png)

Puppet warriors alternate palettes

![](/Palettes/Puppet_Warrior_blue_Palette_alternate.png)

![](/Palettes/Puppet_Warrior_gray_Palette_alternate.png)

![](/Palettes/Puppet_Warrior_orange_Palette_alternate.png)

- Ninja Monk violet, gray and red **--> TO DO**

![](/Palettes/Ninka_Monk_violet_Palette.png)

![](/Palettes/Ninka_Monk_gray_Palette.png)

![](/Palettes/Ninka_Monk_red_Palette.png)

Ninka monks alternate palettes

![](/Palettes/Ninka_Monk_violet_Palette_alternate.png)

![](/Palettes/Ninka_Monk_gray_Palette_alternate.png)

![](/Palettes/Ninka_Monk_red_Palette_alternate.png)

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

- Giant red and blue **--> TO DO**

![](/Palettes/Giant_red_palette.png)

![](/Palettes/Giant_blue_palette.png)

Giant blue alternate palette

![](/Palettes/Giant_blue_palette_alternate.png)

- Kunoichi violet and green **--> TO DO**

![](/Palettes/Kunoichi_violet_palette.png)

![](/Palettes/Kunoichi_green_palette.png)

Alternate palettes

![](/Palettes/Kunoichi_violet_palette_alternate.png)

![](/Palettes/Kunoichi_green_palette_alternate.png)

- Axeman red and green **--> TO DO**

![](/Palettes/Axeman_red_palette.png)

![](/Palettes/Axeman_green_palette.png)

Alternate palettes

![](/Palettes/Axeman_red_palette_alternate.png)

![](/Palettes/Axeman_green_palette_alternate.png)

- Spearman green and red **--> TO DO**

![](/Palettes/Spearman_green_palette.png)

![](/Palettes/Spearman_red_palette.png)

Alternate palette (red)

![](/Palettes/Spearman_red_palette_alternate.png)

- Small and big fishes **--> TO DO**

![](/Palettes/Small_fish_palette.png)

![](/Palettes/Big_fish_palette.png)

Alternate palette (big fish)

![](/Palettes/Big_fish_palette_alternate.png)

- Soldier **--> TO DO**

![](/Palettes/Soldier_palette.png)

Alternate palette

![](/Palettes/Soldier_palette_alternate.png)

- Dragon (last level) **--> TO DO**

![](/Palettes/Dragon_palette.png)

## Regular and modified palettes, bosses

Kojiro blue (Boss level 1) and green (anywhere else) **--> TO DO**

![](/Palettes/Kojiro_blue_palette.png)

![](/Palettes/Kojiro_green_palette.png)

Alternate palette

![](/Palettes/Kojiro_green_palette_alternate.png)

Kitsune (Boss level 2) **--> TO DO**

![](/Palettes/Kitsune_palette.png)

Yoshitsune (Boss level 3) **--> TO DO**

![](/Palettes/Yoshitsune_palette.png)

Alternate palette

![](/Palettes/Yoshitsune_palette_alternate.png)

Dark Monarch and General (Bosses level 4) **--> TO DO**

![](/Palettes/Dark_Monarch_palette.png)

![](/Palettes/General_palette.png)

Aternate palette (General)

![](/Palettes/General_palette_alternate.png)

Puppets (Final boss) **--> TO DO**

![](/Palettes/Puppet_1_palette.png)

![](/Palettes/Puppet_2_palette.png)

Aternate palette (puppet 2)

![](/Palettes/Puppet_2_palette_alternate.png)

## Acknowledgments
- The [neogeodev community](https://wiki.neogeodev.org//index.php/Main_Page) in general and [Furrtek](https://github.com/furrtek) in particular. This project made on spare time was only possible because I stood on the shoulders of giants.
- [Matt Greer](https://www.mattgreer.dev/about/) for sharing [hacks and usefull codes](https://github.com/city41/rotary-bobble) about Neo Geo hacking and the very usefull [sprite viewer](https://neospriteviewer.mattgreer.dev/).
- [Spriter ressources](https://www.spriters-resource.com/neo_geo_ngcd/sengoku2/) for the incredible dataset that helped me a lot figuring out which tiles was where to "easily" edit in the tileset.

