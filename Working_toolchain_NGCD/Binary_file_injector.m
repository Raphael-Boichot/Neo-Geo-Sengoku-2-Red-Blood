function Binary_file_injector()

%% Parameters
origDir = '.\NGCD_track_1_files\';
hackedDir = '.\roms_out\';
trackFile = '.\NGCD_track_1_binary\Sengoku2_Track_01.bin';
patchedTrackFile = '.\NGCD_track_1_binary\Sengoku2_track_1_patched.bin';
chunkSize = 2048;
paddingThreshold = 100;

%% 1. Initialization and Loading
fprintf('Loading track file into memory...\n');
trackData = readbin(trackFile);
trackData = trackData(:);
trackDataT = trackData'; % transpose once, reused for every search

sourceFiles = [dir(fullfile(origDir, '*.PRG')); dir(fullfile(origDir, '*.SPR'))];
dataMap = struct('name', {}, 'orig', {}, 'hacked', {});

for f = 1:length(sourceFiles)
    fileName = sourceFiles(f).name;
    hackedPath = fullfile(hackedDir, fileName);
    if exist(hackedPath, 'file')
        origData = readbin(fullfile(sourceFiles(f).folder, fileName));
        hackedData = readbin(hackedPath);
        if length(origData) ~= length(hackedData)
            error('Size mismatch for %s: orig=%d bytes, hacked=%d bytes. In-place patching requires identical sizes.', ...
                fileName, length(origData), length(hackedData));
        end
        dataMap(end+1).name = fileName;
        dataMap(end).orig = origData;
        dataMap(end).hacked = hackedData;
    end
end

%% 2. Processing with Per-File Reporting
fprintf('\n%-20s | %-12s | %-12s | %-12s | %-12s\n', 'Filename', 'Chunks', 'Injected', 'Padding', 'Skipped');
fprintf('--------------------------------------------------------------------------------------------\n');

grandTotalInjected = 0;

for f = 1:length(dataMap)
    fileName = dataMap(f).name;
    origData = dataMap(f).orig;
    hackedData = dataMap(f).hacked;

    numChunks = ceil(length(origData) / chunkSize);
    lastMatchOffset = 0;
    processedCount = 0;
    ignoredCount = 0;
    skippedCount = 0;

    for c = 1:numChunks
        startByte = (c-1)*chunkSize + 1;
        endByte = min(c*chunkSize, length(origData));
        chunkOrig = origData(startByte:endByte);
        chunkHacked = hackedData(startByte:endByte);

        % Skip if original and hacked chunks are identical.
        % Check this FIRST: if nothing changed, there's nothing to inject,
        % regardless of how many times this chunk repeats in the track.
        if isequal(chunkOrig, chunkHacked)
            skippedCount = skippedCount + 1;
            % Advance lastMatchOffset to keep alignment context
            lastMatchOffset = lastMatchOffset + chunkSize;
            continue;
        end

        % Chunk DID change. Now check if it's too ambiguous to locate safely
        % (e.g. a common padding/fill pattern that repeats many times).
        occurrences = length(strfind(trackDataT, chunkOrig'));
        if occurrences > paddingThreshold
            fprintf('  WARNING: chunk %d in %s changed but repeats %d times in track (> threshold %d) - SKIPPED, not injected!\n', ...
                c, fileName, occurrences, paddingThreshold);
            ignoredCount = ignoredCount + 1;
            continue;
        end

        searchArea = trackData(lastMatchOffset + 1 : end);
        matchPosLocal = strfind(searchArea', chunkOrig');

        if ~isempty(matchPosLocal)
            if numel(matchPosLocal) > 1
                fprintf('  WARNING: chunk %d in %s has %d candidate matches after offset %d; using the first one.\n', ...
                    c, fileName, numel(matchPosLocal), lastMatchOffset);
            end
            absOffset = lastMatchOffset + matchPosLocal(1) - 1;
            trackData(absOffset + 1 : absOffset + length(chunkOrig)) = chunkHacked;
            trackDataT(absOffset + 1 : absOffset + length(chunkOrig)) = chunkHacked';
            lastMatchOffset = absOffset + chunkSize;
            processedCount = processedCount + 1;
        else
            error('CRITICAL: Could not locate chunk %d for %s.', c, fileName);
        end
    end

    grandTotalInjected = grandTotalInjected + processedCount;
    fprintf('%-20s | %-12d | %-12d | %-12d | %-12d\n', fileName, numChunks, processedCount, ignoredCount, skippedCount);
end

fprintf('\nGrand Total Injected Chunks: %d\n', grandTotalInjected);

%% 3. Output
fprintf('\nWriting patched track: %s\n', patchedTrackFile);
fid = fopen(patchedTrackFile, 'wb');
fwrite(fid, trackData, 'uint8');
fclose(fid);

% https://github.com/alex-free/edcre
% Alex Free, you saved my day !

fprintf('\nRegenerating ECC/EDC checksums...\n');
system(sprintf('edcre -v -s 16 "%s"', patchedTrackFile));

    function data = readbin(path)
        fid = fopen(path, 'rb');
        data = fread(fid, '*uint8');
        fclose(fid);
    end
end