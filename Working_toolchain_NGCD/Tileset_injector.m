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

    [base_hashes, base_row, base_col, base_bytes] = build_tile_table(ngcd_modified, tile_size);
    n_base = numel(base_hashes);
    [sorted_hashes, sort_order] = sortrows([base_hashes, (1:n_base)'], [1 2]);
    sorted_hashes = sorted_hashes(:,1); % sorted key column
    base_used = false(n_base, 1);

    % Dynamic entries: tiles placed during this run
    dyn_hash  = zeros(0,1,'int64');
    dyn_row   = zeros(0,1);
    dyn_col   = zeros(0,1);
    dyn_used  = false(0,1);
    dyn_bytes = {};

    for s = 1:size(sets, 1)
        ref_file = sets{s, 1};
        mod_file = sets{s, 2};

        [ref, ~, alpha_ref] = imread(ref_file);
        [mod_img, ~, alpha_mod] = imread(mod_file);

        if isempty(alpha_ref), alpha_ref = uint8(255 * ones(size(ref,1), size(ref,2))); end
        if isempty(alpha_mod), alpha_mod = uint8(255 * ones(size(mod_img,1), size(mod_img,2))); end

        ref = cat(3, ref, alpha_ref);
        mod_img = cat(3, mod_img, alpha_mod);

        [h_img, w_img, ~] = size(ref);
        tiles_per_row = w_img / tile_size;

        diff_mask = any(ref ~= mod_img, 3);
        th_ = h_img / tile_size;
        tw_ = w_img / tile_size;
        blocks = reshape(diff_mask, tile_size, th_, tile_size, tw_);
        blocks = permute(blocks, [1 3 2 4]);
        tile_diff = reshape(any(reshape(blocks, tile_size*tile_size, th_*tw_), 1), th_, tw_);
        
        % Fixed to prevent parsing errors across various MATLAB versions
        tile_diff_transposed = tile_diff.';
        diff_indices = find(tile_diff_transposed(:)); 

        found_count = 0;
        unplaced_count = 0;
        total_diffs = numel(diff_indices);
        fprintf('Set %d: %d differing tiles to place\n', s, total_diffs);

        for idx = diff_indices'
            r_idx = floor((idx-1) / tiles_per_row) * tile_size + 1;
            c_idx = mod(idx-1, tiles_per_row) * tile_size + 1;
            source_tile = mod_img(r_idx:r_idx+15, c_idx:c_idx+15, :);
            ref_tile = ref(r_idx:r_idx+15, c_idx:c_idx+15, :);

            candidates_ref = {ref_tile, flip(ref_tile, 2)};
            candidates_mod = {source_tile, flip(source_tile, 2)};

            bytes1 = candidates_ref{1}(:);
            bytes2 = candidates_ref{2}(:);
            key1 = tile_hash(candidates_ref{1});
            key2 = tile_hash(candidates_ref{2});

            [pos1, src1, cidx1] = find_tile(sorted_hashes, sort_order, base_row, base_col, base_bytes, base_used, dyn_hash, dyn_row, dyn_col, dyn_bytes, dyn_used, key1, bytes1);
            [pos2, src2, cidx2] = find_tile(sorted_hashes, sort_order, base_row, base_col, base_bytes, base_used, dyn_hash, dyn_row, dyn_col, dyn_bytes, dyn_used, key2, bytes2);

            has1 = ~isempty(pos1);
            has2 = ~isempty(pos2);

            chosen_k = 0;
            pos = [];

            if has1 && has2
                if (pos1(1) < pos2(1)) || (pos1(1) == pos2(1) && pos1(2) <= pos2(2))
                    pos = pos1; chosen_k = 1; src = src1; cidx = cidx1;
                else
                    pos = pos2; chosen_k = 2; src = src2; cidx = cidx2;
                end
            elseif has1
                pos = pos1; chosen_k = 1; src = src1; cidx = cidx1;
            elseif has2
                pos = pos2; chosen_k = 2; src = src2; cidx = cidx2;
            end

            if chosen_k > 0
                row = pos(1); col = pos(2);
                ngcd_modified(row:row+15, col:col+15, :) = candidates_mod{chosen_k};
                found_count = found_count + 1;

                if strcmp(src, 'base')
                    base_used(cidx) = true;
                else
                    dyn_used(cidx) = true;
                end

                newBytes = candidates_mod{chosen_k}(:);
                newKey = tile_hash(candidates_mod{chosen_k});
                dyn_hash(end+1,1)  = newKey;
                dyn_row(end+1,1)   = row;
                dyn_col(end+1,1)   = col;
                dyn_used(end+1,1)  = false;
                dyn_bytes{end+1}   = newBytes;
            else
                unplaced_count = unplaced_count + 1;
            end

            processed_count = found_count + unplaced_count;
            if mod(processed_count, 10) == 0
                fprintf('Set %d: processed %d/%d tiles (Injected %d, Unplaced %d, Remaining %d)\n', ...
                    s, processed_count, total_diffs, found_count, unplaced_count, total_diffs - processed_count);
            end
        end
        fprintf('Set %d: Injected %d, Unplaced: %d\n', s, found_count, unplaced_count);
    end

    final_rgb = ngcd_modified(:,:,1:3);
    final_alpha = ngcd_modified(:,:,4);
    imwrite(final_rgb, output_filename, 'Alpha', final_alpha);

    fprintf('=== Finished Target Tileset: %s -> %s ===\n', files(f).name, output_filename);
end
end

function [hashes, row_out, col_out, bytes_out] = build_tile_table(img, tile_size)
    persistent weights
    if isempty(weights)
        weights = mod((1:tile_size*tile_size*4)' .* 2654435761, 1000000007);
    end
    [h, w, nch] = size(img);
    th = h / tile_size;
    tw = w / tile_size;
    n = th * tw;

    blocks = reshape(img, tile_size, th, tile_size, tw, nch);
    blocks = permute(blocks, [1 3 5 2 4]); 
    flat = reshape(blocks, tile_size*tile_size*nch, n); 

    flat_d = double(flat);
    hashraw = mod(weights' * flat_d, 4611686018427387903); 
    hashes_colmajor = int64(hashraw)'; 

    hmat = reshape(hashes_colmajor, th, tw);
    hashes = reshape(hmat.', n, 1);

    bytes_colmajor = uint8(flat); 
    col_order = reshape(reshape(1:n, th, tw).', n, 1);
    bytes_out = bytes_colmajor(:, col_order); 

    tile_row0 = floor((0:n-1)' / tw);
    tile_col0 = mod((0:n-1)', tw);
    row_out = tile_row0 * tile_size + 1;
    col_out = tile_col0 * tile_size + 1;
end

function [pos, src, cidx] = find_tile(sorted_hashes, sort_order, base_row, base_col, base_bytes, base_used, dyn_hash, dyn_row, dyn_col, dyn_bytes, dyn_used, key, target_bytes)
    pos = []; src = ''; cidx = 0;

    lo = compat_lookup(sorted_hashes, key - 1) + 1;
    hi = compat_lookup(sorted_hashes, key);
    
    for i = lo:hi
        oi = sort_order(i);
        if ~base_used(oi) && isequal(base_bytes(:, oi), target_bytes)
            pos = [base_row(oi), base_col(oi)];
            src = 'base';
            cidx = oi;
            return;
        end
    end

    for k = 1:numel(dyn_hash)
        if ~dyn_used(k) && dyn_hash(k) == key && isequal(dyn_bytes{k}, target_bytes)
            pos = [dyn_row(k), dyn_col(k)];
            src = 'dyn';
            cidx = k;
            return;
        end
    end
end

function idx = compat_lookup(sorted_vector, val)
    if isempty(sorted_vector)
        idx = 0;
        return;
    end
    
    low = 1;
    high = length(sorted_vector);
    idx = 0;
    
    if val < sorted_vector(1)
        idx = 0;
        return;
    end
    if val >= sorted_vector(end)
        idx = high;
        return;
    end
    
    while low <= high
        mid = floor((low + high) / 2);
        if sorted_vector(mid) <= val
            idx = mid;
            low = mid + 1;
        else
            high = mid - 1;
        end
    end
end

function h = tile_hash(tile)
    persistent weights
    if isempty(weights)
        weights = mod((1:1024)' .* 2654435761, 1000000007);
    end
    bytes = double(tile(:));
    h = int64(mod(sum(bytes .* weights), 4611686018427387903));
end