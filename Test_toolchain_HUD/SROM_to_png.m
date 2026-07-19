function SROM_to_png(sprFile, palette, outputPng, outputPalette)
% Converts a Neo Geo S ROM (fix/HUD layer graphics) into a PNG sprite sheet.
%
% S ROM tiles are 8x8 px, 32 bytes each, 4bpp - but unlike C ROM (sprite)
% tiles, each pixel's whole 4-bit color index is packed into a SINGLE
% nibble (not spread across 4 separate bitplane bytes), and the nibbles
% are stored in a fixed scrambled order within the 32 bytes. This is
% MAME's classic "All games" fix charlayout:
%
%   xoffset (nibble units, per column 0-7): [33 32 49 48 1 0 17 16]
%   yoffset (nibble units, per row    0-7): [0 2 4 6 8 10 12 14]
%   nibble_addr(row,col) = yoffset(row) + xoffset(col)
%   byte = tile((nibble_addr div 2) + 1)
%   value = low nibble of byte if nibble_addr is even, else high nibble
%
% This layout is fixed/universal (pre-CMC-encryption Neo Geo carts), so
% it should work unmodified for any unencrypted S1/SFIX ROM.

TILES_PER_ROW = 32;
TILE_PX = 8;
BYTES_PER_TILE = 32;

% 2. Load ROM
fid = fopen(sprFile,'rb'); sprData = fread(fid,Inf,'uint8=>uint8'); fclose(fid);
fprintf('Source %s (CRC32: %08X)\n', sprFile, computeCRC32(sprFile));

% 3. Corrected fixed nibble-address map (Per your header documentation)
% Using the MAME "All games" layout:
xoff = [33, 32, 49, 48, 1, 0, 17, 16]; 
yoff = [0, 2, 4, 6, 8, 10, 12, 14];

% Precompute the nibble address map
addrMat = zeros(8,8);
for r = 1:8
    for c = 1:8
        addrMat(r,c) = yoff(r) + xoff(c);
    end
end
byteIdx0 = floor(addrMat / 2);
isHigh   = mod(addrMat, 2); % 1 if high nibble, 0 if low

% 4. Decode
% Define numTiles BEFORE the loop
numTiles = floor(numel(sprData)/BYTES_PER_TILE);
rows = ceil(numTiles/TILES_PER_ROW);
sheet_indices = zeros(rows*TILE_PX, TILES_PER_ROW*TILE_PX, 'uint8');

for tile = 0:numTiles-1
    base = tile * BYTES_PER_TILE;
    tx = mod(tile, TILES_PER_ROW); ty = floor(tile/TILES_PER_ROW);
    tb = sprData(base + (1:32)); 
    
    % Reconstruct the 8x8 tile
    tileVal = zeros(8, 8, 'uint8');
    for r = 1:8
        for c = 1:8
            b = tb(byteIdx0(r,c) + 1);
if isHigh(r,c)
    tileVal(r,c) = bitand(b,15);
else
    tileVal(r,c) = bitshift(b,-4);
end
        end
    end
    sheet_indices(ty*TILE_PX+(1:TILE_PX), tx*TILE_PX+(1:TILE_PX)) = tileVal;
end

% 5. Create visual PNG with Transparent Padding
rgbPalette = zeros(16,3,'uint8');
for i=1:16
    if i == 1, rgbPalette(i,:) = [0 0 0];
    else
        c = uint16(palette(i)); dark = bitget(c,16);
        r = bitshift(bitand(c,hex2dec('0F00')),-8); g = bitshift(bitand(c,hex2dec('00F0')),-4); b = bitand(c,hex2dec('000F'));
        rgbPalette(i,:) = uint8(round(double([bitor(bitshift(r,1),dark), bitor(bitshift(g,1),dark), bitor(bitshift(b,1),dark)])*255/31));
    end
end

% Vectorized replacement for the per-pixel y,x loop
[H, W] = size(sheet_indices);
[xg, yg] = meshgrid(0:W-1, 0:H-1);
tileX = floor(xg/TILE_PX); tileY = floor(yg/TILE_PX);
tileIdxMat = tileY*TILES_PER_ROW + tileX;
validMask = tileIdxMat < numTiles;

idxPlusOne = double(sheet_indices) + 1;
Rall = reshape(rgbPalette(idxPlusOne(:), 1), H, W);
Gall = reshape(rgbPalette(idxPlusOne(:), 2), H, W);
Ball = reshape(rgbPalette(idxPlusOne(:), 3), H, W);

opaqueMask = validMask & (sheet_indices ~= 0);
R = zeros(H, W, 'uint8'); G = zeros(H, W, 'uint8'); B = zeros(H, W, 'uint8');
R(opaqueMask) = Rall(opaqueMask);
G(opaqueMask) = Gall(opaqueMask);
B(opaqueMask) = Ball(opaqueMask);
A = uint8(opaqueMask) * 255;

sheet = cat(3, R, G, B, A);
imwrite(sheet(:,:,1:3), outputPng, 'Alpha', sheet(:,:,4));

% 6. Export Palette and Metadata
paletteFid = fopen(outputPalette, 'w');
fprintf(paletteFid, 'Total Tiles: %d\n', numTiles);
fprintf(paletteFid, 'Palette Export (RGB 0-255):\n');
fprintf(paletteFid, 'Index | R | G | B\n');
fprintf(paletteFid, '------------------\n');
for i = 1:16
    fprintf(paletteFid, '%02d    | %3d | %3d | %3d\n', i-1, rgbPalette(i,1), rgbPalette(i,2), rgbPalette(i,3));
end
fclose(paletteFid);

% 7. Export Palette to PNG
palette_strip = zeros(32, 512, 4, 'uint8');
for i = 1:16
    x_start = (i-1) * 32 + 1; x_end = i * 32;
    if i == 1, palette_strip(:, x_start:x_end, :) = 0;
    else
        palette_strip(:, x_start:x_end, 1) = rgbPalette(i, 1);
        palette_strip(:, x_start:x_end, 2) = rgbPalette(i, 2);
        palette_strip(:, x_start:x_end, 3) = rgbPalette(i, 3);
        palette_strip(:, x_start:x_end, 4) = 255;
    end
end
imwrite(palette_strip(:,:,1:3), 'Palette.png', 'Alpha', palette_strip(:,:,4));
end