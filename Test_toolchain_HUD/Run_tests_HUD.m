clc
clear
warning off
tic
%% Init section
palette = [0x000A, 0x7901, 0x0D85, 0x5FC9, 0x060A, 0x5B0F, 0x5F8F, 0x4F00, 0x4FA1, 0x7555, 0x7999, 0x7EEE, 0x6510, 0x138B, 0x47DE, 0x0000]; %HUD vignette, all characters player 1
disp('Initialization completed')

%% Transforms the pair of roms in png tileset + palette image to ckeck
%///////////////section to comment to edit tileset//////////////////
disp('Building tileset in png from palette vector')
SROM_to_png('040-s1.s1',palette, 'HUD.png', 'palette.txt')
png_to_SROM('HUD.png', 'palette.txt', '040-s1.s1_patched')
SROM_to_png('P040.FIX',palette, 'FIX.png', 'palette.txt')
png_to_SROM('FIX.png', 'palette.txt', 'P040.FIX_patched')