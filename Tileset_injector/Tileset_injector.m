clc
clear

% 1. Load the images
ref = imread('Tileset_MVS_reference.png');
mod_img = imread('Tileset_MVS_modified.png');
ngcd = imread('Tileset_NGCD.png');

% 2. Verify if Reference and Modified are identical
if isequal(ref, mod_img)
    disp('All tiles identical, end of program');
    return;
end

% 3. Identify differing 16x16 tiles
[h, w, ~] = size(ref);
tile_size = 16;
tiles_per_row = w / tile_size;
total_tiles = (w / tile_size) * (h / tile_size);

diff_indices = [];
for i = 0:total_tiles-1
    r_start = floor(i / tiles_per_row) * tile_size + 1;
    c_start = mod(i, tiles_per_row) * tile_size + 1;
    
    tile_ref = ref(r_start:r_start+15, c_start:c_start+15, :);
    tile_mod = mod_img(r_start:r_start+15, c_start:c_start+15, :);
    
    if ~isequal(tile_ref, tile_mod)
        diff_indices = [diff_indices; i + 1];
    end
end

% Output the list of differences
fprintf('Tiles with differences in Modified: %s\n', mat2str(diff_indices));

% 4. Search for identical tiles in NGCD with transformations
fprintf('\nSearching for reference tiles in NGCD (including rotations/flips)...\n');

for idx = diff_indices'
    r_start = floor((idx-1) / tiles_per_row) * tile_size + 1;
    c_start = mod(idx-1, tiles_per_row) * tile_size + 1;
    tile_ref = ref(r_start:r_start+15, c_start:c_start+15, :);
    
    % Generate all 8 possible transformations
    candidates = cell(8, 1);
    candidates{1} = tile_ref;                            % Original
    candidates{2} = rot90(tile_ref, 1);                  % 90 deg
    candidates{3} = rot90(tile_ref, 2);                  % 180 deg
    candidates{4} = rot90(tile_ref, 3);                  % 270 deg
    candidates{5} = flip(tile_ref, 2);                   % Horizontal Flip
    candidates{6} = flip(tile_ref, 1);                   % Vertical Flip
    candidates{7} = flip(rot90(tile_ref, 1), 2);         % Transpose
    candidates{8} = flip(rot90(tile_ref, 1), 1);         % Anti-transpose
    
    [ngcd_h, ngcd_w, ~] = size(ngcd);
    found = false;
    
    % Scan NGCD for any match
    for row = 1:tile_size:(ngcd_h - tile_size + 1)
        for col = 1:tile_size:(ngcd_w - tile_size + 1)
            tile_ngcd = ngcd(row:row+15, col:col+15, :);
            
            for k = 1:8
                if isequal(candidates{k}, tile_ngcd)
                    fprintf('Reference Tile Index %d matches NGCD at Row: %d, Col: %d (Transformation #%d)\n', ...
                        idx, row, col, k);
                    found = true;
                end
            end
        end
    end
end