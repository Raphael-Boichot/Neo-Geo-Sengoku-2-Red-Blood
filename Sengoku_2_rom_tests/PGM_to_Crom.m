clear;

%% Configuration
inputPgm = 'Tileset.pgm';
oddRomOut = 'odd_crom.dat'; 
evenRomOut = 'even_crom.dat';
TILES_PER_ROW = 32;

%% 1. Read PGM
fid = fopen(inputPgm, 'rb'); 
fgetl(fid); dims = strsplit(fgetl(fid));
width = str2double(dims{1}); height = str2double(dims{2}); 
fgetl(fid); % Skip '15'
rawIndices = fread(fid, [width, height], 'uint8')'; 
fclose(fid);

%% 3. Encode
numTiles = floor(height/16) * TILES_PER_ROW;
oddData = zeros(numTiles*64, 1, 'uint8'); 
evenData = zeros(numTiles*64, 1, 'uint8');
blockX = [0 0 8 8]; blockY = [0 8 0 8];

for tile = 0:numTiles-1
    tx = mod(tile, TILES_PER_ROW); ty = floor(tile/TILES_PER_ROW);
    tileIdx = rawIndices(ty*16+(1:16), tx*16+(1:16));
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