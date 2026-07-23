function diff_img = image_differential(img1_path, img2_path, output_path)
% IMAGE_DIFF  Compare two same-size PNG images pixel by pixel.
%
%   diff_img = IMAGE_DIFF(img1_path, img2_path, output_path)
%
%   Reads two PNG images (same width/height, colors may differ) and
%   produces a black & white output image where:
%       - WHITE pixel  = the two images differ at that pixel
%                        (any of R, G, B, or Alpha differs)
%       - BLACK pixel  = the two images are identical at that pixel
%
%   Inputs:
%       img1_path   - path to first PNG
%       img2_path   - path to second PNG
%       output_path - (optional) path to save the resulting diff PNG.
%                     If omitted, the image is not saved to disk, only
%                     returned/displayed.
%
%   Output:
%       diff_img    - logical/uint8 image (same H x W), 255 = different,
%                     0 = identical. Also displayed and reported in console.

    if nargin < 3
        output_path = '';
    end

    %% ---- Read both images with alpha channels ----
    [img1, ~, alpha1] = imread(img1_path);
    [img2, ~, alpha2] = imread(img2_path);

    [h1, w1, ~] = size(img1);
    [h2, w2, ~] = size(img2);

    if h1 ~= h2 || w1 ~= w2
        error('Images must be identical in size. Got %dx%d vs %dx%d.', ...
              h1, w1, h2, w2);
    end

    %% ---- Normalize to RGB + Alpha, filling missing alpha with opaque ----
    rgb1 = img1(:, :, 1:3);
    rgb2 = img2(:, :, 1:3);

    if isempty(alpha1)
        alpha1 = ones(h1, w1, class(img1)) * intmax(class(img1));
    end
    if isempty(alpha2)
        alpha2 = ones(h2, w2, class(img2)) * intmax(class(img2));
    end

    %% ---- Compute per-pixel difference across R, G, B, Alpha ----
    diff_rgb   = any(rgb1 ~= rgb2, 3);      % true if R, G or B differs
    diff_alpha = alpha1 ~= alpha2;          % true if alpha differs
    diff_mask  = diff_rgb | diff_alpha;     % true if any channel differs

    %% ---- Build white-on-black output image ----
    diff_img = uint8(diff_mask) * 255;

    %% ---- Report to console ----
    num_diff_pixels  = nnz(diff_mask);
    total_pixels     = numel(diff_mask);
    pct_diff         = 100 * num_diff_pixels / total_pixels;

    fprintf('%s vs %s: %d/%d pixels differ (%.2f%%)\n', ...
        img1_path, img2_path, num_diff_pixels, total_pixels, pct_diff);

    %% ---- Save if output path given ----
    if ~isempty(output_path)
        imwrite(diff_img, output_path);
    end
end