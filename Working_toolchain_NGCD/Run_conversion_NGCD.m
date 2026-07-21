clear
warning off

disp('The working palette is Matlab jet by default, better not try changing it !')
disp('The NGCD Version is rebuilt from the MVS version, entirely by scripting')
disp('Don''t forget to copy paste the required files (.bin track, files into the track, png tileset from MVS)')
disp('The code will just crash in case any file is missing somewhere!')
%% Init section

% general settings
mkdir('.\roms_out\');
mkdir('.\tileset_out\');
mkdir('.\IPS_scripts\');
dummy_palette_jet =[0x1005, 0x1008, 0x100D, 0x303F, 0x308F, 0x30DF, 0xF3FB, 0xF7F7, 0xFCF2, 0xEFF0, 0xEFA0, 0xEF50, 0xEF00, 0xCB00, 0xC700, 0xC400];
disp('Initialization completed')

%% Transforms the pair of roms in png tileset + palette image to check
% Cspt_to_png is aggressively using matrix/vector formalism
% some .SPR files do not contain modified tiles but I let them just in case
disp('Building the reference tileset in png from jet palette vector')
Cspr_to_png('.\NGCD_track_1_files\JOUCHU.SPR',dummy_palette_jet, '.\tileset_out\JOUCHU.png', '.\tileset_out\JOUCHU_exchange_palette.txt')
Cspr_to_png('.\NGCD_track_1_files\\AREA1.SPR',dummy_palette_jet, '.\tileset_out\AREA1.png', '.\tileset_out\AREA1_exchange_palette.txt')
Cspr_to_png('.\NGCD_track_1_files\AREA2.SPR',dummy_palette_jet, '.\tileset_out\AREA2.png', '.\tileset_out\AREA2_exchange_palette.txt')
Cspr_to_png('.\NGCD_track_1_files\AREA3.SPR',dummy_palette_jet, '.\tileset_out\AREA3.png', '.\tileset_out\AREA3_exchange_palette.txt')
Cspr_to_png('.\NGCD_track_1_files\AREA4.SPR',dummy_palette_jet, '.\tileset_out\AREA4.png', '.\tileset_out\AREA4_exchange_palette.txt')
Cspr_to_png('.\NGCD_track_1_files\STAFF.SPR',dummy_palette_jet, '.\tileset_out\STAFF.png', '.\tileset_out\STAFF_exchange_palette.txt')
Cspr_to_png('.\NGCD_track_1_files\TITLE.SPR',dummy_palette_jet, '.\tileset_out\TITLE.png', '.\tileset_out\TITLE_exchange_palette.txt')
%///////////////section to comment to edit tileset//////////////////

%% Section to inject modified tileset from MVS into NGCD
Tileset_injector() % use the MVS tileset to modify the NGCD tileset, only use dummy palette for NGCD conversion
% if any tile is not found, there is an error message

%% Transforms the png back to pair of C ROMS based on current palette.txt
% png_to_Cspr is aggressively using matrix/vector formalism too
disp('Building back modified .SPR files from png tilesets and palette.txt')
png_to_Cspr('.\roms_out\JOUCHU.SPR','.\tileset_out_modified\JOUCHU.png','.\tileset_out\JOUCHU_exchange_palette.txt')
png_to_Cspr('.\roms_out\AREA1.SPR','.\tileset_out_modified\AREA1.png','.\tileset_out\AREA1_exchange_palette.txt')
png_to_Cspr('.\roms_out\AREA2.SPR','.\tileset_out_modified\AREA2.png','.\tileset_out\AREA2_exchange_palette.txt')
png_to_Cspr('.\roms_out\AREA3.SPR','.\tileset_out_modified\AREA3.png','.\tileset_out\AREA3_exchange_palette.txt')
png_to_Cspr('.\roms_out\AREA4.SPR','.\tileset_out_modified\AREA4.png','.\tileset_out\AREA4_exchange_palette.txt')
png_to_Cspr('.\roms_out\STAFF.SPR','.\tileset_out_modified\STAFF.png','.\tileset_out\STAFF_exchange_palette.txt')
png_to_Cspr('.\roms_out\TITLE.SPR','.\tileset_out_modified\TITLE.png','.\tileset_out\TITLE_exchange_palette.txt')

%% Injects new palettes in P ROMs
% it's a seek and replace sequence based algorithm, it avoids me to do this by hand with hex editor
disp('Targeting and injecting new palette(s) in .PRG')
PRomFile = '.\roms_out\P040.PRG';
copyfile('.\NGCD_track_1_files\P040.PRG','.\roms_out\P040.PRG','f');
fid = fopen(PRomFile, 'rb'); %load file into memory and work with it locally
PROMdata = fread(fid, inf, 'uint8=>uint8');
fclose(fid);

% Boring blood vs vibrant blood, several foes
disp('------------Swapping blood splashings palette--------------------')
palette_old = [0x0070, 0x0660, 0x6AA0, 0x0DD0, 0x6EE0, 0x7FF4, 0x6FFA, 0x7FFF, 0x0000, 0x7154, 0x3275, 0x2398, 0x36B9, 0x47EB, 0x7BFE, 0x7FFF]; % stream of boring blood, many ennemies
palette_new = [0x0070, 0x2812, 0x2912, 0x6A12, 0x0B00, 0x0C00, 0x0D00, 0x0E00, 0x0000, 0x7154, 0x3275, 0x2398, 0x36B9, 0x47EB, 0x7BFE, 0x7FFF]; % stream of blood, gradation of intense reds
[PROMdata] = PRG_Palette_injector(PROMdata,palette_old,palette_new);

% Boring flashing effect, everyone, white to vibrant red
disp('------------Swapping flashing damage palette---------------------')
palette_old = [0x0001, 0x7FFF, 0x7FFF, 0x7FFF, 0x7FFF, 0x7FFF, 0x7FFF, 0x7FFF, 0x7FFF, 0x7FFF, 0x7FFF, 0x7FFF, 0x7FFF, 0x7FFF, 0x7FFF, 0x7FFF]; % general flashing effect when hit
palette_new = [0x0001, 0x4F00, 0x4F00, 0x4F00, 0x4F00, 0x4F00, 0x4F00, 0x4F00, 0x4F00, 0x4F00, 0x4F00, 0x4F00, 0x4F00, 0x4F00, 0x4F00, 0x4F00]; % general flashing effect when hit, red
[PROMdata] = PRG_Palette_injector(PROMdata,palette_old,palette_new);

% Jack Stone (player 2) / DISMISSED, interacts too much with HUD palette
% disp('------------Swapping Jack Stone (player 2) palette---------------')
% palette_old = [0x0011, 0x7810, 0x0C74, 0x5FC9, 0x6640, 0x6B80, 0x6FF0, 0x3037, 0x638C, 0x3AFF, 0x0666, 0x7AAA, 0x0EEE, 0x7334, 0x4FA0, 0x7111]; % Jack Stone (Player 2)
% palette_new = [0x0011, 0x7810, 0x0C74, 0x5FC9, 0x6640, 0x6B80, 0x6FF0, 0x0800, 0x0C00, 0x4F93, 0x0666, 0x7AAA, 0x0EEE, 0x7334, 0x4FA0, 0x7111]; % Jack Stone (Player 2), blue becomes red
% [PROMdata] = PRG_Palette_injector(PROMdata,palette_old,palette_new);

% Kirimaru (Player 2) / DISMISSED, interacts too much with HUD palette
% disp('------------Swapping Kirimaru (player 2) palette-----------------')
% palette_old = [0x0017, 0x4332, 0x4663, 0x4995, 0x3BA6, 0x3DC9, 0x4FFC, 0x000C, 0x306E, 0x10DF, 0x6770, 0x0AA0, 0x7FF3, 0x099A, 0x6556, 0x7111]; % Kirimaru (doggo, blue, player 2)
% palette_new = [0x0017, 0x6940, 0x0C70, 0x4EA0, 0x6FD0, 0x5FF5, 0x4FFC, 0x0A00, 0x0F00, 0x4F90, 0x6770, 0x0AA0, 0x7FF3, 0x099A, 0x6556, 0x7111]; % Kirimaru (doggo, red, blonde fur, player 2)
% [PROMdata] = PRG_Palette_injector(PROMdata,palette_old,palette_new);

% Kirimaru (Player 1 - test)
disp('------------Swapping Kirimaru (player 1) palette-----------------')
palette_old = [0x0014, 0x4332, 0x4663, 0x4995, 0x3BA6, 0x3DC9, 0x4FFC, 0x0A00, 0x0F00, 0x4F90, 0x6770, 0x0AA0, 0x7FF3, 0x099A, 0x6556, 0x7111]; % Kirimaru (doggo, red, player 1)
palette_new = [0x0014, 0x0810, 0x0A42, 0x0C74, 0x0D96, 0x0FC9, 0x4FFC, 0x0A00, 0x0F00, 0x4F90, 0x6770, 0x0AA0, 0x7FF3, 0x099A, 0x6556, 0x7111]; % Kirimaru (red, other fur)
[PROMdata] = PRG_Palette_injector(PROMdata,palette_old,palette_new);

% Kirimaru (Player 2 - test)
disp('------------Swapping Kirimaru (player 2) palette-----------------')
palette_old = [0x0017, 0x4332, 0x4663, 0x4995, 0x3BA6, 0x3DC9, 0x4FFC, 0x000C, 0x306E, 0x10DF, 0x6770, 0x0AA0, 0x7FF3, 0x099A, 0x6556, 0x7111]; % Kirimaru (doggo, blue, player 2)
palette_new = [0x0017, 0x0810, 0x0A42, 0x0C74, 0x0D96, 0x0FC9, 0x4FFC, 0x000C, 0x306E, 0x10DF, 0x6770, 0x0AA0, 0x7FF3, 0x099A, 0x6556, 0x7111]; % Kirimaru (blue, other fur)
[PROMdata] = PRG_Palette_injector(PROMdata,palette_old,palette_new);

% Crow tengu (player 2) / DISMISSED, interacts too much with HUD palette
% disp('------------Swapping Crow Tengu (player 2) palette---------------')
% palette_old = [0x0016, 0x7810, 0x0C74, 0x5FC9, 0x3040, 0x6281, 0x54E2, 0x6253, 0x52A9, 0x3AFF, 0x7555, 0x7999, 0x0EEE, 0x6870, 0x2CC0, 0x7111]; % Crow Tengu God (green, player 2)
% palette_new = [0x0016, 0x7810, 0x0C74, 0x5FC9, 0x0800, 0x0D00, 0x4F64, 0x6253, 0x52A9, 0x3AFF, 0x7555, 0x7999, 0x0EEE, 0x6870, 0x2CC0, 0x7111]; % Crow Tengu God (red and blue, player 2)
% [PROMdata] = PRG_Palette_injector(PROMdata,palette_old,palette_new);

% Sword guards, just a palette swap (color of masks is used for blood)
disp('------------Swapping Sword Guards palette------------------------')
palette_old = [0x0032, 0x3741, 0x2C85, 0x4FC9, 0x0520, 0x4A30, 0x1D74, 0x3132, 0x3375, 0x67A8, 0x7555, 0x0AAA, 0x7FFF, 0x2069, 0x00EE, 0x7111]; % Sword guard, white
palette_new = [0x0032, 0x3741, 0x2C85, 0x4FC9, 0x0520, 0x4A30, 0x1D74, 0x3132, 0x3375, 0x67A8, 0x7555, 0x0AAA, 0x7FFF, 0x0B00, 0x4F00, 0x7111]; % Sword guard, white, red blood
[PROMdata] = PRG_Palette_injector(PROMdata,palette_old,palette_new);
palette_old = [0x0038, 0x3741, 0x2C85, 0x4FC9, 0x6550, 0x6B90, 0x6FE0, 0x0555, 0x0AAA, 0x0FFF, 0x7335, 0x7669, 0x699D, 0x2085, 0x30FC, 0x7111]; % Sword guard, blue
palette_new = [0x0038, 0x3741, 0x2C85, 0x4FC9, 0x6550, 0x6B90, 0x6FE0, 0x0555, 0x0AAA, 0x0FFF, 0x7335, 0x7669, 0x699D, 0x0B00, 0x4F00, 0x7111]; % Sword guard, blue, red blood
[PROMdata] = PRG_Palette_injector(PROMdata,palette_old,palette_new);
palette_old = [0x0039, 0x3741, 0x2C85, 0x4FC9, 0x2029, 0x106F, 0x10DF, 0x4600, 0x2B50, 0x4F90, 0x6424, 0x7846, 0x1DAB, 0x2980, 0x6ED0, 0x7111]; % Sword guard, violet
palette_new = [0x0039, 0x3741, 0x2C85, 0x4FC9, 0x2029, 0x106F, 0x10DF, 0x4600, 0x2B50, 0x4F90, 0x6424, 0x7846, 0x1DAB, 0x0B00, 0x4F00, 0x7111]; % Sword guard, violet, red blood
[PROMdata] = PRG_Palette_injector(PROMdata,palette_old,palette_new);
palette_old = [0x0056, 0x3741, 0x2C85, 0x4FC9, 0x6550, 0x6B90, 0x6FE0, 0x4544, 0x0A99, 0x4FFF, 0x5631, 0x7953, 0x5C96, 0x4996, 0x5FFC, 0x7111]; % Sword guard, brown
palette_new = [0x0056, 0x3741, 0x2C85, 0x4FC9, 0x6550, 0x6B90, 0x6FE0, 0x4544, 0x0A99, 0x4FFF, 0x5631, 0x7953, 0x5C96, 0x0B00, 0x4F00, 0x7111]; % Sword guard, brown, red blood
[PROMdata] = PRG_Palette_injector(PROMdata,palette_old,palette_new);
palette_old = [0x0002, 0x1800, 0x4E45, 0x4F20, 0x0001, 0x9500, 0x4745, 0x4F20, 0x0000, 0x0143, 0x5546, 0x4F20, 0x0000, 0x0110, 0x4341, 0x4E20]; % Sword guard, all
palette_new = [0x0002, 0x1800, 0x4E45, 0x4F20, 0x0001, 0x9500, 0x4745, 0x4F20, 0x0000, 0x0143, 0x5546, 0x4F20, 0x0000, 0x0110, 0x424F, 0x4920]; % Sword guard, all, red
[PROMdata] = PRG_Palette_injector(PROMdata,palette_old,palette_new);

% puppet warriors, lotta red !
disp('------------Swapping Puppet Warriors palette---------------------')
palette_old = [0x002F, 0x1720, 0x5B62, 0x5FD8, 0x3844, 0x4F88, 0x4FDD, 0x2B60, 0x6FB0, 0x4FE0, 0x7113, 0x033D, 0x257D, 0x49CF, 0x7FFF, 0x0111]; % Puppet Warrior blue
palette_new = [0x002F, 0x1720, 0x5B62, 0x5FD8, 0x3844, 0x4F88, 0x4FDD, 0x6600, 0x0A10, 0x4F20, 0x7113, 0x033D, 0x257D, 0x49CF, 0x7FFF, 0x0111]; % Puppet Warrior blue with red
[PROMdata] = PRG_Palette_injector(PROMdata,palette_old,palette_new);
palette_old = [0x0030, 0x2930, 0x5D96, 0x4FFA, 0x6810, 0x4C50, 0x4FA3, 0x0634, 0x0957, 0x4F7A, 0x0433, 0x0766, 0x1987, 0x7CBB, 0x7FFF, 0x0000]; % Puppet Warrior orange
palette_new = [0x0030, 0x2930, 0x5D96, 0x4FFA, 0x6810, 0x4C50, 0x4FA3, 0x6600, 0x0A10, 0x4F20, 0x0433, 0x0766, 0x1987, 0x7CBB, 0x7FFF, 0x0000]; % Puppet Warrior orange with red
[PROMdata] = PRG_Palette_injector(PROMdata,palette_old,palette_new);
palette_old = [0x004B, 0x1720, 0x5B62, 0x5FD8, 0x0443, 0x1887, 0x0BBA, 0x7232, 0x0565, 0x09B9, 0x6223, 0x7446, 0x677A, 0x1BBC, 0x1FFF, 0x0000]; % Puppet Warrior gray
palette_new = [0x004B, 0x1720, 0x5B62, 0x5FD8, 0x0443, 0x1887, 0x0BBA, 0x6600, 0x0A10, 0x4F20, 0x6223, 0x7446, 0x677A, 0x1BBC, 0x1FFF, 0x0000]; % Puppet Warrior gray with red
[PROMdata] = PRG_Palette_injector(PROMdata,palette_old,palette_new);

% Ninja monks, lotta red too!
disp('------------Swapping Ninja Monk palette--------------------------')
palette_old = [0x002B, 0x4730, 0x7B32, 0x5F85, 0x2464, 0x28A8, 0x7EFE, 0x4430, 0x4860, 0x4FA0, 0x5323, 0x7626, 0x2B2B, 0x7E6E, 0x6FC8, 0x7202]; % Ninja Monk violet
palette_new = [0x002B, 0x4730, 0x7B32, 0x5F85, 0x2464, 0x28A8, 0x7EFE, 0x4500, 0x0B00, 0x4F00, 0x5323, 0x7626, 0x2B2B, 0x7E6E, 0x6FC8, 0x7202]; % Ninja Monk violet with red hat
[PROMdata] = PRG_Palette_injector(PROMdata,palette_old,palette_new);
palette_old = [0x0049, 0x6721, 0x2C53, 0x0F95, 0x2555, 0x3999, 0x7FFF, 0x6610, 0x4B20, 0x4F50, 0x6336, 0x6669, 0x7BBE, 0x7EEF, 0x4FE8, 0x0003]; % Ninja Monk gray
palette_new = [0x0049, 0x6721, 0x2C53, 0x0F95, 0x2555, 0x3999, 0x7FFF, 0x4500, 0x0B00, 0x4F00, 0x6336, 0x6669, 0x7BBE, 0x7EEF, 0x4FE8, 0x0003]; % Ninja Monk gray with red hat
[PROMdata] = PRG_Palette_injector(PROMdata,palette_old,palette_new);
palette_old = [0x002C, 0x4550, 0x2A73, 0x4EC5, 0x7447, 0x188A, 0x7EEF, 0x1041, 0x3163, 0x24C7, 0x4500, 0x0B00, 0x4F00, 0x4F80, 0x7FFC, 0x4200]; % Ninja Monk red
palette_new = [0x002C, 0x4550, 0x2A73, 0x4EC5, 0x7447, 0x188A, 0x7EEF, 0x4500, 0x0B00, 0x4F00, 0x0131, 0x1362, 0x54A4, 0x77D7, 0x7FFC, 0x4200]; % Ninja Monk red and green inverted
[PROMdata] = PRG_Palette_injector(PROMdata,palette_old,palette_new);

disp('------------Swapping Giants palette------------------------------')
palette_old = [0x005B, 0x0A51, 0x6C61, 0x6F90, 0x3531, 0x309D, 0x30DF, 0x2840, 0x4C90, 0x6FF0, 0x6621, 0x0999, 0x7FFF, 0x6FCA, 0x4FFD, 0x0000]; % Giant blue dressing
palette_new = [0x005B, 0x0A51, 0x6C61, 0x6F90, 0x3531, 0x309D, 0x30DF, 0x0800, 0x0C00, 0x4F00, 0x6621, 0x0999, 0x7FFF, 0x6FCA, 0x4FFD, 0x0000]; % Giant blue dressing now red
[PROMdata] = PRG_Palette_injector(PROMdata,palette_old,palette_new);

disp('------------Swapping Kunoichi palette----------------------------')
palette_old = [0x0052, 0x0A40, 0x6D86, 0x6FCA, 0x0408, 0x592B, 0x7D5F, 0x7FFF, 0x6CCF, 0x088A, 0x0334, 0x4980, 0x6FF0, 0x54DF, 0x309F, 0x0000]; % Kunoichi (woman) violet
palette_new = [0x0052, 0x0A40, 0x6D86, 0x6FCA, 0x0408, 0x592B, 0x7D5F, 0x7FFF, 0x6CCF, 0x088A, 0x0334, 0x0B00, 0x4F00, 0x54DF, 0x309F, 0x0000]; % Kunoichi (woman) violet, wristband red
[PROMdata] = PRG_Palette_injector(PROMdata,palette_old,palette_new);
palette_old = [0x0083, 0x0A40, 0x6D86, 0x6FCA, 0x2040, 0x30A1, 0x25F5, 0x7FFF, 0x7CDC, 0x08A8, 0x0343, 0x4980, 0x6FF0, 0x5B8F, 0x075C, 0x0000]; % Kunoichi (woman) green
palette_new = [0x0083, 0x0A40, 0x6D86, 0x6FCA, 0x2040, 0x30A1, 0x25F5, 0x7FFF, 0x7CDC, 0x08A8, 0x0343, 0x0B00, 0x4F00, 0x5B8F, 0x075C, 0x0000]; % Kunoichi (woman) green, wristband red
[PROMdata] = PRG_Palette_injector(PROMdata,palette_old,palette_new);

disp('------------Swapping Axeman palette------------------------------')
palette_old = [0x002E, 0x2730, 0x2951, 0x2CA3, 0x7555, 0x0BBB, 0x7FFF, 0x4410, 0x4920, 0x0F40, 0x4F60, 0x0044, 0x0077, 0x00CC, 0x5FF5, 0x0000]; % Axeman red
palette_new = [0x002E, 0x2730, 0x2951, 0x2CA3, 0x7555, 0x0BBB, 0x7FFF, 0x4500, 0x0B00, 0x4F00, 0x4F80, 0x0044, 0x0077, 0x00CC, 0x5FF5, 0x0000]; % Axeman red, more vibrant
[PROMdata] = PRG_Palette_injector(PROMdata,palette_old,palette_new);
palette_old = [0x006F, 0x0631, 0x1962, 0x1DA5, 0x0444, 0x0999, 0x7FFF, 0x3220, 0x4461, 0x6682, 0x58B2, 0x0007, 0x100F, 0x106F, 0x1FEA, 0x0000]; % Axeman green
palette_new = [0x006F, 0x0631, 0x1962, 0x1DA5, 0x0444, 0x0999, 0x7FFF, 0x4500, 0x0B00, 0x4F00, 0x4F80, 0x0007, 0x100F, 0x106F, 0x1FEA, 0x0000]; % Axeman green, now red too
[PROMdata] = PRG_Palette_injector(PROMdata,palette_old,palette_new);

% Spearman palette / DISMISSED, pointless
% disp('-----------------------Spearman palette----------------------')
% palette_old = [0x002D, 0x4B30, 0x2D80, 0x7FD6, 0x0213, 0x3425, 0x2859, 0x2510, 0x6950, 0x4FD0, 0x4600, 0x0C00, 0x6F40, 0x7CBD, 0x7FFF, 0x0000]; % Spearman red
% palette_new = [0x002D, 0x4B30, 0x2D80, 0x7FD6, 0x0213, 0x3425, 0x2859, 0x4600, 0x0C00, 0x6F40, 0x2510, 0x6950, 0x4FD0, 0x7CBD, 0x7FFF, 0x0000]; % Spearman red and green inverted
% [PROMdata] = PRG_Palette_injector(PROMdata,palette_old,palette_new);

disp('------------Swapping Big fish with legs palette------------------')
palette_old = [0x0055, 0x302A, 0x504F, 0x716F, 0x6430, 0x6980, 0x1DD2, 0x0731, 0x0A53, 0x5D84, 0x0016, 0x7FB7, 0x6FFC, 0x248E, 0x37CF, 0x0000]; % big blue fish
palette_new = [0x0055, 0x4A10, 0x0E20, 0x2F50, 0x6430, 0x6980, 0x1DD2, 0x0731, 0x0A53, 0x5D84, 0x6610, 0x7FB7, 0x6FFC, 0x6E80, 0x4FB0, 0x0000]; % big blue fish, now red
[PROMdata] = PRG_Palette_injector(PROMdata,palette_old,palette_new);

disp('------------Swapping Soldier palette-----------------------------')% this one was lucky, I have a free entry in palette !
palette_old = [0x0065, 0x3941, 0x3E93, 0x4FE7, 0x0140, 0x0480, 0x08C0, 0x0720, 0x4B60, 0x1037, 0x518A, 0x26CF, 0x7EFF, 0x7DF4, 0x20F4, 0x0000]; % Soldier palette 2
palette_new = [0x0065, 0x3941, 0x3E93, 0x4FE7, 0x0140, 0x0480, 0x08C0, 0x0720, 0x4B60, 0x1037, 0x518A, 0x26CF, 0x7EFF, 0x7DF4, 0x4F00, 0x0000]; % Soldier palette with red injected;
[PROMdata] = PRG_Palette_injector(PROMdata,palette_old,palette_new);

disp('------------Swapping Kojiro palette------------------------------')
palette_old = [0x004E, 0x2830, 0x2C73, 0x6FC8, 0x5151, 0x4595, 0x79F9, 0x0960, 0x6FB0, 0x30DF, 0x0559, 0x799C, 0x1FFF, 0x5606, 0x5C0C, 0x0000]; % Kojiro (anywhere else, green)
palette_new = [0x004E, 0x2830, 0x2C73, 0x6FC8, 0x5151, 0x4595, 0x79F9, 0x0960, 0x6FB0, 0x30DF, 0x0559, 0x799C, 0x1FFF, 0x4A00, 0x4F00, 0x0000]; % Kojiro (anywhere else, green but a bit of red instead of purple)
[PROMdata] = PRG_Palette_injector(PROMdata,palette_old,palette_new);

disp('------------Swapping Yoshitsune palette--------------------------')
palette_old = [0x0068, 0x3005, 0x202C, 0x306F, 0x1426, 0x393A, 0x5C5F, 0x0360, 0x04A0, 0x6AF0, 0x0777, 0x7BBB, 0x7FFF, 0x4A10, 0x6F40, 0x0000]; % Yoshitsune (boss 3)
palette_new = [0x0068, 0x3005, 0x202C, 0x306F, 0x1426, 0x393A, 0x5C5F, 0x0360, 0x04A0, 0x6AF0, 0x0777, 0x7BBB, 0x7FFF, 0x4A00, 0x4F00, 0x0000]; % Yoshitsune (boss 3), vivid reds
[PROMdata] = PRG_Palette_injector(PROMdata,palette_old,palette_new);

disp('------------Swapping General palette-----------------------------')
palette_old = [0x0076, 0x2A31, 0x2D85, 0x4FC8, 0x0830, 0x0C40, 0x4F60, 0x5131, 0x2242, 0x0494, 0x08B0, 0x6BB0, 0x6FF0, 0x07C7, 0x2AFA, 0x0000]; % Adolfo Ramirez
palette_new = [0x0076, 0x2A31, 0x2D85, 0x4FC8, 0x4600, 0x4A11, 0x4F33, 0x5131, 0x2242, 0x0494, 0x08B0, 0x6BB0, 0x6FF0, 0x07C7, 0x2AFA, 0x0000]; % Adolfo Ramirez, vivid reds
[PROMdata] = PRG_Palette_injector(PROMdata,palette_old,palette_new);

disp('------------Swapping Puppet number 2 palette---------------------')
palette_old = [0x0078, 0x3720, 0x2B52, 0x3E94, 0x5606, 0x5A0A, 0x5F0F, 0x3023, 0x3046, 0x2069, 0x0885, 0x6BB9, 0x7FFC, 0x109B, 0x10DF, 0x0000]; % Puppet 2
palette_new = [0x0078, 0x3720, 0x2B52, 0x3E94, 0x4700, 0x4B00, 0x4F00, 0x3023, 0x3046, 0x2069, 0x0885, 0x6BB9, 0x7FFC, 0x109B, 0x10DF, 0x0000]; % Puppet 2 with reds from puppet 1
[PROMdata] = PRG_Palette_injector(PROMdata,palette_old,palette_new);

[~, name, ext] = fileparts(PRomFile);
newFileName = ['.\roms_out\', name, ext];
fid = fopen(newFileName, 'wb');
fwrite(fid, PROMdata, 'uint8');
fclose(fid);

%% Now dealing directly with the track 1 raw binary
% A modified payload can be injected two times in different locations, it's not an issue
disp('Injecting data packets into the NGCD binary')
Binary_file_injector(); % also contains the ECC/EDC correction routine

%% Generate IPF files for all these modifications on individual files
disp('Generating IPS script and performing CRC32 checksums')
%IPS_generator('.\NGCD_track_1_files\P040.PRG','.\roms_out\P040.PRG','.\IPS_scripts\P040.PRG.ips') %not used anymore, targetting the binary directly
%IPS_generator('.\NGCD_track_1_files\JOUCHU.SPR','.\roms_out\JOUCHU.SPR','.\IPS_scripts\JOUCHU.SPR.ips') %not used anymore, targetting the binary directly
%IPS_generator('.\NGCD_track_1_files\AREA1.SPR','.\roms_out\AREA1.SPR','.\IPS_scripts\AREA1.SPR.ips') %not used anymore, targetting the binary directly
%IPS_generator('.\NGCD_track_1_files\AREA2.SPR','.\roms_out\AREA2.SPR','.\IPS_scripts\AREA2.SPR.ips') %not used anymore, targetting the binary directly
%IPS_generator('.\NGCD_track_1_files\AREA3.SPR','.\roms_out\AREA3.SPR','.\IPS_scripts\AREA3.SPR.ips') %not used anymore, targetting the binary directly
%IPS_generator('.\NGCD_track_1_files\AREA4.SPR','.\roms_out\AREA4.SPR','.\IPS_scripts\AREA4.SPR.ips') %not used anymore, targetting the binary directly
%IPS_generator('.\NGCD_track_1_files\STAFF.SPR','.\roms_out\STAFF.SPR','.\IPS_scripts\STAFF.SPR.ips') %not used anymore, targetting the binary directly
%IPS_generator('.\NGCD_track_1_files\TITLE.SPR','.\roms_out\TITLE.SPR','.\IPS_scripts\TITLE.SPR.ips') %not used anymore, targetting the binary directly
IPS_generator('.\NGCD_track_1_binary\Sengoku2_Track_01.bin','.\NGCD_track_1_binary\Sengoku2_track_1_patched.bin','.\IPS_scripts\Sengoku2_Track_01.bin.ips')

disp('Neo Geo CD version converted !')

