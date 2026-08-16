clear
clc

% Specify input and output filenames
inputFilename = 'Tileset_MVS_modified_small.png';
outputFilename = 'Tileset_MVS_modified_small_flipped.png';

% Read the image, colormap, and alpha channel
[img, map, alpha] = imread(inputFilename);

% Determine image dimensions
[imgHeight, imgWidth, numChannels] = size(img);

% Ensure the image dimensions are multiples of 16
tileSize = 16;
if mod(imgWidth, tileSize) ~= 0 || mod(imgHeight, tileSize) ~= 0
    error('Image width and height must be multiples of 16 pixels.');
end

% Handle indexed images vs truecolor RGB images
hasAlpha = false;
if ~isempty(map)
    % If it's an indexed image, convert to RGB to easily process tile flipping
    img = ind2rgb(img, map);
    [imgHeight, imgWidth, ~] = size(img);
end

if ~isempty(alpha)
    hasAlpha = true;
elseif numChannels == 4
    hasAlpha = true;
    alpha = img(:, :, 4);
    img = img(:, :, 1:3);
end

% Create a copy of the image and alpha arrays to store the modified tiles
flippedImg = img;
if hasAlpha
    flippedAlpha = alpha;
end

% Loop through each 16x16 tile and flip it horizontally (along columns)
for y = 1:tileSize:imgHeight
    for x = 1:tileSize:imgWidth
        % Define the row and column ranges for the current tile
        rowRange = y:(y + tileSize - 1);
        colRange = x:(x + tileSize - 1);
        
        % Extract and horizontally flip the RGB tile
        tileRGB = img(rowRange, colRange, :);
        flippedImg(rowRange, colRange, :) = flip(tileRGB, 2);
        
        % If transparency is present, flip the alpha tile as well
        if hasAlpha
            tileAlpha = alpha(rowRange, colRange);
            flippedAlpha(rowRange, colRange) = flip(tileAlpha, 2);
        end
    end
end

% Save the image while explicitly passing the alpha channel if it exists
if hasAlpha
    imwrite(flippedImg, outputFilename, 'Alpha', flippedAlpha);
else
    imwrite(flippedImg, outputFilename);
end

disp(['Successfully flipped tiles and saved to ', outputFilename]);