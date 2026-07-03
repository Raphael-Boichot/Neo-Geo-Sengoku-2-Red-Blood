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

fprintf('Tiles with differences in Modified: %s\n', mat2str(diff_indices));
fprintf('Total number of different tiles to find in NGCD: %d\n\n', length(diff_indices));

% 4. Search for identical tiles in NGCD with live updates
found_count = 0;
found_indices = []; 

fprintf('Starting live search in NGCD...\n');

for idx = diff_indices'
    r_start = floor((idx-1) / tiles_per_row) * tile_size + 1;
    c_start = mod(idx-1, tiles_per_row) * tile_size + 1;
    tile_ref = ref(r_start:r_start+15, c_start:c_start+15, :);
    
    candidates = {tile_ref, rot90(tile_ref, 1), rot90(tile_ref, 2), rot90(tile_ref, 3), ...
                  flip(tile_ref, 2), flip(tile_ref, 1), flip(rot90(tile_ref, 1), 2), flip(rot90(tile_ref, 1), 1)};
    
    [ngcd_h, ngcd_w, ~] = size(ngcd);
    tile_found_for_this_idx = false;
    
    % Search through NGCD
    for row = 1:tile_size:(ngcd_h - tile_size + 1)
        for col = 1:tile_size:(ngcd_w - tile_size + 1)
            tile_ngcd = ngcd(row:row+15, col:col+15, :);
            
            for k = 1:8
                if isequal(candidates{k}, tile_ngcd)
                    if ~tile_found_for_this_idx
                        fprintf('Found Index %d at NGCD Row: %d, Col: %d (Transform %d)\n', idx, row, col, k);
                        found_count = found_count + 1;
                        tile_found_for_this_idx = true;
                        found_indices = [found_indices; idx];
                    end
                end
            end
        end
    end
    
    if ~tile_found_for_this_idx
        fprintf('Searching... Tile index %d not found yet.\n', idx);
    end
end

% 5. Summary Report
fprintf('\n--- Final Summary ---\n');
fprintf('Different tiles successfully located in NGCD: %d / %d\n', found_count, length(diff_indices));

missing_tiles = setdiff(diff_indices, found_indices);
if ~isempty(missing_tiles)
    fprintf('Tiles still missing from NGCD: %s\n', mat2str(missing_tiles));
else
    fprintf('All different tiles were successfully located in NGCD.\n');
end