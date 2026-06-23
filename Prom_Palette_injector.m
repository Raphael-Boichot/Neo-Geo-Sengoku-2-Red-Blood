clc;
clear;

PRomFile = '040-p1.p1';

% Define Palettes
palette_old = [0x0010, 0x7810, 0x0C74, 0x5FC9, 0x5409, 0x1A0F, 0x1F9F, 0x0800, 0x0C00, 0x4F93, 0x0666, 0x7AAA, 0x0EEE, 0x7334, 0x4500, 0x7111];
palette_new = [0x0010, 0x7810, 0x0C74, 0x5FC9, 0x5409, 0x1A0F, 0x1F9F, 0x0800, 0x0C00, 0x4F93, 0x0666, 0x7AAA, 0x0EEE, 0x7334, 0x4500, 0x7111];

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
newFileName = [name '_patched' ext];
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