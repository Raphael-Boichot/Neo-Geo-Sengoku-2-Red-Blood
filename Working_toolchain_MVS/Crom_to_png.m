function Crom_to_png(oddRomFile,evenRomFile,palette,outputPng, outputPalette)
TILES_PER_ROW = 32;

% 2. Load and Verify ROMs
fid1 = fopen(oddRomFile,'rb'); odd = fread(fid1,Inf,'uint8=>uint8'); fclose(fid1);
fid2 = fopen(evenRomFile,'rb'); even = fread(fid2,Inf,'uint8=>uint8'); fclose(fid2);

% 3. Decode
numTiles = numel(odd)/64;
rows = ceil(numTiles/TILES_PER_ROW);
sheet_indices = zeros(rows*16, TILES_PER_ROW*16, 'uint8');

oddOffsets  = (1:2:15)';   % positions within a 16-byte block holding "byte1" of each row
evenOffsets = (2:2:16)';   % positions within a 16-byte block holding "byte2" of each row
posRep = repmat(1:8, 16, 1);  % for unpacking 16 bytes at once into a 16x8 bit matrix

for tile = 0:numTiles-1
    tx = mod(tile, TILES_PER_ROW); ty = floor(tile/TILES_PER_ROW);
    base = tile*64;
    base0 = base; base1 = base+16; base2 = base+32; base3 = base+48;

    % Assemble the 16 bytes (rows 0-15) for each of the 4 bitplanes,
    % left half (x=0..7, blocks b=0,1) and right half (x=8..15, blocks b=2,3)
    byte1L = [odd(base0+oddOffsets);  odd(base1+oddOffsets)];
    byte2L = [odd(base0+evenOffsets); odd(base1+evenOffsets)];
    byte3L = [even(base0+oddOffsets); even(base1+oddOffsets)];
    byte4L = [even(base0+evenOffsets);even(base1+evenOffsets)];

    byte1R = [odd(base2+oddOffsets);  odd(base3+oddOffsets)];
    byte2R = [odd(base2+evenOffsets); odd(base3+evenOffsets)];
    byte3R = [even(base2+oddOffsets); even(base3+oddOffsets)];
    byte4R = [even(base2+evenOffsets);even(base3+evenOffsets)];

    % Unpack each 16x1 byte column into a 16x8 bit matrix (col c = bit position 8-c),
    % done in one call via bitget on replicated bytes/positions.
    unpack = @(byteCol) double(bitget(repmat(byteCol,1,8), posRep));
    b1L = unpack(byte1L); b2L = unpack(byte2L); b3L = unpack(byte3L); b4L = unpack(byte4L);
    b1R = unpack(byte1R); b2R = unpack(byte2R); b3R = unpack(byte3R); b4R = unpack(byte4R);
    % bit position p (1..8) landed in column p; column p corresponds to image col (8-p),
    % so flip columns to get col order 0..7 left-to-right.
    b1L = fliplr(b1L); b2L = fliplr(b2L); b3L = fliplr(b3L); b4L = fliplr(b4L);
    b1R = fliplr(b1R); b2R = fliplr(b2R); b3R = fliplr(b3R); b4R = fliplr(b4R);

    valLeft  = uint8(b1L + 2*b2L + 4*b3L + 8*b4L);   % 16x8
    valRight = uint8(b1R + 2*b2R + 4*b3R + 8*b4R);   % 16x8

    sheet_indices(ty*16+(1:16), tx*16+(1:8))  = valLeft;
    sheet_indices(ty*16+(1:16), tx*16+(9:16)) = valRight;
end

% 5. Create visual PNG
rgbPalette = zeros(16,3,'uint8');
for i=1:16
    if i == 1
        rgbPalette(i,:) = [0 0 0];
    else
        c = uint16(palette(i)); dark = bitget(c,16);
        r = bitshift(bitand(c,hex2dec('0F00')),-8); g = bitshift(bitand(c,hex2dec('00F0')),-4); b = bitand(c,hex2dec('000F'));
        rgbPalette(i,:) = uint8(round(double([bitor(bitshift(r,1),dark), bitor(bitshift(g,1),dark), bitor(bitshift(b,1),dark)])*255/31));
    end
end

% Vectorized palette lookup + alpha mask (replaces the per-pixel y,x loop)
idxPlusOne = double(sheet_indices) + 1;        % 1..16 indices into rgbPalette
R = reshape(rgbPalette(idxPlusOne(:), 1), size(sheet_indices));
G = reshape(rgbPalette(idxPlusOne(:), 2), size(sheet_indices));
B = reshape(rgbPalette(idxPlusOne(:), 3), size(sheet_indices));
A = uint8(sheet_indices ~= 0) * 255;
sheet = cat(3, R, G, B, A);

imwrite(sheet(:,:,1:3), outputPng, 'Alpha', sheet(:,:,4));

% 6. Export Palette to Text File
paletteFid = fopen(outputPalette, 'w');
fprintf(paletteFid, 'Palette Export (RGB 0-255):\n');
fprintf(paletteFid, 'Index | R | G | B\n');
fprintf(paletteFid, '------------------\n');

for i = 1:16
    fprintf(paletteFid, '%02d    | %3d | %3d | %3d\n', ...
        i-1, rgbPalette(i,1), rgbPalette(i,2), rgbPalette(i,3));
end
fclose(paletteFid);

% 7. Export Palette to PNG (Visual Reference)
% Create a 32x512 image (32 pixels high, 16 blocks of 32 pixels wide = 512 wide)
palette_strip = zeros(32, 512, 4, 'uint8');

for i = 1:16
    % Calculate horizontal range for this color block (32 pixels per block)
    x_start = (i-1) * 32 + 1;
    x_end = i * 32;

    % Fill the block
    if i == 1
        palette_strip(:, x_start:x_end, :) = 0; % Transparent
    else
        palette_strip(:, x_start:x_end, 1) = rgbPalette(i, 1);
        palette_strip(:, x_start:x_end, 2) = rgbPalette(i, 2);
        palette_strip(:, x_start:x_end, 3) = rgbPalette(i, 3);
        palette_strip(:, x_start:x_end, 4) = 255; % Opaque
    end
end

imwrite(palette_strip(:,:,1:3), 'Palette.png', 'Alpha', palette_strip(:,:,4));
end