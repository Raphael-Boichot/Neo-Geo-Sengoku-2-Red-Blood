function PRG_Palette_injector(PRomFile, palette_old, palette_new)
% 1. Load File
fid = fopen(PRomFile, 'rb');
if fid == -1, error('Could not open file: %s', PRomFile); end
% Read as column vector
data = fread(fid, inf, 'uint8=>uint8');
fclose(fid);

% 2. Initial CRC Check
fprintf('Original File CRC32: %08X\n', calculateCRC32(data));

% 3. Prepare Patterns (Ensuring row vectors)
% Change the anonymous function to Big-Endian: [High Byte, Low Byte]
get_be_bytes = @(p) reshape([bitshift(p, -8); bitand(p, 255)], 1, []);

search_pattern = get_be_bytes(palette_old);
replace_pattern = get_be_bytes(palette_new);

% 4. Search and Inject
% Flatten data to row vector for strfind
data_row = data(:)';
idx = strfind(data_row, search_pattern);

if isempty(idx)
    error('Palette not found in file.');
else
    % Calculate the difference in length
    len_diff = length(replace_pattern) - length(search_pattern);
    offset = 0; % Track how much we have shifted the array

    for i = 1:length(idx)
        % Adjust current index by the total offset created by previous replacements
        start_pos = idx(i) + offset;
        end_pos = start_pos + length(search_pattern) - 1;

        % Perform the replacement using row vectors
        data_row = [data_row(1 : start_pos - 1), ...
            replace_pattern, ...
            data_row(end_pos + 1 : end)];

        % Update the offset for the next iteration
        offset = offset + len_diff;

        fprintf('Injected at adjusted offset: %d\n', start_pos);
    end
    % Convert back to column vector for consistency
    data = data_row(:);
    fprintf('Total of %d injections performed.\n', length(idx));
end

% 5. Save and Final CRC
if ~exist('.\roms_out', 'dir'), mkdir('.\roms_out'); end
[~, name, ext] = fileparts(PRomFile);
newFileName = ['.\roms_out\', name, ext];
fid = fopen(newFileName, 'wb');
fwrite(fid, data, 'uint8');
fclose(fid);

fprintf('File saved as: %s\n', newFileName);
fprintf('New File CRC32:      %08X\n', calculateCRC32(data));

%% CRC32 Function
    function crc = calculateCRC32(data)
        poly = uint32(hex2dec('EDB88320'));
        crc = uint32(hex2dec('FFFFFFFF'));
        for i = 1:numel(data)
            crc = bitxor(crc, uint32(data(i)));
            for j = 1:8
                if bitand(crc, 1)
                    crc = bitxor(bitshift(crc, -1), poly);
                else
                    crc = bitshift(crc, -1);
                end
            end
        end
        crc = bitcmp(crc);
    end
end