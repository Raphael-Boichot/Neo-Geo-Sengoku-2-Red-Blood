function []=count_unique_colors(IMAGE_PATH)
%
% Reads a 4-layer (RGB + Alpha/transparency) image and displays in the
% console the total number of distinct colors, where a "color" is
% defined as a unique combination of (R, G, B, Alpha).
%
% Usage:
%   1) Set IMAGE_PATH below to point to your image file.
%   2) Run the script.
%
% Notes:
%   - Most common formats that carry an alpha channel are PNG and TIFF.
%   - If the file has no alpha channel, the script will fall back to
%     counting unique RGB colors only, and will warn you about it.

%% ---- Read image (and alpha channel if present) ----
[img, ~, alpha] = imread(IMAGE_PATH);

[rows, cols, channels] = size(img);

if isempty(alpha)
    if channels >= 4
        % Some formats (e.g. some TIFFs/PNGs) pack alpha as a 4th
        % channel directly inside img instead of returning it separately.
        rgb   = img(:, :, 1:3);
        alpha = img(:, :, 4);
    else
        warning(['No alpha/transparency channel found in this image. ' ...
                 'Counting unique RGB colors only.']);
        rgb   = img(:, :, 1:min(3, channels));
        alpha = ones(rows, cols, class(img)) * intmax(class(img));
    end
else
    rgb = img(:, :, 1:3);
end

%% ---- Build RGBA matrix and count unique combinations ----
R = reshape(rgb(:, :, 1), [], 1);
G = reshape(rgb(:, :, 2), [], 1);
B = reshape(rgb(:, :, 3), [], 1);
A = reshape(alpha, [], 1);

rgba_pixels = [R, G, B, A];

unique_colors = unique(rgba_pixels, 'rows');
num_unique_colors = size(unique_colors, 1);

%% ---- Display result (single line) ----
fprintf('%s: %d x %d pixels, %d distinct colors (RGB+Alpha)\n', ...
    IMAGE_PATH, rows, cols, num_unique_colors);