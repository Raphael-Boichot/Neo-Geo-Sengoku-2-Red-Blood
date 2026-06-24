clc
clear
warning off

% 1. Read the image
inputFileName = 'Yoshitsune_main.png';
img = imread(inputFileName); 

% 2. Get image dimensions and reshape into a list of RGB pixels
[rows, cols, channels] = size(img);
pixelList = reshape(img, rows * cols, channels);

% 3. Find unique colors
uniqueColors = unique(pixelList, 'rows');
numUniqueColors = size(uniqueColors, 1);

fprintf('The image contains %d unique colors.\n', numUniqueColors);

%% Generate Palette Image
% Use the unique colors found above as the palette
rgbPalette = uniqueColors; 
numColors = size(rgbPalette, 1);

% Define Magenta [R G B]
MAGENTA = uint8([255, 0, 255]); 

% Settings for the palette sheet
palW = 32; palH = 32;
colorsPerRow = 16;
numRows = ceil(numColors / colorsPerRow);

% Initialize palette sheet with MAGENTA
palSheet = repmat(reshape(MAGENTA, [1 1 3]), [numRows * palH, colorsPerRow * palW, 1]);

for i = 0:numColors - 1
    rgb = rgbPalette(i+1, :);
    tx = mod(i, colorsPerRow);
    ty = floor(i / colorsPerRow);
    
    colorBlock = repmat(reshape(rgb, [1 1 3]), [palH, palW, 1]);
    palSheet(ty*palH+1:(ty+1)*palH, tx*palW+1:(tx+1)*palW, :) = colorBlock;
end

% Construct dynamic filename
[~, nameOnly, ~] = fileparts(inputFileName);
outputFileName = [nameOnly, '_Palette.png'];

% Save the resulting palette
imwrite(palSheet, outputFileName);
fprintf('Palette exported to %s with %d colors.\n', outputFileName, numColors);