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

[h, w, ~] = size(img);
solidPalette = double(targetRGB(2:16, :)); % Indices 1-15

% --- Vectorized pixel -> palette-index classification (whole image at once) ---
imgR = double(img(:,:,1));
imgG = double(img(:,:,2));
imgB = double(img(:,:,3));

sheet_indices = zeros(h, w, 'uint8');
matched = (alpha == 0);   % fully transparent pixels are already "resolved" to index 0

for k = 1:15
    mask = (imgR == solidPalette(k,1)) & (imgG == solidPalette(k,2)) & (imgB == solidPalette(k,3));
    mask = mask & ~matched;
    sheet_indices(mask) = k;
    matched = matched | mask;
end

if any(~matched(:))
    [yy, xx] = find(~matched, 1);
    pixel = double(reshape(img(yy, xx, :), 1, 3));
    error('Opaque pixel at (%d, %d) [RGB: %d,%d,%d] not in palette (1-15).', xx, yy, pixel(1), pixel(2), pixel(3));
end

% 4. Encode to .spr
sprData = zeros(totalTiles*128, 1, 'uint8');

weights = (2.^(0:7))';        % col c (0..7) -> bit position c+1 (col0 = LSB)
rOffsets = (0:7)'*4;          % byte offset of each row's 4-byte group within a block

for tile = 0:totalTiles-1
    tx = mod(tile, TILES_PER_ROW); ty = floor(tile/TILES_PER_ROW);
    tileIdx = double(sheet_indices(ty*16+(1:16), tx*16+(1:16)));  % 16x16, rows=y(0-15), cols=x(0-15)

    left  = tileIdx(:, 1:8);   % x = 0..7  (blocks b=2 top, b=3 bottom)
    right = tileIdx(:, 9:16);  % x = 8..15 (blocks b=0 top, b=1 bottom)

    % Pack each row's 8 pixel values into 4 bitplane bytes at once (col c -> bit c+1)
    p0L = uint8(bitget(left, 1) * weights); p1L = uint8(bitget(left, 2) * weights);
    p2L = uint8(bitget(left, 3) * weights); p3L = uint8(bitget(left, 4) * weights);
    p0R = uint8(bitget(right,1) * weights); p1R = uint8(bitget(right,2) * weights);
    p2R = uint8(bitget(right,3) * weights); p3R = uint8(bitget(right,4) * weights);

    base = tile*128;
    % blockX=[8 8 0 0], blockY=[0 8 0 8]:
    %   b=0 -> right half, rows 1:8   (top,    x=8)
    %   b=1 -> right half, rows 9:16  (bottom, x=8)
    %   b=2 -> left half,  rows 1:8   (top,    x=0)
    %   b=3 -> left half,  rows 9:16  (bottom, x=0)
    base0 = base;      % b=0
    base1 = base + 32; % b=1
    base2 = base + 64; % b=2
    base3 = base + 96; % b=3

    sprData(base0+rOffsets+1) = p1R(1:8);   sprData(base0+rOffsets+2) = p0R(1:8);
    sprData(base0+rOffsets+3) = p3R(1:8);   sprData(base0+rOffsets+4) = p2R(1:8);

    sprData(base1+rOffsets+1) = p1R(9:16);  sprData(base1+rOffsets+2) = p0R(9:16);
    sprData(base1+rOffsets+3) = p3R(9:16);  sprData(base1+rOffsets+4) = p2R(9:16);

    sprData(base2+rOffsets+1) = p1L(1:8);   sprData(base2+rOffsets+2) = p0L(1:8);
    sprData(base2+rOffsets+3) = p3L(1:8);   sprData(base2+rOffsets+4) = p2L(1:8);

    sprData(base3+rOffsets+1) = p1L(9:16);  sprData(base3+rOffsets+2) = p0L(9:16);
    sprData(base3+rOffsets+3) = p3L(9:16);  sprData(base3+rOffsets+4) = p2L(9:16);
end

% 5. Save and Verify
fid = fopen(sprOut, 'wb');
if fid == -1, error('Cannot open output file.'); end
fwrite(fid, sprData, 'uint8');
fclose(fid);
fprintf('Rebuilt %s (CRC32: %08X)\n', sprOut, computeCRC32(sprOut));