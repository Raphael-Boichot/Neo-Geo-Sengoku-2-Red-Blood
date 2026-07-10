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

sourceFiles = [dir(fullfile(origDir, '*.PRG')); dir(fullfile(origDir, '*.SPR'))];
dataMap = struct('name', {}, 'orig', {}, 'hacked', {});

for f = 1:length(sourceFiles)
    fileName = sourceFiles(f).name;
    hackedPath = fullfile(hackedDir, fileName);
    if exist(hackedPath, 'file')
        dataMap(end+1).name = fileName;
        dataMap(end).orig = readbin(fullfile(sourceFiles(f).folder, fileName));
        dataMap(end).hacked = readbin(hackedPath);
    end
end

%% 2. Processing with Per-File Reporting
fprintf('\n%-20s | %-12s | %-12s | %-12s\n', 'Filename', 'Total Chunks', 'Processed', 'Ignored (padding)');
fprintf('----------------------------------------------------------------------------\n');

for f = 1:length(dataMap)
    fileName = dataMap(f).name;
    origData = dataMap(f).orig;
    hackedData = dataMap(f).hacked;
    
    numChunks = ceil(length(origData) / chunkSize);
    lastMatchOffset = 0;
    processedCount = 0;
    ignoredCount = 0;

    for c = 1:numChunks
        startByte = (c-1)*chunkSize + 1;
        endByte = min(c*chunkSize, length(origData));
        chunk = origData(startByte:endByte);

        % Count padding/duplicates as ignored
        if length(strfind(trackData', chunk')) > paddingThreshold
            ignoredCount = ignoredCount + 1;
            continue;
        end

        searchArea = trackData(lastMatchOffset + 1 : end);
        matchPosLocal = strfind(searchArea', chunk');

        if ~isempty(matchPosLocal)
            absOffset = lastMatchOffset + matchPosLocal(1) - 1;
            trackData(absOffset + 1 : absOffset + length(chunk)) = hackedData(startByte:endByte);
            lastMatchOffset = absOffset + chunkSize;
            processedCount = processedCount + 1;
        else
            error('CRITICAL: Could not locate chunk %d for %s.', c, fileName);
        end
    end
    
    % Update status table for each file
    fprintf('%-20s | %-12d | %-12d | %-12d\n', fileName, numChunks, processedCount, ignoredCount);
end

%% 3. Output
fprintf('\nWriting patched track: %s\n', patchedTrackFile);
fid = fopen(patchedTrackFile, 'wb');
fwrite(fid, trackData, 'uint8');
fclose(fid);

% https://github.com/alex-free/edcre
% alex-free, you saved my day !
fprintf('\nRegenerating ECC/EDC checksums...\n');
system(sprintf('edcre -v -s 16 "%s"', patchedTrackFile));

    function data = readbin(path)
        fid = fopen(path, 'rb');
        data = fread(fid, '*uint8');
        fclose(fid);
    end
end