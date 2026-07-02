function Cspr_to_png(sprFile, palette, outputPng, outputPalette)
TILES_PER_ROW = 32;

% 1. CRC32 Check
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

% 2. Load ROM
fid = fopen(sprFile,'rb'); sprData = fread(fid,Inf,'uint8=>uint8'); fclose(fid);
fprintf('Source %s (CRC32: %08X)\n', sprFile, calculateCRC32(sprData));

% 3. Decode
numTiles = floor(numel(sprData)/128);
rows = ceil(numTiles/TILES_PER_ROW);
sheet_indices = zeros(rows*16, TILES_PER_ROW*16, 'uint8');

blockX = [8 8 0 0]; blockY = [0 8 0 8];

for tile = 0:numTiles-1
    base = tile*128;
    tx = mod(tile, TILES_PER_ROW); ty = floor(tile/TILES_PER_ROW);

    for b = 0:3
        xOfs = blockX(b+1); yOfs = blockY(b+1);
        blockBase = base + (b * 32);

        for row = 0:7
            rowBase = blockBase + (row * 4);
            p1 = sprData(rowBase + 1); p0 = sprData(rowBase + 2);
            p3 = sprData(rowBase + 3); p2 = sprData(rowBase + 4);

            for col = 0:7
                bitPos = col; % FIX: Removed inversion (7-col) to correct horizontal flip
                val = bitget(p0, bitPos+1) + ...
                    bitshift(bitget(p1, bitPos+1), 1) + ...
                    bitshift(bitget(p2, bitPos+1), 2) + ...
                    bitshift(bitget(p3, bitPos+1), 3);
                sheet_indices(ty*16+yOfs+row+1, tx*16+xOfs+col+1) = uint8(val);
            end
        end
    end
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

sheet = zeros(size(sheet_indices,1), size(sheet_indices,2), 4, 'uint8');
for y=1:size(sheet_indices,1)
    for x=1:size(sheet_indices,2)
        tileX = floor((x-1) / 16);
        tileY = floor((y-1) / 16);
        tileIdx = tileY * TILES_PER_ROW + tileX;

        if tileIdx >= numTiles
            % Updated: Transparent black padding
            sheet(y,x,:) = [0, 0, 0, 0];
        else
            idx = sheet_indices(y,x);
            if idx == 0, sheet(y,x,:) = [0, 0, 0, 0]; else, sheet(y,x,:) = [rgbPalette(idx+1,:), 255]; end
        end
    end
end
imwrite(sheet(:,:,1:3), outputPng, 'Alpha', sheet(:,:,4));

% 6. Export Palette and Metadata
paletteFid = fopen(outputPalette, 'w');
fprintf(paletteFid, 'Total Tiles: %d\n', numTiles); % Added tile count metadata
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