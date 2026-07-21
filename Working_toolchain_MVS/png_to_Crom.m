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
[img, map, alpha] = imread(inputPng);
% Ensure alpha is 2D if the input was an indexed image
if size(alpha, 3) > 1, alpha = alpha(:,:,4); end

% Convert indexed images to RGB if necessary
if ~isempty(find(size(img) > 0, 1)) && size(img, 3) ~= 3
    img = ind2rgb(img, map);
    img = uint8(img * 255);
end

[h, w, ~] = size(img);

% targetRGB is 16x3.
% We want to search for solid colors only in rows 2 to 16 (indices 1 to 15)
solidPalette = double(targetRGB(2:16, :));

% --- Vectorized pixel -> palette-index classification ---
imgR = double(img(:,:,1));
imgG = double(img(:,:,2));
imgB = double(img(:,:,3));

sheet_indices = zeros(h, w, 'uint8');
matched = (alpha == 0);   % fully transparent pixels are already "resolved" to index 0

for k = 1:15
    mask = (imgR == solidPalette(k,1)) & (imgG == solidPalette(k,2)) & (imgB == solidPalette(k,3));
    mask = mask & ~matched;            % don't overwrite transparent pixels
    sheet_indices(mask) = k;
    matched = matched | mask;
end

if any(~matched(:))
    [yy, xx] = find(~matched, 1);
    pixel = double(reshape(img(yy, xx, :), 1, 3));
    error('Error: Pixel at (%d, %d) [RGB: %d,%d,%d] does not match any valid non-transparent palette entry.', ...
        xx, yy, pixel(1), pixel(2), pixel(3));
end

% 3. Encode to ROM format
numTiles = floor(h/16) * floor(w/16);
oddData  = zeros(numTiles*64, 1, 'uint8');
evenData = zeros(numTiles*64, 1, 'uint8');

weights = (2.^(7:-1:0))';   % 8x1 column of bit weights (MSB first), for packing a row of 8 bits into a byte
oddOffsets  = (1:2:15)';    % positions within a 16-byte block that hold "byte1" of each row
evenOffsets = (2:2:16)';    % positions within a 16-byte block that hold "byte2" of each row

for tile = 0:numTiles-1
    tx = mod(tile, TILES_PER_ROW); ty = floor(tile/TILES_PER_ROW);
    tileIdx = double(sheet_indices(ty*16+(1:16), tx*16+(1:16)));  % 16x16, rows=y(0-15), cols=x(0-15)

    left  = tileIdx(:, 1:8);   % x = 0..7   (16 rows)
    right = tileIdx(:, 9:16);  % x = 8..15  (16 rows)

    % Pack each row's 8 bits (col 0 -> MSB ... col 7 -> LSB) into a byte, for all 4 bitplanes at once.
    b1L = uint8(bitget(left,  1) * weights);  b2L = uint8(bitget(left,  2) * weights);
    b3L = uint8(bitget(left,  3) * weights);  b4L = uint8(bitget(left,  4) * weights);
    b1R = uint8(bitget(right, 1) * weights);  b2R = uint8(bitget(right, 2) * weights);
    b3R = uint8(bitget(right, 3) * weights);  b4R = uint8(bitget(right, 4) * weights);

    base = tile*64;
    % Block layout matches blockX=[0 0 8 8], blockY=[0 8 0 8]:
    %   b=0 -> left,  rows 1:8   (top-left)
    %   b=1 -> left,  rows 9:16  (bottom-left)
    %   b=2 -> right, rows 1:8   (top-right)
    %   b=3 -> right, rows 9:16  (bottom-right)
    base0 = base;      % b=0
    base1 = base + 16; % b=1
    base2 = base + 32; % b=2
    base3 = base + 48; % b=3

    oddData(base0 + oddOffsets)  = b1L(1:8);   oddData(base0 + evenOffsets)  = b2L(1:8);
    evenData(base0 + oddOffsets) = b3L(1:8);   evenData(base0 + evenOffsets) = b4L(1:8);

    oddData(base1 + oddOffsets)  = b1L(9:16);  oddData(base1 + evenOffsets)  = b2L(9:16);
    evenData(base1 + oddOffsets) = b3L(9:16);  evenData(base1 + evenOffsets) = b4L(9:16);

    oddData(base2 + oddOffsets)  = b1R(1:8);   oddData(base2 + evenOffsets)  = b2R(1:8);
    evenData(base2 + oddOffsets) = b3R(1:8);   evenData(base2 + evenOffsets) = b4R(1:8);

    oddData(base3 + oddOffsets)  = b1R(9:16);  oddData(base3 + evenOffsets)  = b2R(9:16);
    evenData(base3 + oddOffsets) = b3R(9:16);  evenData(base3 + evenOffsets) = b4R(9:16);
end

% Save files directly to provided paths
fileNames = {oddRomOut, evenRomOut};
dataSets = {oddData, evenData};

for i = 1:2
    fid = fopen(fileNames{i}, 'wb');
    fwrite(fid, dataSets{i}, 'uint8');
    fclose(fid);
end