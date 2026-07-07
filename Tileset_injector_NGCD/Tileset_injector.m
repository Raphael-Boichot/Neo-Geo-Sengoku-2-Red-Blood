clc
clear

% Start from fresh
delete('Tileset_NGCD_modified.png');

% Configuration: Define the pairs of files to process
sets = {
    'Tileset_MVS_reference_big.png', 'Tileset_MVS_modified_big.png';
    'Tileset_MVS_reference_small.png', 'Tileset_MVS_modified_small.png'
};

% Initial setup for the base file
ngcd_filename = 'Tileset_NGCD.png';
output_filename = 'Tileset_NGCD_modified.png';

% Load the base NGCD tileset once
[ngcd, ~, alpha_ngcd] = imread(ngcd_filename);
if isempty(alpha_ngcd), alpha_ngcd = uint8(255 * ones(size(ngcd,1), size(ngcd,2))); end
ngcd_modified = cat(3, ngcd, alpha_ngcd);

% Process each set
for s = 1:size(sets, 1)
    ref_file = sets{s, 1};
    mod_file = sets{s, 2};
    
    fprintf('--- Processing Set %d: %s ---\n', s, ref_file);
    
    % 1. Load the images
    [ref, ~, alpha_ref] = imread(ref_file);
    [mod_img, ~, alpha_mod] = imread(mod_file);
    
    % Ensure Alpha is 255 if missing
    if isempty(alpha_ref), alpha_ref = uint8(255 * ones(size(ref,1), size(ref,2))); end
    if isempty(alpha_mod), alpha_mod = uint8(255 * ones(size(mod_img,1), size(mod_img,2))); end
    
    % Concatenate Alpha
    ref = cat(3, ref, alpha_ref); 
    mod_img = cat(3, mod_img, alpha_mod);
    
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
    
    fprintf('Total number of different tiles to process: %d\n', length(diff_indices));
    
    % 4. Search, Match, and Inject
    found_count = 0;
    
    for idx = diff_indices'
        r_idx = floor((idx-1) / tiles_per_row) * tile_size + 1;
        c_idx = mod(idx-1, tiles_per_row) * tile_size + 1;
        tile_ref = ref(r_idx:r_idx+15, c_idx:c_idx+15, :);
        source_tile = mod_img(r_idx:r_idx+15, c_idx:c_idx+15, :);
        
        candidates_ref = {tile_ref, flip(tile_ref, 2)};
        candidates_mod = {source_tile, flip(source_tile, 2)};
        
        tile_found = false;
        for row = 1:tile_size:(size(ngcd,1)-tile_size+1)
            for col = 1:tile_size:(size(ngcd,2)-tile_size+1)
                tile_ngcd = ngcd_modified(row:row+15, col:col+15, :);
                for k = 1:2
                    if isequal(candidates_ref{k}, tile_ngcd)
                        ngcd_modified(row:row+15, col:col+15, :) = candidates_mod{k};
                        found_count = found_count + 1;
                        tile_found = true;
                        break;
                    end
                end
                if tile_found, break; end
            end
            if tile_found, break; end
        end
        
        % Warning if tile was not found in the target set
        if ~tile_found
            fprintf('WARNING: Could not find a match for Tile Index %d in the NGCD set.\n', idx);
        end
    end
    fprintf('Finished Set %d. Injected %d tiles.\n\n', s, found_count);
end

% 5. Save the result
final_rgb = ngcd_modified(:,:,1:3);
final_alpha = ngcd_modified(:,:,4);
imwrite(final_rgb, output_filename, 'Alpha', final_alpha);
fprintf('Process complete. Final tileset saved as %s.\n', output_filename);