
clc
clear
warning off
tic

disp('If test is good, checksums before and after must coincide')
disp('Just ignore this message in case you''re doing modifications')

%% Init section
% Original roms
oddRomFile_big  = '.\roms\040-c1.c1';
evenRomFile_big = '.\roms\040-c2.c2';
oddRomFile_small  = '.\roms\040-c3.c3';
evenRomFile_small = '.\roms\040-c4.c4';

original_prog ='.\roms\040-p1.p1';

% modified roms
oddRomOut_big    = '.\roms_out\040-c1.c1';
evenRomOut_big   = '.\roms_out\040-c2.c2';
oddRomOut_small    = '.\roms_out\040-c3.c3';
evenRomOut_small   = '.\roms_out\040-c4.c4';
modified_prog = '.\roms_out\040-p1.p1';

outpng_big ='Tileset_big.png';
outpng_small ='Tileset_small.png';

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Main characteres %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
palette = [0x0010, 0x7810, 0x0C74, 0x5FC9, 0x5409, 0x1A0F, 0x1F9F, 0x0800, 0x0C00, 0x4F93, 0x0666, 0x7AAA, 0x0EEE, 0x7334, 0x4500, 0x7111]; % Claude Yamamoto (player 1)
% palette = [0x0011, 0x7810, 0x0C74, 0x5FC9, 0x6640, 0x6B80, 0x6FF0, 0x3037, 0x638C, 0x3AFF, 0x0666, 0x7AAA, 0x0EEE, 0x7334, 0x4FA0, 0x7111]; % Jack Stone (Player 2)
% palette = [0x0012, 0x7810, 0x0C74, 0x5FC9, 0x1738, 0x5B8C, 0x3FCF, 0x4700, 0x0C00, 0x4F93, 0x0250, 0x2680, 0x0AD0, 0x6B80, 0x6FF0, 0x7111]; % Mike Walsh (green)
% palette = [0x0013, 0x7810, 0x0C74, 0x5FC9, 0x0800, 0x0D00, 0x4F64, 0x6551, 0x0AA4, 0x0FF8, 0x7555, 0x7999, 0x0EEE, 0x0A80, 0x2EC0, 0x7111]; % Crow Tengu God (red)
% palette = [0x0014, 0x4332, 0x4663, 0x4995, 0x3BA6, 0x3DC9, 0x4FFC, 0x0A00, 0x0F00, 0x4F90, 0x6770, 0x0AA0, 0x7FF3, 0x099A, 0x6556, 0x7111]; % Kirimaru (doggo, red)
% palette = [0x0015, 0x7810, 0x0C74, 0x5FC9, 0x5204, 0x5309, 0x190F, 0x4700, 0x0C00, 0x4F93, 0x0045, 0x138B, 0x29EF, 0x1DA3, 0x6FFB, 0x7111]; % Mike Walsh (blue)
% palette = [0x0016, 0x7810, 0x0C74, 0x5FC9, 0x3040, 0x6281, 0x54E2, 0x6253, 0x52A9, 0x3AFF, 0x7555, 0x7999, 0x0EEE, 0x6870, 0x2CC0, 0x7111]; % Crow Tengu God (green)
% palette = [0x0017, 0x4332, 0x4663, 0x4995, 0x3BA6, 0x3DC9, 0x4FFC, 0x000C, 0x306E, 0x10DF, 0x6770, 0x0AA0, 0x7FF3, 0x099A, 0x6556, 0x7111]; % Kirimaru (doggo, blue)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Main characteres %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Foes %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% palette = [0x004A, 0x0660, 0x6AA0, 0x6FF0, 0x0157, 0x029D, 0x14FF, 0x6600, 0x0A10, 0x4F20, 0x3115, 0x6348, 0x558B, 0x59BC, 0x7FFF, 0x0000]; % Puppet Warrior blue
% palette = [0x004B, 0x1720, 0x5B62, 0x5FD8, 0x0443, 0x1887, 0x0BBA, 0x7232, 0x0565, 0x09B9, 0x6223, 0x7446, 0x677A, 0x1BBC, 0x1FFF, 0x0000]; % Puppet Warrior gray

