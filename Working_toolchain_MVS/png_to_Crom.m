function png_to_Crom(oddRomOut, evenRomOut,inputPng, paletteFile)
TILES_PER_ROW = 32;

% 1. Load Palette
fileID = fopen(paletteFile, 'r');
if fileID == -1, error('Could not open palette file: %s', paletteFile); end
for i=1:3, fgetl(fileID); end
rawPal = fscanf(fileID, '%d | %d | %d | %d\n', [4, 16]);
fclose(fileID);
targetRGB = rawPal(2:4, :)';

% 2. Load PNG and Convert to Index
[img, ~, alpha] = imread(inputPng);
% Ensure alpha is 2D if the input was an indexed image
if size(alpha, 3) > 1, alpha = alpha(:,:,4); end

% Convert indexed images to RGB if necessary
if ~isempty(find(size(img) > 0, 1)) && size(img, 3) ~= 3
    img = ind2rgb(img, map);
    img = uint8(img * 255);
end

[h, w, ~] = size(img);
sheet_indices = zeros(h, w, 'uint8');

% targetRGB is 16x3.
% We want to search for solid colors only in rows 2 to 16 (indices 1 to 15)
solidPalette = targetRGB(2:16, :);

for y = 1:h
    for x = 1:w
        % Rule: If fully transparent, index is 0
        if alpha(y, x) == 0
            sheet_indices(y, x) = 0;
        else
            pixel = reshape(img(y, x, :), 1, 3);

            % Rule: Search only among the 15 non-transparent palette entries
            matchIdx = find(all(solidPalette == pixel, 2));

            if ~isempty(matchIdx)
                % matchIdx is 1-15, which corresponds to the correct ROM index
                sheet_indices(y, x) = matchIdx(1);
            else
                error('Error: Pixel at (%d, %d) [RGB: %d,%d,%d] does not match any valid non-transparent palette entry.', ...
                    x, y, pixel(1), pixel(2), pixel(3));
            end
        end
    end
end

% 3. Encode to ROM format
numTiles = floor(h/16) * floor(w/16);
oddData  = zeros(numTiles*64, 1, 'uint8');
evenData = zeros(numTiles*64, 1, 'uint8');
blockX = [0 0 8 8]; blockY = [0 8 0 8];

for tile = 0:numTiles-1
    tx = mod(tile, TILES_PER_ROW); ty = floor(tile/TILES_PER_ROW);
    tileIdx = sheet_indices(ty*16+(1:16), tx*16+(1:16));
    for b = 0:3
        for row = 0:7
            for col = 0:7
                idx = tileIdx(blockY(b+1)+row+1, blockX(b+1)+col+1);
                bIdx = tile*64 + b*16 + row*2; p = 7-col;
                oddData(bIdx+1) = bitset(oddData(bIdx+1), p+1, bitget(idx, 1));
                oddData(bIdx+2) = bitset(oddData(bIdx+2), p+1, bitget(idx, 2));
                evenData(bIdx+1) = bitset(evenData(bIdx+1), p+1, bitget(idx, 3));
                evenData(bIdx+2) = bitset(evenData(bIdx+2), p+1, bitget(idx, 4));
            end
        end
    end
end

% Save files directly to provided paths
fileNames = {oddRomOut, evenRomOut};
dataSets = {oddData, evenData};

for i = 1:2
    fid = fopen(fileNames{i}, 'wb');
    if fid == -1
        error('Failed to open file for writing: %s. Ensure the directory exists and is writable.', fileNames{i});
    end
    fwrite(fid, dataSets{i}, 'uint8');
    fclose(fid);
    fprintf('Rebuilt %s (CRC32: %08X)\n', fileNames{i}, computeCRC32(fileNames{i}));
end
end