clear;

%% Configuration
inputPng     = 'Tileset.png';
paletteFile  = 'Palette.txt';
oddRomOut    = '040-c1.c1.new';
evenRomOut   = '040-c2.c2.new';
TILES_PER_ROW = 32;

%% 1. Load Palette
% Reads the R, G, B values from the provided text file
fileID = fopen(paletteFile, 'r');
% Skip header lines
for i=1:3, fgetl(fileID); end
rawPal = fscanf(fileID, '%d | %d | %d | %d\n', [4, 16]);
fclose(fileID);
targetRGB = rawPal(2:4, :)'; % Extracts 16x3 matrix of RGB values

%% 2. Load PNG and Convert to Index
img = imread(inputPng);
% Handle RGBA if necessary (stripping alpha)
if size(img, 3) == 4, img = img(:,:,1:3); end

[h, w, ~] = size(img);
sheet_indices = zeros(h, w, 'uint8');

% Map each RGB pixel to the closest palette index
for y = 1:h
    for x = 1:w
        pixel = double(reshape(img(y,x,:), 1, 3));
        % Find Euclidean distance to all palette colors
        dist = sum((targetRGB - pixel).^2, 2);
        [~, minIdx] = min(dist);
        sheet_indices(y, x) = minIdx - 1; % 0-15
    end
end

%% 3. Encode to ROM format
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
                % Bit-packing
                oddData(bIdx+1) = bitset(oddData(bIdx+1), p+1, bitget(idx, 1));
                oddData(bIdx+2) = bitset(oddData(bIdx+2), p+1, bitget(idx, 2));
                evenData(bIdx+1) = bitset(evenData(bIdx+1), p+1, bitget(idx, 3));
                evenData(bIdx+2) = bitset(evenData(bIdx+2), p+1, bitget(idx, 4));
            end
        end
    end
end

%% 4. Save and CRC Check
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

fid = fopen(oddRomOut, 'wb'); fwrite(fid, oddData, 'uint8'); fclose(fid);
fid = fopen(evenRomOut, 'wb'); fwrite(fid, evenData, 'uint8'); fclose(fid);

fprintf('Rebuilt %s (CRC: %08X)\n', oddRomOut, calculateCRC32(oddData));
fprintf('Rebuilt %s (CRC: %08X)\n', evenRomOut, calculateCRC32(evenData));