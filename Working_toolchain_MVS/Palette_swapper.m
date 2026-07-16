function Palette_swapper(palette,inputPng,Old_palette)

% 1. Convert Neo Geo 16-bit to 8-bit RGB (vectorized over all 16 entries at once)
New_palette_RGB = zeros(16, 3, 'uint8');

c = uint16(palette(2:16));               % entries 2..16, entry 1 stays [0 0 0]
c = c(:);                                 % ensure column vector

dark = bitget(c, 16);
r = bitshift(bitand(c, hex2dec('0F00')), -8);
g = bitshift(bitand(c, hex2dec('00F0')), -4);
b = bitand(c, hex2dec('000F'));

rgb = uint8(round(double([ ...
    bitor(bitshift(r, 1), dark), ...
    bitor(bitshift(g, 1), dark), ...
    bitor(bitshift(b, 1), dark)]) * 255 / 31));

New_palette_RGB(1, :)    = [0 0 0];
New_palette_RGB(2:16, :) = rgb;

% 2. Load Old Palette
fileID = fopen(Old_palette, 'r');
for i=1:3, fgetl(fileID); end % Skip header
rawPal = fscanf(fileID, '%d | %d | %d | %d\n', [4, 16]);
fclose(fileID);
targetRGB = rawPal(2:4, :)';

% 3. Load PNG and Convert to Index
[img, ~, alpha] = imread(inputPng);

% If the image is RGB but has an alpha channel, combine them
if size(img, 3) == 3 && ~isempty(alpha)
    img = cat(3, img, alpha);
end

[h, w, d] = size(img);
hasAlpha = (d == 4);

% --- Vectorized nearest-color matching (replaces the y/x double loop) ---
pixels = double(reshape(img(:,:,1:3), h*w, 3));   % (h*w) x 3
targets = double(targetRGB(2:16, :));              % 15 x 3

% Squared Euclidean distance, all pixels vs all 15 targets at once
distSq = sum(pixels.^2, 2) + sum(targets.^2, 2)' - 2*(pixels*targets');
[~, minIdx] = min(distSq, [], 2);                  % (h*w) x 1, values 1-15

sheet_indices = reshape(minIdx, h, w);

if hasAlpha
    sheet_indices(img(:,:,4) < 128) = 0; % transparent pixels -> index 0
end

% 4. Substitute colors only for solid pixels (vectorized, replaces the second double loop)
new_img = img; % Start with a copy of the original image to keep alpha intact

solidMask = sheet_indices > 0;              % h x w logical, false where transparent
idxFlat = sheet_indices(solidMask);         % values 1-15 for solid pixels
colorLookup = New_palette_RGB(2:16, :);     % row i -> replacement color for match idx i

R = new_img(:,:,1); G = new_img(:,:,2); B = new_img(:,:,3);
R(solidMask) = colorLookup(idxFlat, 1);
G(solidMask) = colorLookup(idxFlat, 2);
B(solidMask) = colorLookup(idxFlat, 3);
new_img(:,:,1) = R;
new_img(:,:,2) = G;
new_img(:,:,3) = B;

imwrite(new_img(:,:,1:3), inputPng, 'Alpha', new_img(:,:,4));

% 5. Regenerate Palette.txt
fileID = fopen(Old_palette, 'w');
fprintf(fileID, 'Palette Export (RGB 0-255):\nIndex | R | G | B\n------------------\n');
for i = 0:15
    fprintf(fileID, '%02d    | %3d | %3d | %3d\n', i, New_palette_RGB(i+1, 1), New_palette_RGB(i+1, 2), New_palette_RGB(i+1, 3));
end
fclose(fileID);

% 6. Export Palette to PNG (Visual Reference)
% Create a 32x512 image (32 pixels high, 16 blocks of 32 pixels wide = 512 wide)
palette_strip = zeros(32, 512, 4, 'uint8');

for i = 1:16
    % Calculate horizontal range for this color block (32 pixels per block)
    x_start = (i-1) * 32 + 1;
    x_end = i * 32;
    
    % Fill the block
    if i == 1
        palette_strip(:, x_start:x_end, :) = 0; % Transparent
    else
        palette_strip(:, x_start:x_end, 1) = New_palette_RGB(i, 1);
        palette_strip(:, x_start:x_end, 2) = New_palette_RGB(i, 2);
        palette_strip(:, x_start:x_end, 3) = New_palette_RGB(i, 3);
        palette_strip(:, x_start:x_end, 4) = 255; % Opaque
    end
end

imwrite(palette_strip(:,:,1:3), 'Palette.png', 'Alpha', palette_strip(:,:,4));
fprintf('Swapped palette exported as 32x32 blocks to Palette.png\n');
end