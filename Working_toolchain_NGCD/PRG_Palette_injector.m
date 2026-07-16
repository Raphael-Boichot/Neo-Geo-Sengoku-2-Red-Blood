function PRG_Palette_injector(PRomFile, palette_old, palette_new)
% 1. Load File
fid = fopen(PRomFile, 'rb');
if fid == -1, error('Could not open file: %s', PRomFile); end
data = fread(fid, inf, 'uint8=>uint8');
fclose(fid);

% 2. Initial CRC Check (Using fast LUT method)
origCRC = computeCRC32(PRomFile);

% 3. Prepare Patterns
get_be_bytes = @(p) reshape([bitshift(p, -8); bitand(p, 255)], 1, []);
search_pattern = get_be_bytes(palette_old);
replace_pattern = get_be_bytes(palette_new);

% 4. Search and Inject (Vectorized, fast)
data_row = data(:)';
pattern_len = length(search_pattern);

% Fast vectorized byte-pattern search via strfind
% (uint8 values map 1:1 to char codes, so this is safe for binary data)
idx = strfind(char(data_row), char(search_pattern));

if isempty(idx)
    error('Palette not found in file.');
else
    % Check if lengths are identical for in-place optimization
    if length(search_pattern) == length(replace_pattern)
        pattern_len = length(replace_pattern);
        for i = 1:length(idx)
            data_row(idx(i) : idx(i) + pattern_len - 1) = replace_pattern;
        end
        numInjections = length(idx);
    else
        % Fallback for different lengths (less efficient but necessary)
        error('For performance, this version assumes palette lengths are equal.');
    end
    data = data_row(:);
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
