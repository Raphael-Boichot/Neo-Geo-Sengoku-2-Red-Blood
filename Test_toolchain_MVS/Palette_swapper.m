function Palette_swapper(palette, inputPng, Old_palette)

% 1. Load Palette
fileID = fopen(Old_palette, 'r');
if fileID == -1, error('Could not open palette file: %s', Old_palette); end
line1 = fgetl(fileID);
totalTiles = sscanf(line1, 'Total Tiles: %d'); 
for i=1:3, fgetl(fileID); end 
rawPal = fscanf(fileID, '%d | %d | %d | %d\n', [4, 16]);
targetRGB = rawPal(2:4, :)'; 
fclose(fileID);

% 2. Convert Neo Geo 16-bit to 8-bit RGB
New_palette_RGB = zeros(16, 3, 'uint8');
for i = 1:16
    if i == 1
        New_palette_RGB(i, :) = [0 0 0];
    else
        c = uint16(palette(i));
        dark = bitget(c, 16);
        r = bitshift(bitand(c, hex2dec('0F00')), -8);
        g = bitshift(bitand(c, hex2dec('00F0')), -4);
        b = bitand(c, hex2dec('000F'));
        
        New_palette_RGB(i, :) = uint8(round(double([ ...
            bitor(bitshift(r, 1), dark), ...
            bitor(bitshift(g, 1), dark), ...
            bitor(bitshift(b, 1), dark)]) * 255 / 31));
    end
end

% 3. Load PNG and Convert to Index
[img, ~, alpha] = imread(inputPng);
if size(img, 3) == 3 && ~isempty(alpha)
    img = cat(3, img, alpha);
end

% Get actual dimensions from the loaded image
[h, w, ~] = size(img);
hasAlpha = (size(img, 3) == 4);
sheet_indices = zeros(h, w);

for y = 1:h
    for x = 1:w
        if hasAlpha && img(y, x, 4) < 128
            sheet_indices(y, x) = 0;
        else
            pixel = double(reshape(img(y,x,1:3), 1, 3));
            dist = sum((targetRGB(2:16, :) - pixel).^2, 2);
            [~, minIdx] = min(dist);
            sheet_indices(y, x) = minIdx;
        end
    end
end

% 4. Substitute colors only for solid pixels
new_img = img;
for y = 1:h
    for x = 1:w
        if ~(hasAlpha && img(y, x, 4) < 128)
            idx = sheet_indices(y, x);
            if idx > 0
                new_img(y, x, 1) = New_palette_RGB(idx+1, 1);
                new_img(y, x, 2) = New_palette_RGB(idx+1, 2);
                new_img(y, x, 3) = New_palette_RGB(idx+1, 3);
            end
        end
    end
end
imwrite(new_img(:,:,1:3), inputPng, 'Alpha', new_img(:,:,4));

% 5. Export Palette and Metadata
paletteFid = fopen(Old_palette, 'w');
fprintf(paletteFid, 'Total Tiles: %d\n', totalTiles);
fprintf(paletteFid, 'Palette Export (RGB 0-255):\n');
fprintf(paletteFid, 'Index | R | G | B\n');
fprintf(paletteFid, '------------------\n');
for i = 1:16
    fprintf(paletteFid, '%02d    | %3d | %3d | %3d\n', i-1, New_palette_RGB(i,1), New_palette_RGB(i,2), New_palette_RGB(i,3));
end
fclose(paletteFid);

% 6. Export Palette to PNG
palette_strip = zeros(32, 512, 4, 'uint8');
for i = 1:16
    x_start = (i-1) * 32 + 1;
    x_end = i * 32;
    if i == 1
        palette_strip(:, x_start:x_end, :) = 0;
    else
        palette_strip(:, x_start:x_end, 1) = New_palette_RGB(i, 1);
        palette_strip(:, x_start:x_end, 2) = New_palette_RGB(i, 2);
        palette_strip(:, x_start:x_end, 3) = New_palette_RGB(i, 3);
        palette_strip(:, x_start:x_end, 4) = 255;
    end
end
imwrite(palette_strip(:,:,1:3), 'Palette.png', 'Alpha', palette_strip(:,:,4));
fprintf('Swapped palette exported. Processed %d tiles.\n', totalTiles);
end