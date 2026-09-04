function modifiedSectors = Binary_file_injector_v2(origDir, hackedDir, trackFile, patchedTrackFile)
%BINARY_FILE_INJECTOR_V2  Patch PRG/SPR files back into a CD track image,
%   using a single "anchor chunk" per file to locate its start offset on
%   the track, then computing every other chunk's position directly by
%   fixed sector stride instead of re-running a global search per chunk.
%
%   This avoids the "changed but repeats >threshold times" skip that a
%   pure per-chunk strfind approach suffers on low-entropy graphics data:
%   only ONE chunk per file needs to be uniquely identifiable, not every
%   chunk that changed.
%
%   modifiedSectors is a sorted vector of 0-based sector indices (i.e.
%   relative to the start of trackFile, in raw 2352-byte-sector units --
%   the same convention as EDCRE_FIX_FILE's 'StartSector'). Feed these
%   straight into the EDC/ECC corrector instead of rescanning the whole
%   image, e.g.:
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

% Immutable reference copy used for ALL searches (anchor-finding,
% verification, and fallback global search). Searching against the
% original bytes -- rather than the live, partially-patched buffer --
% keeps anchor detection deterministic and prevents one file's freshly
% injected bytes from being mistaken for another file's original data.
origTrackDataChar = char(trackData'); % Octave's strfind requires char/string input, not numeric uint8

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
fprintf('\n%-20s | %-8s | %-9s | %-9s | %-9s | %-9s | %s\n', ...
    'Filename', 'Chunks', 'Injected', 'Verified', 'Fallback', 'Skipped', 'Anchor');
fprintf('--------------------------------------------------------------------------------------------------\n');

grandTotalInjected = 0;

for f = 1:length(dataMap)
    fileName = dataMap(f).name;
    origData = dataMap(f).orig;
    hackedData = dataMap(f).hacked;

    numChunks = ceil(length(origData) / chunkSize);

    % Precompute each chunk's orig/hacked bytes once
    chunkOrigAll = cell(numChunks, 1);
    chunkHackedAll = cell(numChunks, 1);
    for c = 1:numChunks
        startByte = (c-1)*chunkSize + 1;
        endByte = min(c*chunkSize, length(origData));
        chunkOrigAll{c} = origData(startByte:endByte);
        chunkHackedAll{c} = hackedData(startByte:endByte);
    end

    %% 2a. Find one unique anchor chunk for this file
    anchorChunk = 0;
    anchorAbsOffset = -1;
    for c = 1:numChunks
        matchPos = strfind(origTrackDataChar, char(chunkOrigAll{c}'));
        if numel(matchPos) == 1
            anchorChunk = c;
            anchorAbsOffset = matchPos(1) - 1;
            break;
        end
    end

    processedCount = 0;
    verifiedCount = 0;
    fallbackCount = 0;
    skippedCount = 0;

    if anchorChunk > 0
        %% 2b. Anchor found -- derive fixed stride, place every chunk directly
        byteOffsetInSector = mod(anchorAbsOffset, sectorSize);
        anchorSector = floor(anchorAbsOffset / sectorSize);
        anchorStr = sprintf('chunk %d @0x%X (sector %d)', anchorChunk, anchorAbsOffset, anchorSector);

        for c = 1:numChunks
            chunkOrig = chunkOrigAll{c};
            chunkHacked = chunkHackedAll{c};

            if isequal(chunkOrig, chunkHacked)
                skippedCount = skippedCount + 1;
                continue;
            end

            targetSector = anchorSector + (c - anchorChunk);
            expectedOffset = targetSector*sectorSize + byteOffsetInSector; % 0-based

            len = length(chunkOrig);
            candidate = trackData(expectedOffset+1 : expectedOffset+len)';

            if isequal(candidate, chunkOrig')
                % Contiguous-stride assumption holds for this chunk: inject directly, no search needed.
                trackData(expectedOffset+1 : expectedOffset+len) = chunkHacked;

                firstSector = floor(expectedOffset / sectorSize);
                lastSector  = floor((expectedOffset + len - 1) / sectorSize);
                modifiedSectors = [modifiedSectors, firstSector:lastSector]; %#ok<AGROW>

                grandTotalInjected = grandTotalInjected + 1;
                processedCount = processedCount + 1;
                verifiedCount = verifiedCount + 1;
            else
                % Assumption broke down for this chunk (e.g. file isn't laid out in a
                % single fixed-stride run) -- fall back to a global search just for it.
                [ok, nSectorsTouched] = injectByGlobalSearch(chunkOrig, chunkHacked, ...
                    fileName, c, origTrackDataChar, paddingThreshold);
                if ok
                    fallbackCount = fallbackCount + 1;
                    processedCount = processedCount + 1;
                    grandTotalInjected = grandTotalInjected + nSectorsTouched.instances;
                    modifiedSectors = [modifiedSectors, nSectorsTouched.sectors]; %#ok<AGROW>
                else
                    skippedCount = skippedCount + 1;
                end
            end
        end
    else
        %% 2c. No unique anchor anywhere in the file -- full fallback to global per-chunk search
        anchorStr = '(none - full fallback)';
        for c = 1:numChunks
            chunkOrig = chunkOrigAll{c};
            chunkHacked = chunkHackedAll{c};

            if isequal(chunkOrig, chunkHacked)
                skippedCount = skippedCount + 1;
                continue;
            end

            [ok, nSectorsTouched] = injectByGlobalSearch(chunkOrig, chunkHacked, ...
                fileName, c, origTrackDataChar, paddingThreshold);
            if ok
                fallbackCount = fallbackCount + 1;
                processedCount = processedCount + 1;
                grandTotalInjected = grandTotalInjected + nSectorsTouched.instances;
                modifiedSectors = [modifiedSectors, nSectorsTouched.sectors]; %#ok<AGROW>
            else
                skippedCount = skippedCount + 1;
            end
        end
    end

    fprintf('%-20s | %-8d | %-9d | %-9d | %-9d | %-9d | %s\n', ...
        fileName, numChunks, processedCount, verifiedCount, fallbackCount, skippedCount, anchorStr);
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

    function [ok, info] = injectByGlobalSearch(chunkOrig, chunkHacked, fileName, c, refChar, threshold)
        % Fallback path: identical in spirit to the original script's
        % per-chunk global search. Injects into trackData (captured from
        % the enclosing scope) at every match found, unless the match
        % count exceeds the ambiguity threshold.
        info.instances = 0;
        info.sectors = [];
        ok = false;

        occurrences = length(strfind(refChar, char(chunkOrig')));
        if occurrences > threshold
            fprintf('  WARNING: chunk %d in %s changed but repeats %d times in track (> threshold %d) - SKIPPED, not injected!\n', ...
                c, fileName, occurrences, threshold);
            return;
        end

        matchPosLocal = strfind(refChar, char(chunkOrig'));
        if isempty(matchPosLocal)
            fprintf('  NOTICE: Chunk %d for %s not found (likely already modified or missing), skipping and continuing...\n', c, fileName);
            return;
        end

        if numel(matchPosLocal) > 1
            fprintf('  WARNING: chunk %d in %s has %d candidate matches. Injecting into all locations at: %s\n', ...
                c, fileName, numel(matchPosLocal), mat2str(matchPosLocal - 1));
        end

        for i = 1:numel(matchPosLocal)
            absOffset = matchPosLocal(i) - 1;
            trackData(absOffset + 1 : absOffset + length(chunkOrig)) = chunkHacked; %#ok<FXSET>

            firstSector = floor(absOffset / sectorSize);
            lastSector  = floor((absOffset + length(chunkOrig) - 1) / sectorSize);
            info.sectors = [info.sectors, firstSector:lastSector];
            info.instances = info.instances + 1;
        end
        ok = true;
    end
end