function png_to_Crom(oddRomOut, evenRomOut,inputPng)
TILES_PER_ROW = 32;
% Configuration
paletteFile  = 'Palette.txt';

% 1. Load Palette
fileID = fopen(paletteFile, 'r');
if fileID == -1, error('Could not open palette file: %s', paletteFile); end
for i=1:3, fgetl(fileID); end
rawPal = fscanf(fileID, '%d | %d | %d | %d\n', [4, 16]);
fclose(fileID);
targetRGB = rawPal(2:4, :)'; 

% 2. Load PNG and Convert to Index
img = imread(inputPng);
if size(img, 3) == 4
    alpha = img(:,:,4);
    img_rgb = img(:,:,1:3);
else
    alpha = ones(size(img,1), size(img,2), 'uint8') * 255;
    img_rgb = img;
end

[h, w, ~] = size(img_rgb);
sheet_indices = zeros(h, w, 'uint8');

for y = 1:h
    for x = 1:w
        if alpha(y, x) == 0
            sheet_indices(y, x) = 0;
        else
            pixel = reshape(img_rgb(y,x,:), 1, 3);
            matchIdx = find(all(targetRGB == pixel, 2));
            if ~isempty(matchIdx)
                sheet_indices(y, x) = matchIdx(1) - 1;
            else
                error('Error: Pixel at coordinates (%d, %d) does not match any color in the provided palette.', x, y);
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

% 4. Save and CRC Check
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
    fprintf('Rebuilt %s (CRC32: %08X)\n', fileNames{i}, calculateCRC32(dataSets{i}));
end
end