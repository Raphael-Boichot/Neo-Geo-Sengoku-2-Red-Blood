clc
clear
warning off
tic
%% Init section


% Original roms
oddRomFile_big  = '040-c1.c1';
evenRomFile_big = '040-c2.c2';
oddRomFile_small  = '040-c3.c3';
evenRomFile_small = '040-c4.c4';

palette =[0x1005, 0x1008, 0x100D, 0x303F, 0x308F, 0x30DF, 0xF3FB, 0xF7F7, 0xFCF2, 0xEFF0, 0xEFA0, 0xEF50, 0xEF00, 0xCB00, 0xC700, 0xC400]; % Dummy palette jet, high contrast
disp('Initialization completed')

%% Prepare merged roms for burning EPROMs
disp('Prepare ROMs for burning EPROMs to a bootleg MVS cartridge') 
EPROM_merger(oddRomFile_big, evenRomFile_big, 'MX29LV320.C1') % chip is 4 MBytes, ROM is 4 MBytes, filled at 100% OK
EPROM_merger(oddRomFile_small, evenRomFile_small, 'MX29LV320.C2') % chip is 4 MBytes, ROM is 1 MBytes
toc

%% Transforms the pair of roms in png tileset + palette image to ckeck
%///////////////section to comment to edit tileset//////////////////
disp('Building tileset in png from palette vector')
Cspr_to_png('MX29LV320.C1',palette, 'C1_interlaced.png', 'palette.txt')
Cspr_to_png('MX29LV320.C2',palette, 'C2_interlaced.png', 'palette.txt')
Cspr_to_png(oddRomFile_big,palette, 'C1_as_it.png', 'palette.txt')
Cspr_to_png(evenRomFile_big,palette, 'C2_as_it.png', 'palette.txt')
Cspr_to_png(oddRomFile_small,palette, 'C3_as_it.png', 'palette.txt')
Cspr_to_png(evenRomFile_small,palette, 'C4_as_it.png', 'palette.txt')