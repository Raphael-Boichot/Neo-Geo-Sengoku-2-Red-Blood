function []=Tileset_injector()

% Configuration
sets = {
    '.\MVS_hack\Tileset_MVS_reference_big.png', '.\MVS_hack\Tileset_MVS_modified_big.png';
    '.\MVS_hack\Tileset_MVS_reference_small.png', '.\MVS_hack\Tileset_MVS_modified_small.png'
};

input_dir = '.\tileset_out\';
output_dir = '.\tileset_out_modified\';

% Create the output directory if it doesn't exist
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

files = dir(fullfile(input_dir, '*.png'));

for f = 1:length(files)
    ngcd_filename = fullfile(files(f).folder, files(f).name);
    % Save to output_dir instead of input_dir
    output_filename = fullfile(output_dir, files(f).name); 
    
    fprintf('=== Processing Target Tileset: %s ===\n', files(f).name);
    
    [ngcd, ~, alpha_ngcd] = imread(ngcd_filename);
    if isempty(alpha_ngcd), alpha_ngcd = uint8(255 * ones(size(ngcd,1), size(ngcd,2))); end
    ngcd_modified = cat(3, ngcd, alpha_ngcd);

    for s = 1:size(sets, 1)
        ref_file = sets{s, 1};
        mod_file = sets{s, 2};
        
        [ref, ~, alpha_ref] = imread(ref_file);
        [mod_img, ~, alpha_mod] = imread(mod_file);
        
        if isempty(alpha_ref), alpha_ref = uint8(255 * ones(size(ref,1), size(ref,2))); end
        if isempty(alpha_mod), alpha_mod = uint8(255 * ones(size(mod_img,1), size(mod_img,2))); end
        
        ref = cat(3, ref, alpha_ref); 
        mod_img = cat(3, mod_img, alpha_mod);
        
        [h, w, ~] = size(ref);
        tile_size = 16;
        tiles_per_row = w / tile_size;
        
        diff_indices = [];
        for i = 0:((w / tile_size) * (h / tile_size))-1
            r_start = floor(i / tiles_per_row) * tile_size + 1;
            c_start = mod(i, tiles_per_row) * tile_size + 1;
            if ~isequal(ref(r_start:r_start+15, c_start:c_start+15, :), ...
                         mod_img(r_start:r_start+15, c_start:c_start+15, :))
                diff_indices = [diff_indices; i + 1];
            end
        end
        
        found_count = 0;
        unplaced_count = 0;
        
        for idx = diff_indices'
            r_idx = floor((idx-1) / tiles_per_row) * tile_size + 1;
            c_idx = mod(idx-1, tiles_per_row) * tile_size + 1;
            source_tile = mod_img(r_idx:r_idx+15, c_idx:c_idx+15, :);
            candidates_ref = {ref(r_idx:r_idx+15, c_idx:c_idx+15, :), flip(ref(r_idx:r_idx+15, c_idx:c_idx+15, :), 2)};
            candidates_mod = {source_tile, flip(source_tile, 2)};
            
            tile_found = false;
            for row = 1:tile_size:(size(ngcd,1)-tile_size+1)
                for col = 1:tile_size:(size(ngcd,2)-tile_size+1)
                    for k = 1:2
                        if isequal(candidates_ref{k}, ngcd_modified(row:row+15, col:col+15, :))
                            ngcd_modified(row:row+15, col:col+15, :) = candidates_mod{k};
                            found_count = found_count + 1;
                            tile_found = true; break;
                        end
                    end
                    if tile_found, break; end
                end
                if tile_found, break; end
            end
            if ~tile_found, unplaced_count = unplaced_count + 1; end
        end
        fprintf('Set %d: Injected %d, Unplaced: %d\n', s, found_count, unplaced_count);
    end

    final_rgb = ngcd_modified(:,:,1:3);
    final_alpha = ngcd_modified(:,:,4);
    imwrite(final_rgb, output_filename, 'Alpha', final_alpha);
end