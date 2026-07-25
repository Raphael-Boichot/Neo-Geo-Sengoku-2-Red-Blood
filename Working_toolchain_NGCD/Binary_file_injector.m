function modifiedSectors = Binary_file_injector(origDir, hackedDir, trackFile, patchedTrackFile)
%BINARY_FILE_INJECTOR  Patch PRG/SPR files back into a CD track image.
%
%   modifiedSectors = BINARY_FILE_INJECTOR(origDir, hackedDir, trackFile, patchedTrackFile)
%
%   modifiedSectors is a sorted vector of 0-based sector indices (i.e.
%   relative to the start of trackFile, in raw 2352-byte-sector units --
%   the same convention as EDCRE_FIX_FILE's 'StartSector') that received
%   at least one injected byte. Feed these straight into the EDC/ECC
%   corrector instead of rescanning the whole image, e.g.:
%
%       fid = fopen(patchedTrackFile, 'r+b');
%       [~, T] = edcre_encode_sector(1, 0, zeros(1,2352)); % build tables once
%       for s = modifiedSectors(:)'
%           fseek(fid, s*2352, 'bof');
%           sec = fread(fid, 2352, 'uint8=>uint8')';
%           mode = sec(16); % 1 = Mode1, 2 = Mode2 (check form1/form2 flag too)
%           sec = edcre_encode_sector(mode, s+150, sec, 'Tables', T, 'Verbose', true);
%           fseek(fid, s*2352, 'bof');
%           fwrite(fid, sec, 'uint8');
%       end
%       fclose(fid);

%% Parameters

chunkSize = 2048;
paddingThreshold = 100;
sectorSize = 2352;
modifiedSectors = [];

%% 1. Initialization and Loading
fprintf('Loading track file into memory...\n');
trackData = readbin(trackFile);
trackData = trackData(:);
trackDataT = trackData'; % transpose once, reused for every search
trackDataTChar = char(trackDataT); % Octave's strfind requires char/string input, not numeric uint8

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
    processedCount = 0;
    ignoredCount = 0;
    skippedCount = 0;

    for c = 1:numChunks
        startByte = (c-1)*chunkSize + 1;
        endByte = min(c*chunkSize, length(origData));
        chunkOrig = origData(startByte:endByte);
        chunkHacked = hackedData(startByte:endByte);

        % Skip if original and hacked chunks are identical.
        if isequal(chunkOrig, chunkHacked)
            skippedCount = skippedCount + 1;
            continue;
        end

        % Check for ambiguous padding patterns
        occurrences = length(strfind(trackDataTChar, char(chunkOrig')));
        if occurrences > paddingThreshold
            fprintf('  WARNING: chunk %d in %s changed but repeats %d times in track (> threshold %d) - SKIPPED, not injected!\n', ...
                c, fileName, occurrences, paddingThreshold);
            ignoredCount = ignoredCount + 1;
            continue;
        end

        % Search globally
        searchArea = trackData;
        matchPosLocal = strfind(char(searchArea'), char(chunkOrig'));

        if ~isempty(matchPosLocal)
            if numel(matchPosLocal) > 1
                fprintf('  WARNING: chunk %d in %s has %d candidate matches. Injecting into all locations at: %s\n', ...
                    c, fileName, numel(matchPosLocal), mat2str(matchPosLocal - 1));
            end

            % Inject into all found locations
            for i = 1:numel(matchPosLocal)
                absOffset = matchPosLocal(i) - 1;
                trackData(absOffset + 1 : absOffset + length(chunkOrig)) = chunkHacked;
                trackDataT(absOffset + 1 : absOffset + length(chunkOrig)) = chunkHacked';
                trackDataTChar(absOffset + 1 : absOffset + length(chunkOrig)) = char(chunkHacked');

                % Record every raw sector this injection touched (a chunk
                % can straddle a sector boundary if it isn't aligned to
                % sectorSize), so the caller can target the ECC/EDC
                % corrector at exactly these sectors afterwards.
                firstSector = floor(absOffset / sectorSize);
                lastSector  = floor((absOffset + length(chunkOrig) - 1) / sectorSize);
                modifiedSectors = [modifiedSectors, firstSector:lastSector]; %#ok<AGROW>

                % Increment grand total for every individual injection performed
                grandTotalInjected = grandTotalInjected + 1;
            end

            processedCount = processedCount + 1;
        else
            fprintf('  NOTICE: Chunk %d for %s not found (likely already modified or missing), skipping and continuing...\n', c, fileName);
            continue;
        end
    end

    fprintf('%-20s | %-12d | %-12d | %-12d | %-12d\n', fileName, numChunks, processedCount, ignoredCount, skippedCount);
end

modifiedSectors = unique(modifiedSectors);
fprintf('\nGrand Total Injected Instances: %d\n', grandTotalInjected);
fprintf('Sectors touched: %d\n', numel(modifiedSectors));

%% 3. Output
fprintf('\nWriting patched track: %s\n', patchedTrackFile);
fid = fopen(patchedTrackFile, 'wb');
fwrite(fid, trackData, 'uint8');
fclose(fid);

    function data = readbin(path)
        fid = fopen(path, 'rb');
        data = fread(fid, '*uint8');
        fclose(fid);
    end
end