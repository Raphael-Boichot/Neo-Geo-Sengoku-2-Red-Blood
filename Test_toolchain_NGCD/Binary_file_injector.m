%% Binary File Patcher for 16-bit Audio Samples
% Treats track1.iso and source files as raw 16-bit PCM data.
% Compares headers as 16-bit samples (not bytes) to avoid false matches.

clc;
clear;

%% Parameters
sourceDir = '.\\Source_files\\';
trackFile = 'Sengoku2_track_1.bin';
patchedTrackFile = 'Sengoku2_track_1_patched.bin';
headerSamples = 256; % 64 bytes = 32 samples (16-bit)

%% Check files
if ~isfolder(sourceDir)
    error('Source directory "%s" does not exist.', sourceDir);
end
if ~isfile(trackFile)
    error('Track file "%s" does not exist.', trackFile);
end

%% Read track as 16-bit samples (little-endian)
fprintf('Reading track "%s" as 16-bit PCM...\n', trackFile);
fid = fopen(trackFile, 'rb');
trackSamples = fread(fid, 'int16', 'l'); % 'l' = little-endian
fclose(fid);
trackLength = length(trackSamples);

%% Process source files
sourceFiles = dir(fullfile(sourceDir, '*'));
sourceFiles = sourceFiles(~[sourceFiles.isdir]);
numSourceFiles = length(sourceFiles);

fprintf('Found %d source files.\n', numSourceFiles);

for i = 1:numSourceFiles
    fileName = sourceFiles(i).name;
    filePath = fullfile(sourceDir, fileName);
    fprintf('Processing "%s"...\n', fileName);

    % Read source file as 16-bit samples
    fid = fopen(filePath, 'rb');
    fileSamples = fread(fid, 'int16', 'l');
    fclose(fid);
    fileLength = length(fileSamples);

    % Check minimum size
    if fileLength < headerSamples
        warning('File "%s" too small (%d samples). Skipping.', fileName, fileLength);
        continue;
    end

    % Extract header (first 32 samples = 64 bytes)
    header = fileSamples(1:headerSamples);

    %% Find header in track (16-bit comparison)
    % Convert to row vectors for strfind
    trackRow = trackSamples(:)';
    headerRow = header(:)';

    % Find matches (non-overlapping)
    matches = strfind(trackRow, headerRow);

    % Debug: Print matches
    fprintf('Matches at sample offsets: %s\n', num2str(matches));

    % Check uniqueness
    if isempty(matches)
        warning('No match for "%s". Skipping.', fileName);
    elseif length(matches) > 1
        warning('Multiple matches for "%s". Skipping.', fileName);
    else
        offset = matches(1) - 1; % 0-based sample index
        fprintf('Unique match at sample %d (byte offset: %d/0x%X).\n', ...
                offset, offset*2, offset*2);

        % Verify space
        if (offset + fileLength) > trackLength
            error('File "%s" (size %d) exceeds track bounds at offset %d.', ...
                  fileName, fileLength, offset);
        end

        % Inject (convert back to bytes for writing)
        trackSamples(offset + 1 : offset + fileLength) = fileSamples;
    end
end

%% Write patched track (as 16-bit samples)
fprintf('Writing patched track "%s"...\n', patchedTrackFile);
fid = fopen(patchedTrackFile, 'wb');
fwrite(fid, trackSamples, 'int16', 'l');
fclose(fid);

fprintf('Done. Patched track saved as "%s".\n', patchedTrackFile);
