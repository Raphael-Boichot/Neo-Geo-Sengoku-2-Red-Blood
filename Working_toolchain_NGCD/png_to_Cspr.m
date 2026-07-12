function png_to_Cspr(sprOut, inputPng, paletteFile)
TILES_PER_ROW = 32;

% 2. Load Palette
fileID = fopen(paletteFile, 'r');
if fileID == -1, error('Could not open palette file: %s', paletteFile); end
line1 = fgetl(fileID);
totalTiles = sscanf(line1, 'Total Tiles: %d');
for i=1:3, fgetl(fileID); end
rawPal = fscanf(fileID, '%d | %d | %d | %d\n', [4, 16]);
fclose(fileID);
targetRGB = rawPal(2:4, :)';

% 3. Load PNG
[img, ~, alpha] = imread(inputPng);
if size(alpha, 3) > 1, alpha = alpha(:,:,4); end

% 4. Encode to .spr
sprData = zeros(totalTiles*128, 1, 'uint8');
solidPalette = targetRGB(2:16, :); % Indices 1-15
blockX = [8 8 0 0]; blockY = [0 8 0 8];

for tile = 0:totalTiles-1
    tx = mod(tile, TILES_PER_ROW); ty = floor(tile/TILES_PER_ROW);
    pixelY_start = ty * 16 + 1;
    pixelX_start = tx * 16 + 1;

    tileIdx = zeros(16, 16, 'uint8');
    for py = 0:15
        for px = 0:15
            y = pixelY_start + py; x = pixelX_start + px;

            % Enforce transparency for Alpha=0
            if alpha(y, x) == 0
                tileIdx(py+1, px+1) = 0;
            else
                % Match opaque pixels against solid palette (1-15)
                pixel = reshape(img(y, x, :), 1, 3);
                matchIdx = find(all(solidPalette == pixel, 2));

                if ~isempty(matchIdx)
                    tileIdx(py+1, px+1) = uint8(matchIdx(1));
                else
                    error('Opaque pixel at (%d, %d) [RGB: %d,%d,%d] not in palette (1-15).', x, y, pixel(1), pixel(2), pixel(3));
                end
            end
        end
    end

    % Encode tile
    for b = 0:3
        blockBase = tile*128 + b*32;
        for row = 0:7
            rowBits = tileIdx(blockY(b+1)+row+1, blockX(b+1)+(1:8));
            p1 = 0; p0 = 0; p3 = 0; p2 = 0;
            for col = 0:7
                val = rowBits(col+1);
                p0 = bitset(p0, col+1, bitget(val, 1));
                p1 = bitset(p1, col+1, bitget(val, 2));
                p2 = bitset(p2, col+1, bitget(val, 3));
                p3 = bitset(p3, col+1, bitget(val, 4));
            end
            rowOffset = blockBase + row*4;
            sprData(rowOffset+1) = p1;
            sprData(rowOffset+2) = p0;
            sprData(rowOffset+3) = p3;
            sprData(rowOffset+4) = p2;
        end
    end
end

% 5. Save and Verify
fid = fopen(sprOut, 'wb');
if fid == -1, error('Cannot open output file.'); end
fwrite(fid, sprData, 'uint8');
fclose(fid);
fprintf('Rebuilt %s (CRC32: %08X)\n', sprOut, computeCRC32(sprOut));