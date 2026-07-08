% Configuration
binaryPath = '.\NGCD_track_1\Sengoku2_Track_01.bin';
searchDir = '.\NGCD_track_1\';
filePattern = {'*.PRG', '*.SPR'};

% Read binary file into memory
fid = fopen(binaryPath, 'rb');
if fid == -1, error('Could not open binary file.'); end
binData = fread(fid, inf, 'uint8=>uint8');
fclose(fid);

% Get list of files to search
files = [];
for p = 1:length(filePattern)
    files = [files; dir(fullfile(searchDir, filePattern{p}))];
end

fprintf('Scanning %s...\n\n', binaryPath);

for i = 1:length(files)
    filePath = fullfile(files(i).folder, files(i).name);
    
    % Read target file
    fid = fopen(filePath, 'rb');
    targetData = fread(fid, inf, 'uint8=>uint8');
    fclose(fid);
    
    % Find occurrences
    % strfind works on uint8 arrays in newer MATLAB versions
    offsets = strfind(binData', targetData');
    
    % Report results
    fprintf('File: %s\n', files(i).name);
    if isempty(offsets)
        fprintf('  [!] No matches found.\n');
    elseif length(offsets) > 1
        fprintf('  [!] Multiple matches found at offsets: %s\n', ...
            strjoin(cellfun(@(x) sprintf('0x%X', x-1), num2cell(offsets), 'UniformOutput', false), ', '));
    else
        fprintf('  [OK] Found at offset: 0x%X\n', offsets(1)-1);
    end
    fprintf('\n');
end