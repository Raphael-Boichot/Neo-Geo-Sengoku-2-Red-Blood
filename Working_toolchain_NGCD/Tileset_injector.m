function []=Tileset_injector()

% Configuration
sets = {
    '.\MVS_hack\Tileset_MVS_reference_big.png', '.\MVS_hack\Tileset_MVS_modified_big.png';
    '.\MVS_hack\Tileset_MVS_reference_small.png', '.\MVS_hack\Tileset_MVS_modified_small.png'
};

input_dir = '.\tileset_out\';
output_dir = '.\tileset_out_modified\';

if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

files = dir(fullfile(input_dir, '*.png'));
tile_size = 16;

for f = 1:length(files)
    ngcd_filename = fullfile(files(f).folder, files(f).name);
    output_filename = fullfile(output_dir, files(f).name);

    fprintf('=== Processing Target Tileset: %s ===\n', files(f).name);

    [ngcd, ~, alpha_ngcd] = imread(ngcd_filename);
    if isempty(alpha_ngcd), alpha_ngcd = uint8(255 * ones(size(ngcd,1), size(ngcd,2))); end
    ngcd_modified = cat(3, ngcd, alpha_ngcd);

    % Build a lookup table of every tile currently in ngcd_modified.
    % Key = exact byte content of the tile -> FIFO list of [row col] positions,
    % stored in raster-scan order (same order the original nested loop walked).
    tileMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
    [ngh, ngw, ~] = size(ngcd_modified);
    for row = 1:tile_size:(ngh - tile_size + 1)
        for col = 1:tile_size:(ngw - tile_size + 1)
            key = tile_key(ngcd_modified(row:row+15, col:col+15, :));
            if isKey(tileMap, key)
                tileMap(key) = [tileMap(key); row col];
            else
                tileMap(key) = [row col];
            end
        end
    end

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
            ref_tile = ref(r_idx:r_idx+15, c_idx:c_idx+15, :);

            candidates_ref = {ref_tile, flip(ref_tile, 2)};
            candidates_mod = {source_tile, flip(source_tile, 2)};

            key1 = tile_key(candidates_ref{1});
            key2 = tile_key(candidates_ref{2});

            chosen_k = 0;
            pos = [];

            has1 = isKey(tileMap, key1) && ~isempty(tileMap(key1));
            has2 = isKey(tileMap, key2) && ~isempty(tileMap(key2));

            if has1 && has2
                list1 = tileMap(key1); list2 = tileMap(key2);
                % Pick whichever match comes first in raster-scan order
                % (ties go to the non-flipped candidate, matching the original loop)
                if (list1(1,1) < list2(1,1)) || (list1(1,1) == list2(1,1) && list1(1,2) <= list2(1,2))
                    pos = list1(1,:); chosen_k = 1;
                else
                    pos = list2(1,:); chosen_k = 2;
                end
            elseif has1
                list1 = tileMap(key1);
                pos = list1(1,:); chosen_k = 1;
            elseif has2
                list2 = tileMap(key2);
                pos = list2(1,:); chosen_k = 2;
            end

            if chosen_k > 0
                row = pos(1); col = pos(2);
                ngcd_modified(row:row+15, col:col+15, :) = candidates_mod{chosen_k};
                found_count = found_count + 1;

                % Remove the consumed slot from its queue
                if chosen_k == 1, usedKey = key1; else, usedKey = key2; end
                list = tileMap(usedKey);
                list(1,:) = [];
                if isempty(list)
                    remove(tileMap, usedKey);
                else
                    tileMap(usedKey) = list;
                end

                % Register the new content now sitting at this position
                newKey = tile_key(candidates_mod{chosen_k});
                if isKey(tileMap, newKey)
                    tileMap(newKey) = [tileMap(newKey); row col];
                else
                    tileMap(newKey) = [row col];
                end
            else
                unplaced_count = unplaced_count + 1;
            end
        end
        fprintf('Set %d: Injected %d, Unplaced: %d\n', s, found_count, unplaced_count);
    end

    final_rgb = ngcd_modified(:,:,1:3);
    final_alpha = ngcd_modified(:,:,4);
    imwrite(final_rgb, output_filename, 'Alpha', final_alpha);
end
end

function key = tile_key(tile)
    % Exact byte content of the tile, used as a hash-map key.
    % Guarantees no false-positive matches (only identical isequal tiles collide).
    key = char(tile(:)');
end
