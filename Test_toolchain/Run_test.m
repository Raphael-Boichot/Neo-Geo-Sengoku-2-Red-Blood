clc
clear

run('Crom_to_png.m')
run('Palette_swapper.m')

% Here some manual editing of the png tileset
run('png_to_Crom.m')
% CRC32 must be the same in test mode

% Here some manual editing of the new palette
PRomFile = '.\roms\040-p1.p1';
palette_old = [0x0010, 0x7810, 0x0C74, 0x5FC9, 0x5409, 0x1A0F, 0x1F9F, 0x0800, 0x0C00, 0x4F93, 0x0666, 0x7AAA, 0x0EEE, 0x7334, 0x4500, 0x7111];
palette_new = [0x0010, 0x7810, 0x0C74, 0x5FC9, 0x5409, 0x1A0F, 0x1F9F, 0x0800, 0x0C00, 0x4F93, 0x0666, 0x7AAA, 0x0EEE, 0x7334, 0x4500, 0x7111];
Prom_Palette_injector(PRomFile,palette_old,palette_new)
% CRC32 must be the same in test mode


originalFile='.\roms\040-c1.c1';
modifiedFile='.\roms_out\040-c1.c1.new';
ipsFile='.\roms_out\040-c1.c1.ips';
IPS_generator(originalFile,modifiedFile,ipsFile)

originalFile='.\roms\040-c2.c2';
modifiedFile='.\roms_out\040-c2.c2.new';
ipsFile='.\roms_out\040-c2.c2.ips';
IPS_generator(originalFile,modifiedFile,ipsFile)

originalFile='.\roms\040-p1.p1';
modifiedFile='.\roms_out\040-p1.p1.new';
ipsFile='.\roms_out\040-p1.p1.ips';
IPS_generator(originalFile,modifiedFile,ipsFile)