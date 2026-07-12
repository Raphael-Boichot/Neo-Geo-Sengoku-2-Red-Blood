function Prom_Palette_injector(PRomFile, palette_old, palette_new)
% 1. Load entire file into memory
fid = fopen(PRomFile, 'rb');
if fid == -1, error('Could not open file: %s', PRomFile); end
data = fread(fid, inf, 'uint8=>uint8');
fclose(fid);

% 2. Initial CRC Check (Using fast LUT method)
origCRC = computeCRC32(PRomFile);

% 3. Prepare Patterns
get_le_bytes = @(p) reshape([bitand(p, 255); bitshift(p, -8)], 1, []);
search_pattern = get_le_bytes(palette_old);
replace_pattern = get_le_bytes(palette_new);

% 4. Search and Inject (Optimized)
if length(search_pattern) == length(replace_pattern)
    data_row = data(:)';
    idx = strfind(data_row, search_pattern);

    if isempty(idx)
        error('Palette not found in file.');
    end

    % Vectorized modification on all occurrences
    pattern_len = length(replace_pattern);
    for i = 1:length(idx)
        data_row(idx(i) : idx(i) + pattern_len - 1) = replace_pattern;
    end
    data = data_row(:);
    numInjections = length(idx);
else
    error('This fast version requires palettes of the same length.');
end

% 5. Save and Final CRC
if ~exist('.\roms_out', 'dir'), mkdir('.\roms_out'); end
[~, name, ext] = fileparts(PRomFile);
newFileName = ['.\roms_out\', name, ext];
fid = fopen(newFileName, 'wb');
fwrite(fid, data, 'uint8');
fclose(fid);

fprintf('Orig CRC32: %08X | Injections: %d | Saved: %s | New CRC32: %08X\n', ...
    origCRC, numInjections, newFileName, computeCRC32(newFileName));