% palette = [0x002B, 0x4730, 0x7B32, 0x5F85, 0x2464, 0x28A8, 0x7EFE, 0x4430, 0x4860, 0x4FA0, 0x5323, 0x7626, 0x2B2B, 0x7E6E, 0x6FC8, 0x7202]; % Ninja Monk (violet)
% palette = [0x0049, 0x6721, 0x2C53, 0x0F95, 0x2555, 0x3999, 0x7FFF, 0x6610, 0x4B20, 0x4F50, 0x6336, 0x6669, 0x7BBE, 0x7EEF, 0x4FE8, 0x0003]; % Ninja Monk (gray)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Foes %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

dummy_palette = [0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000];
disp('Initialization completed')

%% Transforms the pair of roms in png tileset + palette image to ckeck
%///////////////section to comment to edit tileset//////////////////
disp('Building tileset in png from palette vector')
Crom_to_png(oddRomFile_big,evenRomFile_big,palette, outpng_big)
Crom_to_png(oddRomFile_small,evenRomFile_small,palette, outpng_small)
% Here some manual editing of the png tileset is expected
%///////////////section to comment to edit tileset//////////////////

%% Neo Geo new palette hex values for testing
disp('Swapping palettes from vector and updating palette.txt')
alternate_palette = [0x0010, 0x7810, 0x0C74, 0x5FC9, 0x5409, 0x1A0F, 0x1F9F, 0x0800, 0x0C00, 0x4F93, 0x0666, 0x7AAA, 0x0EEE, 0x7334, 0x4500, 0x7111]; % Claude Yamamoto (player 1)
Palette_swapper(alternate_palette,outpng_big)
Palette_swapper(alternate_palette,outpng_small)

%% Transforms the png back to pair of C ROMS based on current palette.txt
disp('Building back C ROMs from png and palette.txt')
png_to_Crom(oddRomOut_big, evenRomOut_big,outpng_big)
png_to_Crom(oddRomOut_small, evenRomOut_small,outpng_small)
% CRC32 must be the same in test mode

%% Injects new palettes in P ROMs
% Here some manual editing of the new palette
disp('Targeting and injecting new palette(s) in P ROM')
copyfile('.\roms\040-p1.p1','.\roms_out\040-p1.p1');
PRomFile = '.\roms_out\040-p1.p1';
% Here some manual editing of the palette vector is expected
palette_old = [0x0010, 0x7810, 0x0C74, 0x5FC9, 0x5409, 0x1A0F, 0x1F9F, 0x0800, 0x0C00, 0x4F93, 0x0666, 0x7AAA, 0x0EEE, 0x7334, 0x4500, 0x7111]; % Claude Yamamoto (player 1)
palette_new = [0x0010, 0x7810, 0x0C74, 0x5FC9, 0x5409, 0x1A0F, 0x1F9F, 0x0800, 0x0C00, 0x4F93, 0x0666, 0x7AAA, 0x0EEE, 0x7334, 0x4500, 0x7111]; % Claude Yamamoto (player 1)
Prom_Palette_injector(PRomFile,palette_old,palette_new)
% CRC32 must be the same in test mode

%% Generate IPF file for these modifications
disp('Generating IPS script')
ipsFile='.\IPS_scripts\040-c1.c1.ips';
IPS_generator(oddRomFile_big,oddRomOut_big,ipsFile)
ipsFile='.\IPS_scripts\040-c2.c2.ips';
IPS_generator(evenRomFile_big,evenRomOut_big,ipsFile)
ipsFile='.\IPS_scripts\040-c3.c3.ips';
IPS_generator(oddRomFile_small,oddRomOut_small,ipsFile)
ipsFile='.\IPS_scripts\040-c4.c4.ips';
IPS_generator(evenRomFile_small,evenRomOut_small,ipsFile)
ipsFile='.\IPS_scripts\040-p1.p1.ips';
IPS_generator(original_prog,modified_prog,ipsFile)
toc