function Palette_swapper(palette,inputPng,Old_palette)

% 1. Convert Neo Geo 16-bit to 8-bit RGB
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

for y = 1:h
    for x = 1:w
        % Check Alpha channel first
        if hasAlpha && img(y, x, 4) < 128 % Threshold for transparency
            sheet_indices(y, x) = 0;
        else
            % Perform matching against indices 1 through 15 only
            pixel = double(reshape(img(y,x,1:3), 1, 3));
            % Only compare against targetRGB rows 2-16 (ignoring the entry 0 color)
            dist = sum((targetRGB(2:16, :) - pixel).^2, 2);
            [~, minIdx] = min(dist);
            sheet_indices(y, x) = minIdx; % This now maps to 1-15
        end
    end
end

% 4. Substitute colors only for solid pixels
new_img = img; % Start with a copy of the original image to keep alpha intact

for y = 1:h
    for x = 1:w
        % Only process pixels that are NOT transparent
        if hasAlpha && img(y, x, 4) < 128
            % Do nothing: keep the original pixel (transparency/attributes preserved)
        else
            % Identify which palette index this pixel belongs to (1-15)
            % We use the sheet_indices logic we already calculated
            idx = sheet_indices(y, x);
            
            % If it matched a palette entry, replace the color
            if idx > 0
                new_img(y, x, 1) = New_palette_RGB(idx+1, 1);
                new_img(y, x, 2) = New_palette_RGB(idx+1, 2);
                new_img(y, x, 3) = New_palette_RGB(idx+1, 3);
            end
        end
    end
end
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