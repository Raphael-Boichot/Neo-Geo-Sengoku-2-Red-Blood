function png_to_Cspr(sprOut, inputPng, paletteFile)
TILES_PER_ROW = 32;

% 1. CRC32 Function
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

% 2. Load Palette
fileID = fopen(paletteFile, 'r');
if fileID == -1, error('Could not open palette file: %s', paletteFile); end
for i=1:3, fgetl(fileID); end 
rawPal = fscanf(fileID, '%d | %d | %d | %d\n', [4, 16]);
fclose(fileID);
targetRGB = rawPal(2:4, :)'; 

% 3. Load PNG and Convert to Index
[img, ~, alpha] = imread(inputPng);
if size(alpha, 3) > 1, alpha = alpha(:,:,4); end 

[h, w, ~] = size(img);
sheet_indices = zeros(h, w, 'uint8');
solidPalette = targetRGB(2:16, :); 

for y = 1:h
    for x = 1:w
        if alpha(y, x) == 0
            sheet_indices(y, x) = 0;
        else
            pixel = reshape(img(y, x, :), 1, 3);
            matchIdx = find(all(solidPalette == pixel, 2));
            if ~isempty(matchIdx)
                sheet_indices(y, x) = matchIdx(1); 
            else
                error('Pixel at (%d, %d) does not match palette.', x, y);
            end
        end
    end
end

% 4. Encode to .spr
numTiles = floor(h/16) * floor(w/16);
sprData = zeros(numTiles*128, 1, 'uint8');
blockX = [8 8 0 0]; blockY = [0 8 0 8];

for tile = 0:numTiles-1
    tx = mod(tile, TILES_PER_ROW); ty = floor(tile/TILES_PER_ROW);
    tileIdx = sheet_indices(ty*16+(1:16), tx*16+(1:16));
    
    for b = 0:3
        blockBase = tile*128 + b*32;
        for row = 0:7
            rowBits = tileIdx(blockY(b+1)+row+1, blockX(b+1)+(1:8));
            p1 = 0; p0 = 0; p3 = 0; p2 = 0;
            for col = 0:7
                val = rowBits(col+1);
                p0 = bitset(p0, 8-col, bitget(val, 1));
                p1 = bitset(p1, 8-col, bitget(val, 2));
                p2 = bitset(p2, 8-col, bitget(val, 3));
                p3 = bitset(p3, 8-col, bitget(val, 4));
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

fprintf('Rebuilt %s (CRC32: %08X)\n', sprOut, calculateCRC32(sprData));
end