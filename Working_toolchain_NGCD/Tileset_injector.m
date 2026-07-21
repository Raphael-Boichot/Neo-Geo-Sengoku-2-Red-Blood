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
    % Key = integer hash of the tile bytes -> FIFO list of entries
    % {row, col, bytes, used}, stored in raster-scan order (same order
    % the original nested loop walked). "bytes" is kept so that hash
    % collisions (rare, but possible) can be resolved with an exact
    % byte comparison, preserving the original isequal-based guarantee.
    %
    % Duplicate tiles (e.g. blank/background tiles) commonly appear at
    % many positions under the same hash. Each occurrence must only be
    % handed out once, otherwise two different diffs that both need a
    % copy of the same repeated tile would collide on the same position
    % (one overwrite silently clobbers the other, and other genuine
    % occurrences of that tile are never touched at all). To avoid that
    % without the cost of splicing entries out of a cell array on every
    % match (the previous, correctness-losing "open loop" version
    % avoided this entirely, and the version before that spliced), each
    % entry instead carries a "used" flag that is set once consumed;
    % find_tile_in_map simply skips flagged entries.
    tileMap = containers.Map('KeyType', 'int64', 'ValueType', 'any');
    [ngh, ngw, ~] = size(ngcd_modified);
    for row = 1:tile_size:(ngh - tile_size + 1)
        for col = 1:tile_size:(ngw - tile_size + 1)
            tile = ngcd_modified(row:row+15, col:col+15, :);
            h = tile_hash(tile);
            entry = struct('row', row, 'col', col, 'bytes', tile(:), 'used', false);
            if isKey(tileMap, h)
                tileMap(h) = [tileMap(h), {entry}];
            else
                tileMap(h) = {entry};
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

        [h_img, w_img, ~] = size(ref);
        tiles_per_row = w_img / tile_size;

        diff_indices = [];
        for i = 0:((w_img / tile_size) * (h_img / tile_size))-1
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

            bytes1 = candidates_ref{1}(:);
            bytes2 = candidates_ref{2}(:);
            key1 = tile_hash(candidates_ref{1});
            key2 = tile_hash(candidates_ref{2});

            [pos1, list_idx1] = find_tile_in_map(tileMap, key1, bytes1);
            [pos2, list_idx2] = find_tile_in_map(tileMap, key2, bytes2);

            has1 = ~isempty(pos1);
            has2 = ~isempty(pos2);

            chosen_k = 0;
            pos = [];

            if has1 && has2
                % Pick whichever match comes first in raster-scan order
                % (ties go to the non-flipped candidate, matching the original loop)
                if (pos1(1) < pos2(1)) || (pos1(1) == pos2(1) && pos1(2) <= pos2(2))
                    pos = pos1; chosen_k = 1;
                else
                    pos = pos2; chosen_k = 2;
                end
            elseif has1
                pos = pos1; chosen_k = 1;
            elseif has2
                pos = pos2; chosen_k = 2;
            end

            if chosen_k > 0
                row = pos(1); col = pos(2);
                ngcd_modified(row:row+15, col:col+15, :) = candidates_mod{chosen_k};
                found_count = found_count + 1;

                % Mark the consumed slot as used (no array splicing —
                % just flip a flag on that one entry and write the list
                % back).
                if chosen_k == 1, usedKey = key1; usedIdx = list_idx1; else, usedKey = key2; usedIdx = list_idx2; end
                list = tileMap(usedKey);
                list{usedIdx}.used = true;
                tileMap(usedKey) = list;

                % Register the new content now sitting at this position,
                % so later diffs (including from the next set) see the
                % tileset's current state rather than stale bytes.
                newBytes = candidates_mod{chosen_k}(:);
                newKey = tile_hash(candidates_mod{chosen_k});
                newEntry = struct('row', row, 'col', col, 'bytes', newBytes, 'used', false);
                if isKey(tileMap, newKey)
                    tileMap(newKey) = [tileMap(newKey), {newEntry}];
                else
                    tileMap(newKey) = {newEntry};
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

function h = tile_hash(tile)
    % Fast integer hash of the tile's exact byte content, used as a
    % containers.Map key. Using an int64 numeric key instead of a
    % ~1024-character string key is what actually fixes the Octave
    % slowdown: Octave's containers.Map compares/hashes string keys in
    % time proportional to string length, so with thousands of 1024-byte
    % keys the original code degraded badly. A single int64 key is
    % compared in constant time.
    %
    % Collisions are possible (this is a checksum, not a cryptographic
    % hash) but are resolved by find_tile_in_map via an exact byte
    % comparison, so correctness matches the original isequal-based logic.
    bytes = double(tile(:));
    n = numel(bytes);
    % Deterministic per-position weights, large enough to spread the sum
    % well, kept small enough that the running sum stays an exactly
    % representable integer in double precision (max ~1024*255*~4.3e9
    % ~= 1.1e15, comfortably under 2^53 ~= 9.0e15).
    weights = mod((1:n)' .* 2654435761, 1000000007);
    h = int64(mod(sum(bytes .* weights), 4611686018427387903)); % < intmax('int64')
end

function [pos, list_idx] = find_tile_in_map(tileMap, h, tileBytes)
    % Look up the first (raster-order) not-yet-used entry under hash h
    % whose stored bytes exactly match tileBytes. Returns pos = [row col]
    % and the index of that entry within the map's list (so the caller
    % can flag it used), or pos = [] / list_idx = 0 if no exact,
    % unconsumed match exists.
    pos = [];
    list_idx = 0;
    if isKey(tileMap, h)
        list = tileMap(h);
        for k = 1:numel(list)
            if ~list{k}.used && isequal(list{k}.bytes, tileBytes)
                pos = [list{k}.row, list{k}.col];
                list_idx = k;
                return;
            end
        end
    end
end