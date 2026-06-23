clear; clc;

%% Configuration
oddRomFile  = '040-c1.c1';
evenRomFile = '040-c2.c2';
outputPng   = 'Tileset.png';
%outputPgm   = 'Tileset.pgm';
%palette = [0x0010, 0x7810, 0x0C74, 0x5FC9, 0x5409, 0x1A0F, 0x1F9F, 0x0800, ...
%           0x0C00, 0x4F93, 0x0666, 0x7AAA, 0x0EEE, 0x7334, 0x4500, 0x7111]; %Claude Yamamoto (player 1)
% palette = [0x0011, 0x7810, 0x0C74, 0x5FC9, 0x6640, 0x6B80, 0x6FF0, 0x3037, ...
%           0x638C, 0x3AFF, 0x0666, 0x7AAA, 0x0EEE, 0x7334, 0x4FA0, 0x7111]; %Jack Stone (Player 2)
palette = [0x0014, 0x4332, 0x4663, 0x4995, 0x3BA6, 0x3DC9, 0x4FFC, 0x0A00 ...
           0x0F00, 0x4F90, 0x6770, 0x0AA0, 0x7FF3, 0x099A, 0x6556, 0x7111]; % Kirimaru (doggo)
% palette =[0x004B, 0x1720, 0x5B62, 0x5FD8, 0x0443, 0x1887, 0x0BBA, 0x7232, ...
%           0x0565, 0x09B9, 0x6223, 0x7446, 0x677A, 0x1BBC, 0x1FFF, 0x0000]; %Puppet Warrior main

TILES_PER_ROW = 32;

%% 1. CRC32 Check Function
function crc = calculateCRC32(data)
poly = uint32(hex2dec('EDB88320')); crc = uint32(hex2dec('FFFFFFFF'));
for i = 1:numel(data)
    crc = bitxor(crc, uint32(data(i)));
    for j = 1:8
        if bitand(crc, 1), crc = bitxor(bitshift(crc, -1), poly); else, crc = bitshift(crc, -1); end
    end
end
crc = bitcmp(crc);
end

%% 2. Load and Verify ROMs
fid1 = fopen(oddRomFile,'rb'); odd = fread(fid1,Inf,'uint8=>uint8'); fclose(fid1);
fid2 = fopen(evenRomFile,'rb'); even = fread(fid2,Inf,'uint8=>uint8'); fclose(fid2);

fprintf('Verifying ROMs:\n');
fprintf('  %s CRC32: %08X\n', oddRomFile, calculateCRC32(odd));
fprintf('  %s CRC32: %08X\n', evenRomFile, calculateCRC32(even));

%% 3. Decode
numTiles = numel(odd)/64;
rows = ceil(numTiles/TILES_PER_ROW);
sheet_indices = zeros(rows*16, TILES_PER_ROW*16, 'uint8');
blockX = [0 0 8 8]; blockY = [0 8 0 8];

for tile = 0:numTiles-1
    oddBase = tile*64; evenBase = tile*64;
    tx = mod(tile, TILES_PER_ROW); ty = floor(tile/TILES_PER_ROW);
    for b = 0:3
        xOfs = blockX(b+1); yOfs = blockY(b+1);
        for row = 0:7
            idx = b*16 + row*2;
            for col = 0:7
                bitPos = 7-col;
                val = bitget(odd(oddBase+idx+1), bitPos+1) + ...
                    bitshift(bitget(odd(oddBase+idx+2), bitPos+1),1) + ...
                    bitshift(bitget(even(evenBase+idx+1), bitPos+1),2) + ...
                    bitshift(bitget(even(evenBase+idx+2), bitPos+1),3);
                sheet_indices(ty*16+yOfs+row+1, tx*16+xOfs+col+1) = uint8(val);
            end
        end
    end
end

%% 4. Save
% fid = fopen(outputPgm, 'wb');
% fprintf(fid, 'P5\n%d %d\n15\n', size(sheet_indices, 2), size(sheet_indices, 1));
% fwrite(fid, sheet_indices', 'uint8'); fclose(fid);

% Create visual PNG
rgbPalette = zeros(16,3,'uint8');
for i=1:16
    c = uint16(palette(i)); dark = bitget(c,16);
    r = bitshift(bitand(c,hex2dec('0F00')),-8); g = bitshift(bitand(c,hex2dec('00F0')),-4); b = bitand(c,hex2dec('000F'));
    rgbPalette(i,:) = uint8(round(double([bitor(bitshift(r,1),dark), bitor(bitshift(g,1),dark), bitor(bitshift(b,1),dark)])*255/31));
end
sheet = zeros(size(sheet_indices,1), size(sheet_indices,2), 4, 'uint8');
for y=1:size(sheet_indices,1)
    for x=1:size(sheet_indices,2)
        idx = sheet_indices(y,x);
        if idx == 0, sheet(y,x,:) = [0 0 0 0]; else, sheet(y,x,:) = [rgbPalette(idx+1,:), 255]; end
    end
end
imwrite(sheet(:,:,1:3), outputPng, 'Alpha', sheet(:,:,4));
fprintf('Export complete.\n');

%% 5. Export Palette to Text File
paletteFid = fopen('Palette.txt', 'w');
fprintf(paletteFid, 'Palette Export (RGB 0-255):\n');
fprintf(paletteFid, 'Index | R | G | B\n');
fprintf(paletteFid, '------------------\n');

for i = 1:16
    fprintf(paletteFid, '%02d    | %3d | %3d | %3d\n', ...
        i-1, rgbPalette(i,1), rgbPalette(i,2), rgbPalette(i,3));
end
fclose(paletteFid);
fprintf('Palette exported to Palette.txt\n');

%% 6. Export Palette to PNG (Visual Reference)
% Create a 32x512 image (32 pixels high, 16 blocks of 32 pixels wide = 512 wide)
palette_strip = zeros(32, 512, 3, 'uint8');

for i = 1:16
    % Calculate horizontal range for this color block (32 pixels per block)
    x_start = (i-1) * 32 + 1;
    x_end = i * 32;
    
    % Fill the block with the corresponding RGB color
    palette_strip(:, x_start:x_end, 1) = rgbPalette(i, 1);
    palette_strip(:, x_start:x_end, 2) = rgbPalette(i, 2);
    palette_strip(:, x_start:x_end, 3) = rgbPalette(i, 3);
end

imwrite(palette_strip, 'Palette.png');
fprintf('Visual palette exported as 32x32 blocks to Palette.png\n');