function build_Raw_Bin_from_Folder(isoFile, binFile, opts)
%BUILD_RAW_BIN_FROM_FOLDER Wrap a plain ISO9660 image into a raw
%CD-ROM Mode1 .bin image (2352 bytes/sector, with correct sync/
%header/EDC/ECC). This is the raw-sector counterpart of
%build_ISO_from_Folder: it does NOT scan a folder itself -- build the
%.iso first with build_ISO_from_Folder, then wrap it here. Splitting
%the two steps lets you reuse each independently (e.g. inspect/patch
%the .iso by hand before wrapping, or wrap a .iso that came from
%somewhere else entirely).
%
%   build_Raw_Bin_from_Folder(isoFile, binFile)
%   build_Raw_Bin_from_Folder(isoFile, binFile, opts)
%
%   isoFile  - path to an existing plain ISO9660 image (2048
%              bytes/sector), typically produced by build_ISO_from_Folder.
%   binFile  - path of the .bin file to create (2352 bytes/sector,
%              Mode1). A matching .cue file with the same base name
%              is also written alongside it.
%   opts     - optional struct of advanced settings, all optional:
%
%     opts.TotalSectors - pad the output with extra zero-data Mode1
%                       sectors (valid sync/header/EDC/ECC, continuing
%                       the MSF sequence) until the raw image reaches
%                       exactly this many 2352-byte sectors. Useful
%                       when the ISO9660 filesystem doesn't use the
%                       disc's full declared track length (common on
%                       original mastered discs -- there can be a
%                       large gap of empty sectors after the last file
%                       before the track's nominal end).
%
%     opts.ReferenceBin - path to an existing .bin (or .iso) image.
%                       If opts.TotalSectors isn't given explicitly,
%                       the total raw sector count is taken from this
%                       reference file instead (its size / 2352, or
%                       size / 2048 if it's a plain .iso -- in which
%                       case no raw padding is applicable and this is
%                       ignored).
%
%   Example (generic use):
%       build_Raw_Bin_from_Folder('rebuilt.iso', 'rebuilt.bin')
%
%   Example (matching an original disc's exact raw length):
%       opts = struct();
%       opts.ReferenceBin = 'original.bin';
%       build_Raw_Bin_from_Folder('rebuilt.iso', 'rebuilt.bin', opts);
%
%   The EDC/ECC algorithm was verified byte-for-byte against a real
%   CD-ROM Mode1 image before being used here: recomputing EDC/ECC
%   for every sector of that reference image and comparing against
%   the image's actual stored EDC/ECC bytes gave 0 mismatches.

    if nargin < 2
        error('build_Raw_Bin_from_Folder:nargin', ...
            'Usage: build_Raw_Bin_from_Folder(isoFile, binFile [, opts])');
    end
    if ~isfile(isoFile)
        error('build_Raw_Bin_from_Folder:noIso', 'ISO file not found: %s', isoFile);
    end
    if nargin < 3
        opts = struct();
    end
    if ~isfield(opts, 'TotalSectors')
        opts.TotalSectors = [];
    end
    if ~isfield(opts, 'ReferenceBin')
        opts.ReferenceBin = '';
    end

    targetTotalSectors = opts.TotalSectors;
    if isempty(targetTotalSectors) && ~isempty(opts.ReferenceBin)
        [refSectorSize, ~] = detectLayout(opts.ReferenceBin);
        if refSectorSize == 2352
            info = dir(opts.ReferenceBin);
            targetTotalSectors = floor(info(1).bytes / 2352);
            fprintf('Using total sector count from reference "%s": %d sectors\n', ...
                opts.ReferenceBin, targetTotalSectors);
        end
    end

    fprintf('Wrapping "%s" into raw 2352-byte/sector Mode1 image ...\n', isoFile);
    wrapPlainISOToRawBin(isoFile, binFile, targetTotalSectors);

    % Write a matching .cue file
    [cueDir, cueName] = fileparts(binFile);
    cueFile = fullfile(cueDir, [cueName '.cue']);
    [~, binName, binExt] = fileparts(binFile);
    fid = fopen(cueFile, 'w');
    fprintf(fid, 'FILE "%s%s" BINARY\n', binName, binExt);
    fprintf(fid, '  TRACK 01 MODE1/2352\n');
    fprintf(fid, '    INDEX 01 00:00:00\n');
    fclose(fid);

    fprintf('Done. Wrote %s and %s\n', binFile, cueFile);
end

% ===================================================================
function [sectorSize, dataOffset] = detectLayout(path)
    fid = fopen(path, 'rb');
    fseek(fid, 0, 'eof');
    fileSize = ftell(fid);
    fseek(fid, 0, 'bof');
    header = fread(fid, 16, 'uint8=>uint8')';
    fclose(fid);

    sectorSize = 2048;
    dataOffset = 0;
    if mod(fileSize, 2352) == 0
        syncPattern = uint8([0 255 255 255 255 255 255 255 255 255 255 0]);
        if numel(header) == 16 && isequal(header(1:12), syncPattern)
            sectorSize = 2352;
            dataOffset = 16;
        end
    end
end

% ===================================================================
function wrapPlainISOToRawBin(isoFile, binFile, targetTotalSectors)
    [edcLut, fLut, bLut] = buildTables();

    ifid = fopen(isoFile, 'rb');
    fseek(ifid, 0, 'eof');
    isoSize = ftell(ifid);
    fseek(ifid, 0, 'bof');
    numIsoSectors = ceil(isoSize / 2048);

    if isempty(targetTotalSectors)
        totalSectors = numIsoSectors;
    else
        totalSectors = targetTotalSectors;
        if totalSectors < numIsoSectors
            warning('build_Raw_Bin_from_Folder:tooSmall', ...
                ['Requested TotalSectors (%d) is smaller than the ISO itself ' ...
                 '(%d sectors); writing %d sectors, no padding applied.'], ...
                totalSectors, numIsoSectors, numIsoSectors);
            totalSectors = numIsoSectors;
        end
    end

    ofid = fopen(binFile, 'wb');
    if ofid == -1
        error('build_Raw_Bin_from_Folder:openFail', 'Could not create file: %s', binFile);
    end

    sync = uint8([0 255 255 255 255 255 255 255 255 255 255 0])';

    fprintf('Encoding %d sectors (%d from ISO content, %d zero-padded) ...\n', ...
        totalSectors, numIsoSectors, totalSectors - numIsoSectors);

    chunkSize = 4000; % bounds memory use for large images
    n0 = 0;
    while n0 < totalSectors
        thisChunk = min(chunkSize, totalSectors - n0);

        isoRemaining = max(0, numIsoSectors - n0);
        fromIso = min(thisChunk, isoRemaining);
        fromPad = thisChunk - fromIso;

        if fromIso > 0
            userDataIso = fread(ifid, [2048, fromIso], 'uint8=>uint8');
            if size(userDataIso, 1) < 2048 || size(userDataIso, 2) < fromIso
                padded = zeros(2048, fromIso, 'uint8');
                padded(1:size(userDataIso,1), 1:size(userDataIso,2)) = userDataIso;
                userDataIso = padded;
            end
        else
            userDataIso = zeros(2048, 0, 'uint8');
        end

        if fromPad > 0
            userDataPad = zeros(2048, fromPad, 'uint8');
        else
            userDataPad = zeros(2048, 0, 'uint8');
        end

        userData = [userDataIso, userDataPad]; % 2048 x thisChunk

        n = (n0:n0+thisChunk-1)';
        frameTotal = n + 150; % LBA 0 == MSF 00:02:00
        mm = floor(frameTotal / (60*75));
        rem1 = mod(frameTotal, 60*75);
        ss = floor(rem1 / 75);
        ff = mod(rem1, 75);
        header = [toBCD(mm)'; toBCD(ss)'; toBCD(ff)'; ones(1, thisChunk, 'uint8')]; % 4 x chunk

        syncMat = repmat(sync, 1, thisChunk); % 12 x chunk

        edcSrc = [syncMat; header; userData]; % 2064 x chunk
        edcVal = edcComputeVec(edcSrc, edcLut);
        edcBytes = uint32ToLEvec(edcVal); % 4 x chunk

        zero8 = zeros(8, thisChunk, 'uint8');

        address = double([header; userData; edcBytes; zero8]); % 2064 x chunk
        eccBytes = eccWriteSectorVec(address, fLut, bLut); % 276 x chunk

        allSectors = [syncMat; header; userData; edcBytes; zero8; eccBytes]; % 2352 x chunk
        fwrite(ofid, allSectors, 'uint8'); % column-major write = sector-by-sector

        n0 = n0 + thisChunk;
        fprintf('  %d / %d sectors\n', n0, totalSectors);
    end

    fclose(ifid);
    fclose(ofid);
end

% ===================================================================
function [edcLut, fLut, bLut] = buildTables()
    edcLut = zeros(256, 1, 'uint32');
    for i = 0:255
        edc = uint32(i);
        for j = 1:8
            if bitand(edc, uint32(1)) ~= 0
                edc = bitxor(bitshift(edc, -1), uint32(3623976961)); % 0xD8018001
            else
                edc = bitshift(edc, -1);
            end
        end
        edcLut(i+1) = edc;
    end

    fLut = zeros(256, 1);
    bLut = zeros(256, 1);
    for i = 0:255
        if bitand(i, 128) ~= 0
            j = bitxor(bitshift(i, 1), 285); % 0x11D
        else
            j = bitshift(i, 1);
        end
        j = bitand(j, 255);
        fLut(i+1) = j;
        bLut(bitxor(i, j)+1) = i;
    end
end

% ===================================================================
function edcVal = edcComputeVec(dataMat, edcLut)
    % dataMat: bytesPerSector x numSectors uint8
    [numBytes, numSectors] = size(dataMat);
    edc = zeros(1, numSectors, 'uint32');
    dataMat32 = uint32(dataMat);
    for i = 1:numBytes
        idx = bitand(bitxor(edc, dataMat32(i,:)), uint32(255)) + 1;
        edc = bitxor(edcLut(idx)', bitshift(edc, -8));
    end
    edcVal = edc;
end

% ===================================================================
function bytes = uint32ToLEvec(v)
    v = double(v);
    bytes = uint8([mod(v,256); mod(floor(v/256),256); mod(floor(v/65536),256); floor(v/16777216)]);
end

% ===================================================================
function b = toBCD(v)
    b = uint8(floor(v/10)*16 + mod(v,10));
end

% ===================================================================
function eccBytes = eccWriteSectorVec(address, fLut, bLut)
    % address: 2064 x numSectors double, representing per-sector
    % header(4) + userData(2048) + EDC(4) + zero(8)
    p = eccWritePQvec(address, 86, 24, 2, 86, fLut, bLut);   % 172 x N
    combined = [address; double(p)];                          % 2236 x N
    q = eccWritePQvec(combined, 52, 43, 86, 88, fLut, bLut);  % 104 x N
    eccBytes = [p; q];
end

% ===================================================================
function out = eccWritePQvec(address, majorCount, minorCount, majorMult, minorInc, fLut, bLut)
    sz = majorCount * minorCount;
    numSectors = size(address, 2);

    majors = (0:majorCount-1)';
    idxVec = floor(majors/2)*majorMult + mod(majors, 2); % majorCount x 1, 0-based

    eccA = zeros(majorCount, numSectors);
    eccB = zeros(majorCount, numSectors);

    for minor = 0:minorCount-1
        temp = address(idxVec + 1, :); % majorCount x numSectors
        idxVec = idxVec + minorInc;
        wrap = idxVec >= sz;
        idxVec(wrap) = idxVec(wrap) - sz;

        eccA = bitxor(eccA, temp);
        eccB = bitxor(eccB, temp);
        eccA = fLut(eccA + 1);
    end

    eccA = bLut(bitxor(fLut(eccA + 1), eccB) + 1);
    out = [uint8(eccA); uint8(bitxor(eccA, eccB))]; % 2*majorCount x numSectors
end
