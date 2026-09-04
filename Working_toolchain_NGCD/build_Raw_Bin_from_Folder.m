function build_Raw_Bin_from_Folder(inputDir, binFile)
%BUILDRAWBINFROMFOLDER Build a raw CD-ROM Mode1 .bin image (2352
%bytes/sector, with correct sync/header/EDC/ECC) from a folder of
%files. This is the raw-sector counterpart of build_ISO_from_Folder: it
%first lays out a standard ISO9660 filesystem (same directory tree,
%same file placement) and then wraps every 2048-byte logical sector
%into a full Mode1 raw sector, computing:
%   - 12-byte sync pattern
%   - 4-byte header (MM:SS:FF in BCD, mode = 1)
%   - 2048 bytes of user data
%   - 4-byte EDC  (CRC-32 variant used by the Red Book / ECMA-130,
%                  polynomial 0xD8018001)
%   - 8 reserved zero bytes
%   - 276-byte Reed-Solomon P/Q ECC (product code, per ECMA-130)
%
%   buildRawBinFromFolder(inputDir, binFile)
%
%   inputDir - folder containing the files/folders to pack (e.g. the
%              output of extractISOFromBin).
%   binFile  - path of the .bin file to create (2352 bytes/sector,
%              Mode1). A matching .cue file with the same base name
%              is also written alongside it.
%
%   Example:
%       buildRawBinFromFolder('extracted_files', 'rebuilt.bin')
%
%   The EDC/ECC algorithm was verified byte-for-byte against a real
%   CD-ROM Mode1 image before being used here: recomputing EDC/ECC
%   for every sector of that reference image and comparing against
%   the image's actual stored EDC/ECC bytes gave 0 mismatches.

    if nargin < 2
        error('buildRawBinFromFolder:nargin', ...
            'Usage: buildRawBinFromFolder(inputDir, binFile)');
    end
    if ~isfolder(inputDir)
        error('buildRawBinFromFolder:noDir', 'Input folder not found: %s', inputDir);
    end

    [binDir, binBaseName] = fileparts(binFile);
    if isempty(binDir)
        binDir = pwd;
    end
    tmpIso = fullfile(binDir, [binBaseName '_temp.iso']);
    % Kept (not deleted) after the build so it's available alongside
    % the .bin/.cue for testing/inspection.

    fprintf('--- Step 1: building ISO9660 layout ---\n');
    build_ISO_from_Folder(inputDir, tmpIso);

    fprintf('--- Step 2: wrapping into raw 2352-byte/sector Mode1 image ---\n');
    wrapPlainISOToRawBin(tmpIso, binFile);

    % Write a matching .cue file
    [cueDir, cueName] = fileparts(binFile);
    cueFile = fullfile(cueDir, [cueName '.cue']);
    [~, binName, binExt] = fileparts(binFile);
    fid = fopen(cueFile, 'w');
    fprintf(fid, 'FILE "%s%s" BINARY\n', binName, binExt);
    fprintf(fid, '  TRACK 01 MODE1/2352\n');
    fprintf(fid, '    INDEX 01 00:00:00\n');
    fclose(fid);

    fprintf('Done. Wrote %s, %s and %s\n', binFile, cueFile, tmpIso);
end

% ===================================================================
function safeDelete(f)
    if isfile(f)
        delete(f);
    end
end

% ===================================================================
function wrapPlainISOToRawBin(isoFile, binFile)
    [edcLut, fLut, bLut] = buildTables();

    ifid = fopen(isoFile, 'rb');
    fseek(ifid, 0, 'eof');
    isoSize = ftell(ifid);
    fseek(ifid, 0, 'bof');
    numSectors = ceil(isoSize / 2048);

    ofid = fopen(binFile, 'wb');
    if ofid == -1
        error('buildRawBinFromFolder:openFail', 'Could not create file: %s', binFile);
    end

    sync = uint8([0 255 255 255 255 255 255 255 255 255 255 0])';

    fprintf('Encoding %d sectors ...\n', numSectors);

    chunkSize = 4000; % bounds memory use for large images
    n0 = 0;
    while n0 < numSectors
        thisChunk = min(chunkSize, numSectors - n0);

        userData = fread(ifid, [2048, thisChunk], 'uint8=>uint8');
        if size(userData, 1) < 2048 || size(userData, 2) < thisChunk
            padded = zeros(2048, thisChunk, 'uint8');
            padded(1:size(userData,1), 1:size(userData,2)) = userData;
            userData = padded;
        end

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
        fprintf('  %d / %d sectors\n', n0, numSectors);
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