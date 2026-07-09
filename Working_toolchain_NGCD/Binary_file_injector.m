function Binary_file_injector()

%% Binary File Patcher (Fragment-Aware Fragment Injection)
% Maps fragment offsets from original files and injects hacked versions.

%% Parameters
origDir = '.\NGCD_track_1_files\';
hackedDir = '.\roms_out\';
trackFile = '.\NGCD_track_1_binary\Sengoku2_Track_01.bin';
patchedTrackFile = '.\NGCD_track_1_binary\Sengoku2_track_1_patched.bin';
chunkSize = 2048;
paddingThreshold = 100;

%% Initialization
fprintf('Reading track file: %s\n', trackFile);
trackData = readbin(trackFile);
% Combine file search patterns to include PRG and SPR
sourceFiles = [dir(fullfile(origDir, '*.PRG')); dir(fullfile(origDir, '*.SPR'))];

for f = 1:length(sourceFiles)
    fileName = sourceFiles(f).name;
    origPath = fullfile(sourceFiles(f).folder, fileName);
    hackedPath = fullfile(hackedDir, fileName);

    if ~exist(hackedPath, 'file')
        fprintf('WARNING: No hacked file found for %s. Skipping.\n', fileName);
        continue;
    end

    fprintf('\n>>> Scanning File: %s\n', fileName);
    origData = readbin(origPath);
    hackedData = readbin(hackedPath);

    if length(origData) ~= length(hackedData)
        error('CRITICAL: Size mismatch for %s. Original: %d, Hacked: %d', ...
            fileName, length(origData), length(hackedData));
    end

    numChunks = ceil(length(origData) / chunkSize);
    lastMatchOffset = 0; % Pointer reset for fragment-chain mapping

    for c = 1:numChunks
        startByte = (c-1)*chunkSize + 1;
        endByte = min(c*chunkSize, length(origData));
        chunk = origData(startByte:endByte);

        % Skip padding/duplicates
        if length(strfind(trackData', chunk')) > paddingThreshold
            continue;
        end

        % Find location of this specific chunk
        searchArea = trackData(lastMatchOffset + 1 : end);
        matchPosLocal = strfind(searchArea', chunk');

        if ~isempty(matchPosLocal)
            absOffset = lastMatchOffset + matchPosLocal(1) - 1;

            % Inject corresponding chunk from HACKED file
            hackedChunk = hackedData(startByte:endByte);
            trackData(absOffset + 1 : absOffset + length(hackedChunk)) = hackedChunk;

            % Required output format
            gap = absOffset - lastMatchOffset;
            fprintf('Chunk %d/%d (File: %s) found at 0x%X (Gap from previous: 0x%X)\n', ...
                c, numChunks, fileName, absOffset, gap);

            lastMatchOffset = absOffset + chunkSize;
        else
            error('CRITICAL: Could not locate chunk %d for %s. Stopping.', c, fileName);
        end
    end
end

%% Save Patched Track
fprintf('\nWriting patched track: %s\n', patchedTrackFile);
fid = fopen(patchedTrackFile, 'wb');
fwrite(fid, trackData, 'uint8');
fclose(fid);
fprintf('Patch complete.\n');

%% 4. Fix ECC/EDC Overhead
fprintf('\nRegenerating ECC/EDC checksums using EDCRE...\n');
% The -v flag provides verbose output, -s 16 starts regeneration at sector 16
system(sprintf('edcre -v -s 16 "%s"', patchedTrackFile));

    function data = readbin(path)
        fid = fopen(path, 'rb');
        data = fread(fid, '*uint8');
        fclose(fid);
    end

end