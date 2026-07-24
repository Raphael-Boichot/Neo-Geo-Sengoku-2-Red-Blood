function Cspr_to_png(sprFile, palette, outputPng, outputPalette)
TILES_PER_ROW = 32;

% 1. Talk
disp(['Dealing with ',sprFile]);
disp(['Generating ', outputPng,' and ',outputPalette]);

% 2. Load ROM
fid = fopen(sprFile,'rb'); sprData = fread(fid,Inf,'uint8=>uint8'); fclose(fid);

% 3. Decode
numTiles = floor(numel(sprData)/128);
rows = ceil(numTiles/TILES_PER_ROW);
sheet_indices = zeros(rows*16, TILES_PER_ROW*16, 'uint8');

rOffsets = (0:7)'*4;          % byte offset of each row's 4-byte group within a block
posRep = repmat(1:8, 16, 1);  % for unpacking 16 bytes at once into a 16x8 bit matrix

for tile = 0:numTiles-1
    base = tile*128;
    tx = mod(tile, TILES_PER_ROW); ty = floor(tile/TILES_PER_ROW);

    % blockX=[8 8 0 0], blockY=[0 8 0 8]:
    %   b=0 -> x=8, rows 1:8   (top,    right half)
    %   b=1 -> x=8, rows 9:16  (bottom, right half)
    %   b=2 -> x=0, rows 1:8   (top,    left half)
    %   b=3 -> x=0, rows 9:16  (bottom, left half)
    base0 = base;      % b=0
    base1 = base + 32; % b=1
    base2 = base + 64; % b=2
    base3 = base + 96; % b=3

    rightP1 = [sprData(base0+rOffsets+1); sprData(base1+rOffsets+1)];
    rightP0 = [sprData(base0+rOffsets+2); sprData(base1+rOffsets+2)];
    rightP3 = [sprData(base0+rOffsets+3); sprData(base1+rOffsets+3)];
    rightP2 = [sprData(base0+rOffsets+4); sprData(base1+rOffsets+4)];

    leftP1 = [sprData(base2+rOffsets+1); sprData(base3+rOffsets+1)];
    leftP0 = [sprData(base2+rOffsets+2); sprData(base3+rOffsets+2)];
    leftP3 = [sprData(base2+rOffsets+3); sprData(base3+rOffsets+3)];
    leftP2 = [sprData(base2+rOffsets+4); sprData(base3+rOffsets+4)];

    % Unpack each 16x1 byte column into a 16x8 bit matrix in one call.
    % bitPos = col (no inversion), so column p directly corresponds to image col (p-1) - no flip needed.
    unpack = @(byteCol) double(bitget(repmat(byteCol,1,8), posRep));

    valRight = uint8(unpack(rightP0) + 2*unpack(rightP1) + 4*unpack(rightP2) + 8*unpack(rightP3)); % 16x8
    valLeft  = uint8(unpack(leftP0)  + 2*unpack(leftP1)  + 4*unpack(leftP2)  + 8*unpack(leftP3));  % 16x8

    sheet_indices(ty*16+(1:16), tx*16+(1:8))    = valLeft;   % xOfs = 0
    sheet_indices(ty*16+(1:16), tx*16+(9:16))   = valRight;  % xOfs = 8
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

% Vectorized replacement for the per-pixel y,x loop
[H, W] = size(sheet_indices);
[xg, yg] = meshgrid(0:W-1, 0:H-1);           % xg,yg == (x-1),(y-1) from the original 1-indexed loop
tileX = floor(xg/16); tileY = floor(yg/16);
tileIdxMat = tileY*TILES_PER_ROW + tileX;
validMask = tileIdxMat < numTiles;

idxPlusOne = double(sheet_indices) + 1;
Rall = reshape(rgbPalette(idxPlusOne(:), 1), H, W);
Gall = reshape(rgbPalette(idxPlusOne(:), 2), H, W);
Ball = reshape(rgbPalette(idxPlusOne(:), 3), H, W);

opaqueMask = validMask & (sheet_indices ~= 0);
R = zeros(H, W, 'uint8'); G = zeros(H, W, 'uint8'); B = zeros(H, W, 'uint8');
R(opaqueMask) = Rall(opaqueMask);
G(opaqueMask) = Gall(opaqueMask);
B(opaqueMask) = Ball(opaqueMask);
A = uint8(opaqueMask) * 255;

sheet = cat(3, R, G, B, A);
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