clc
clear

run('Crom_to_png.m')
run('Palette_swapper.m')

% Here some manual editing of the png tileset
run('png_to_Crom.m')
% CRC32 must be the same

% Here some manual editing of the new palette
run('Prom_Palette_injector.m')
% CRC32 must be the same
run('IPS_generator.m')