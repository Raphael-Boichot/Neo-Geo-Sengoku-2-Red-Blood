function [] = repair_transparent_pixels(modified_path, reference_path, output_path)
% REPAIR_TRANSPARENT_PIXELS  Force transparent-black pixels from a
% reference image onto a modified image, wherever they mismatch.
%
%   repaired = REPAIR_TRANSPARENT_PIXELS(modified_path, reference_path, output_path)
%
%   Rule: wherever the REFERENCE image has a fully transparent, black
%   pixel (RGB = [0 0 0], Alpha = 0), that pixel is considered the
%   ground truth for "background/transparent". If the MODIFIED image
%   does NOT have that same transparent-black pixel at that location
%   (a "rogue" pixel introduced by error), it is forcibly overwritten
%   with [0 0 0 0] to match the reference.
%
%   All other pixels (anywhere the reference is not transparent-black)
%   are left completely untouched in the modified image, even if they
%   differ from the reference.
%
%   Inputs:
%       modified_path   - path to the PNG to be repaired
%       reference_path  - path to the reference PNG (ground truth for
%                         transparent/background pixels)
%       output_path     - (optional) path to save the repaired PNG.
%                         If omitted, result is only returned/displayed,
%                         not saved.
%
%   Output:
%       repaired        - HxWx4 uint8 RGBA array of the repaired image.

    if nargin < 3
        output_path = '';
    end

    %% ---- Read both images with alpha channels ----
    [imgMod, ~, alphaMod] = imread(modified_path);
    [imgRef, ~, alphaRef] = imread(reference_path);

    [hMod, wMod, ~] = size(imgMod);
    [hRef, wRef, ~] = size(imgRef);

    if hMod ~= hRef || wMod ~= wRef
        error('Images must be identical in size. Got %dx%d vs %dx%d.', ...
              hMod, wMod, hRef, wRef);
    end

    if isempty(alphaMod)
        alphaMod = ones(hMod, wMod, class(imgMod)) * intmax(class(imgMod));
    end
    if isempty(alphaRef)
        alphaRef = ones(hRef, wRef, class(imgRef)) * intmax(class(imgRef));
    end

    rgbMod = imgMod(:, :, 1:3);
    rgbRef = imgRef(:, :, 1:3);

    %% ---- Identify reference "transparent-black" pixels ----
    ref_is_transparent_black = (alphaRef == 0) & all(rgbRef == 0, 3);

    %% ---- Identify modified pixels that mismatch the reference there ----
    mod_matches_ref_there = (alphaMod == 0) & all(rgbMod == 0, 3);

    rogue_mask = ref_is_transparent_black & ~mod_matches_ref_there;

    num_rogue = nnz(rogue_mask);
    fprintf('%s: %d rogue pixel(s) found and forced to transparent-black.\n', ...
        modified_path, num_rogue);

    %% ---- Repair: force rogue pixels to [0 0 0 0] ----
    R = rgbMod(:, :, 1); G = rgbMod(:, :, 2); B = rgbMod(:, :, 3); A = alphaMod;

    R(rogue_mask) = 0;
    G(rogue_mask) = 0;
    B(rogue_mask) = 0;
    A(rogue_mask) = 0;

    repaired = cat(3, R, G, B, A);

    %% ---- Save if requested ----
    if ~isempty(output_path)
        imwrite(repaired(:, :, 1:3), output_path, 'Alpha', repaired(:, :, 4));
    end
end