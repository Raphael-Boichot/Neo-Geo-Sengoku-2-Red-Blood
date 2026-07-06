function PRG_Palette_injector(PRomFile, palette_old, palette_new)
    % 1. Load File
    fid = fopen(PRomFile, 'rb');
    if fid == -1, error('Could not open file: %s', PRomFile); end
    data = fread(fid, inf, 'uint8=>uint8');
    fclose(fid);

    % 2. Initial CRC Check (Using fast LUT method)
    fprintf('Original File CRC32: %08X\n', calculateCRC32_fast(data));

    % 3. Prepare Patterns
    get_be_bytes = @(p) reshape([bitshift(p, -8); bitand(p, 255)], 1, []);
    search_pattern = get_be_bytes(palette_old);
    replace_pattern = get_be_bytes(palette_new);

    % 4. Search and Inject
    data_row = data(:)';
    idx = strfind(data_row, search_pattern);

    if isempty(idx)
        error('Palette not found in file.');
    else
        % Check if lengths are identical for in-place optimization
        if length(search_pattern) == length(replace_pattern)
            pattern_len = length(replace_pattern);
            for i = 1:length(idx)
                data_row(idx(i) : idx(i) + pattern_len - 1) = replace_pattern;
            end
            fprintf('Total of %d injections performed (in-place).\n', length(idx));
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

    fprintf('File saved as: %s\n', newFileName);
    fprintf('New File CRC32:      %08X\n', calculateCRC32_fast(data));
end

%% High-Performance CRC32 using Lookup Table
function crc = calculateCRC32_fast(data)
    persistent crc32Table;
    if isempty(crc32Table)
        poly = uint32(hex2dec('EDB88320'));
        crc32Table = zeros(256, 1, 'uint32');
        for i = 0:255
            crc_val = uint32(i);
            for j = 1:8
                if bitand(crc_val, 1)
                    crc_val = bitxor(bitshift(crc_val, -1), poly);
                else
                    crc_val = bitshift(crc_val, -1);
                end
            end
            crc32Table(i+1) = crc_val;
        end
    end

    crc = uint32(hex2dec('FFFFFFFF'));
    for i = 1:numel(data)
        idx = bitxor(bitand(crc, 255), uint32(data(i))) + 1;
        crc = bitxor(bitshift(crc, -8), crc32Table(idx));
    end
    crc = bitcmp(crc);
end