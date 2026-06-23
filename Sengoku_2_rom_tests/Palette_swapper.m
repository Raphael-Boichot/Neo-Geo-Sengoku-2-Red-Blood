clear;

%% Configuration
inputPng     = 'Tileset.png';
Old_palette  = 'Palette.txt';
% Neo Geo palette hex values
rawHex = [0x0010,0x7810,0x0C74,0x5FC9,0x5409,0x1A0F,0x1F9F,0x0800,0x0C00,0x4F93,0x0666,0x7AAA,0x0EEE,0x7334,0x4500,0x7111];

% Convert Neo Geo 16-bit to 8-bit RGB
% Format: DarkBit(15) | R4 R3 R2 R1 R0(14-10) | G4 G3 G2 G1 G0(9-5) | B4 B3 B2 B1 B0(4-0)
% Note: The "dark bit" is often ignored or used as a global LSB; 
% this implementation maps the 5-bit channels to 8-bit scale.
New_palette_RGB = zeros(16, 3, 'uint8');
for i = 1:16
    val = rawHex(i);
    % Extract bits: 
    % R = bits 14-10, G = bits 9-5, B = bits 4-0
    r = bitand(bitshift(val, -10), 31);
    g = bitand(bitshift(val, -5), 31);
    b = bitand(val, 31);
    
    % Scale 5-bit (0-31) to 8-bit (0-255)
    New_palette_RGB(i, 1) = uint8(round((r * 255) / 31));
    New_palette_RGB(i, 2) = uint8(round((g * 255) / 31));
    New_palette_RGB(i, 3) = uint8(round((b * 255) / 31));
end

%% 1. Load Old Palette
fileID = fopen(Old_palette, 'r');
for i=1:3, fgetl(fileID); end % Skip header
rawPal = fscanf(fileID, '%d | %d | %d | %d\n', [4, 16]);
fclose(fileID);
targetRGB = rawPal(2:4, :)'; 

%% 2. Load PNG and Convert to Index
img = imread(inputPng);
if size(img, 3) == 4, img = img(:,:,1:3); end

[h, w, ~] = size(img);
sheet_indices = zeros(h, w, 'uint8');

for y = 1:h
    for x = 1:w
        pixel = double(reshape(img(y,x,:), 1, 3));
        dist = sum((targetRGB - pixel).^2, 2);
        [~, minIdx] = min(dist);
        sheet_indices(y, x) = minIdx - 1; 
    end
end

%% 3. Remap to New Palette
new_img = zeros(h, w, 3, 'uint8');
for i = 0:15
    mask = (sheet_indices == i);
    new_img(:,:,1) = new_img(:,:,1) + uint8(mask) * New_palette_RGB(i+1, 1);
    new_img(:,:,2) = new_img(:,:,2) + uint8(mask) * New_palette_RGB(i+1, 2);
    new_img(:,:,3) = new_img(:,:,3) + uint8(mask) * New_palette_RGB(i+1, 3);
end

imwrite(new_img, inputPng);

%% 4. Regenerate Palette.txt
fileID = fopen(Old_palette, 'w');
fprintf(fileID, 'Palette Export (RGB 0-255):\nIndex | R | G | B\n------------------\n');
for i = 0:15
    fprintf(fileID, '%02d    | %3d | %3d | %3d\n', i, New_palette_RGB(i+1, 1), New_palette_RGB(i+1, 2), New_palette_RGB(i+1, 3));
end
fclose(fileID);