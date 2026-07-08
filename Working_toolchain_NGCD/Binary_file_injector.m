%% Binary File Patcher (Byte-Level)
% Treats files as raw byte streams and handles non-matching files gracefully.

%% Parameters
sourceDir = '.\roms_out\';
trackFile = '.\NGCD_track_1\Sengoku2_Track_01.bin';
patchedTrackFile = '.\patched_binary\Sengoku2_track_1_patched.bin';
headerBytesCount = 2048; % Define how many bytes define a unique header

%% Check files
if ~isfolder(sourceDir)
    error('Source directory "%s" does not exist.', sourceDir);
end
if ~isfile(trackFile)
    error('Track file "%s" does not exist.', trackFile);
end

%% Read track
fprintf('Reading track file...\n');
fid = fopen(trackFile, 'rb');
trackData = fread(fid, '*uint8'); 
fclose(fid);
trackLength = length(trackData);

%% Process source files
sourceFiles = dir(fullfile(sourceDir, '*'));
sourceFiles = sourceFiles(~[sourceFiles.isdir]);

for i = 1:length(sourceFiles)
    fileName = sourceFiles(i).name;
    filePath = fullfile(sourceDir, fileName);
    
    fid = fopen(filePath, 'rb');
    fileData = fread(fid, '*uint8');
    fclose(fid);
    
    if length(fileData) < headerBytesCount
        fprintf('SKIP: "%s" is too small to contain a header.\n', fileName);
        continue;
    end

    header = fileData(1:headerBytesCount);

    %% Find header in track
    matches = strfind(trackData', header');

    if isempty(matches)
        % Explicitly reporting no match found
        fprintf('NO MATCH: The header for "%s" was not found in the track file.\n', fileName);
    elseif length(matches) > 1
        fprintf('WARNING: Multiple matches found for "%s". Skipping to prevent data corruption.\n', fileName);
    else
        offset = matches(1) - 1; 
        fprintf('SUCCESS: Injecting "%s" at offset %d (0x%X).\n', fileName, offset, offset);

        % Verify bounds
        if (offset + length(fileData)) > trackLength
            error('CRITICAL: File "%s" exceeds track bounds at offset %d.', fileName, offset);
        end

        % Inject
        trackData(offset + 1 : offset + length(fileData)) = fileData;
    end
end

%% Write patched track
fprintf('Writing patched track to "%s"...\n', patchedTrackFile);
fid = fopen(patchedTrackFile, 'wb');
fwrite(fid, trackData, 'uint8');
fclose(fid);

fprintf('Operation complete.\n');