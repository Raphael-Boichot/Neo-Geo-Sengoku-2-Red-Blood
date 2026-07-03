clc
clear

delete('Tileset_NGCD_modified.png');

% 1. Load the images
[ref, ~, alpha_ref] = imread('Tileset_MVS_reference.png');
[mod_img, ~, alpha_mod] = imread('Tileset_MVS_modified.png');
[ngcd, ~, alpha_ngcd] = imread('Tileset_NGCD.png');

% Ensure Alpha is 255 if missing
if isempty(alpha_ref), alpha_ref = uint8(255 * ones(size(ref,1), size(ref,2))); end
if isempty(alpha_mod), alpha_mod = uint8(255 * ones(size(mod_img,1), size(mod_img,2))); end
if isempty(alpha_ngcd), alpha_ngcd = uint8(255 * ones(size(ngcd,1), size(ngcd,2))); end

% Concatenate Alpha to create RGBA images
ref = cat(3, ref, alpha_ref); 
mod_img = cat(3, mod_img, alpha_mod);
% Initialize destination as a standard 3D RGBA array
ngcd_modified = cat(3, ngcd, alpha_ngcd);

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

fprintf('Total number of different tiles to process: %d\n\n', length(diff_indices));

% 4. Search, Match, and Inject
found_count = 0;
trans_names = {'Original', 'Horizontal Flip'};

fprintf('Starting live search and injection into NGCD_modified...\n');

for idx = diff_indices'
    % Tile from MVS Reference
    r_idx = floor((idx-1) / tiles_per_row) * tile_size + 1;
    c_idx = mod(idx-1, tiles_per_row) * tile_size + 1;
    tile_ref = ref(r_idx:r_idx+15, c_idx:c_idx+15, :);
    
    % Tile from MVS Modified
    source_tile = mod_img(r_idx:r_idx+15, c_idx:c_idx+15, :);
    
    % Search targets
    candidates_ref = {tile_ref, flip(tile_ref, 2)};
    candidates_mod = {source_tile, flip(source_tile, 2)};
    
    tile_found = false;
    
    for row = 1:tile_size:(size(ngcd,1)-tile_size+1)
        for col = 1:tile_size:(size(ngcd,2)-tile_size+1)
            tile_ngcd = ngcd_modified(row:row+15, col:col+15, :);
            
            for k = 1:2
                if isequal(candidates_ref{k}, tile_ngcd)
                    % INJECTION: Directly assign the 16x16x4 tile
                    ngcd_modified(row:row+15, col:col+15, :) = candidates_mod{k};
                    
                    fprintf('Injected Index %d into NGCD at Row: %d, Col: %d (Method: %s)\n', ...
                        idx, row, col, trans_names{k});
                    
                    found_count = found_count + 1;
                    tile_found = true;
                    break;
                end
            end
            if tile_found, break; end
        end
        if tile_found, break; end
    end
end

% 5. Save the result
% Ensure dimensions are strictly [H, W, 4] and type is uint8
final_rgb = ngcd_modified(:,:,1:3);
final_alpha = ngcd_modified(:,:,4);

imwrite(final_rgb, 'Tileset_NGCD_modified.png', 'Alpha', final_alpha);
fprintf('\nProcess complete. Found and injected %d tiles with Alpha preservation.\n', found_count);