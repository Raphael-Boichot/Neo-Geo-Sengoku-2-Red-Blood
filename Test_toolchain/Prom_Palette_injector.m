function Prom_Palette_injector(PRomFile,palette_old,palette_new)

% 1. Load File
fid = fopen(PRomFile, 'rb');
if fid == -1, error('Could not open file: %s', PRomFile); end
data = fread(fid, inf, 'uint8=>uint8');
fclose(fid);

% 2. Initial CRC Check
fprintf('Original File CRC32: %08X\n', calculateCRC32(data));

% 3. Prepare Patterns (Little-Endian: [LSB, MSB])
get_le_bytes = @(p) reshape([bitand(p, 255); bitshift(p, -8)], 1, []);
search_pattern = get_le_bytes(palette_old);
replace_pattern = get_le_bytes(palette_new);

% 4. Search and Inject
idx = strfind(data', search_pattern);

if isempty(idx)
    error('Palette not found in file.');
else
    fprintf('Found palette at offset: %d\n', idx(1));
    data(idx(1) : idx(1) + length(replace_pattern) - 1) = replace_pattern;
    fprintf('Injection successful.\n');
end

% 5. Save and Final CRC
[~, name, ext] = fileparts(PRomFile);
newFileName = ['.\roms_out\',name, ext, '.new' ];
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