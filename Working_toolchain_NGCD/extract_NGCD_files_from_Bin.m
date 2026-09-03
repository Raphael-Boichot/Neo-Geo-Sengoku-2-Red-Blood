function extract_NGCD_files_from_Bin(binFile, outputDir)
%EXTRACTISOFROMBIN Extract all files from an ISO9660 CD image.
%
%   extractISOFromBin(binFile, outputDir)
%
%   binFile   - path to the .bin (or .iso) image containing an ISO9660
%               filesystem. Both raw CD images (2352 bytes/sector,
%               Mode1 or Mode2/XA Form1) and plain 2048 byte/sector
%               ISO images are supported and auto-detected.
%   outputDir - folder where the extracted files/folders will be
%               written. It is created if it does not already exist.
%
%   Example:
%       extractISOFromBin('game_Track_01.bin', 'extracted_files')
%
%   The function parses the Primary Volume Descriptor, walks the
%   directory tree starting at the root directory, and recursively
%   recreates the same folder structure found in the image, writing
%   every file it finds.

    if nargin < 2
        error('extractISOFromBin:nargin', ...
            'Usage: extractISOFromBin(binFile, outputDir)');
    end

    if ~isfile(binFile)
        error('extractISOFromBin:noFile', 'Input file not found: %s', binFile);
    end

    if ~isfolder(outputDir)
        mkdir(outputDir);
    end

    fid = fopen(binFile, 'rb');
    if fid == -1
        error('extractISOFromBin:openFail', 'Could not open file: %s', binFile);
    end
    cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

    % ---- Detect sector layout (raw CD image vs plain ISO) ----
    fseek(fid, 0, 'eof');
    fileSize = ftell(fid);

    layout = detectLayout(fid, fileSize);
    fprintf('Detected sector size: %d bytes, data offset: %d (%s)\n', ...
        layout.sectorSize, layout.dataOffset, layout.description);

    % ---- Locate & parse Primary Volume Descriptor (sector 16) ----
    pvd = readLogicalSector(fid, layout, 16);
    if pvd(1) ~= 1 || ~isequal(char(pvd(2:6))', 'CD001')
        error('extractISOFromBin:noPVD', ...
            'Primary Volume Descriptor not found at sector 16. This may not be an ISO9660 image.');
    end

    % Root directory record occupies bytes 157-190 (1-based) i.e.
    % 0-based offset 156, length 34
    rootRecord = pvd(157:190);
    rootEntry = parseDirRecord(rootRecord);

    fprintf('Extracting "%s" -> "%s" ...\n', binFile, outputDir);

    count = struct('files', 0, 'dirs', 0);
    count = extractDirectory(fid, layout, rootEntry.lba, rootEntry.dataLen, outputDir, count);

    fprintf('Done. Extracted %d files in %d directories.\n', count.files, count.dirs);
end

% ===================================================================
function layout = detectLayout(fid, fileSize)
% Determine whether the image is a raw CD sector dump (2352 bytes per
% sector, with a 16-byte sync+header before the 2048 bytes of user
% data) or a plain ISO image (2048 bytes per sector, no header).

    rawSectorSize = 2352;
    isoSectorSize = 2048;

    layout = struct('sectorSize', isoSectorSize, 'dataOffset', 0, ...
        'description', 'plain 2048-byte ISO9660');

    if mod(fileSize, rawSectorSize) == 0
        fseek(fid, 0, 'bof');
        header = fread(fid, 16, 'uint8=>uint8')';
        syncPattern = uint8([0 255 255 255 255 255 255 255 255 255 255 0]);
        if numel(header) == 16 && isequal(header(1:12), syncPattern)
            mode = header(16);
            if mode == 1
                layout = struct('sectorSize', rawSectorSize, 'dataOffset', 16, ...
                    'description', 'raw CD image, Mode1 (2352 bytes/sector)');
            elseif mode == 2
                % Mode2/XA: 8-byte sub-header follows the 16-byte
                % header before the 2048 bytes of user data (Form 1).
                layout = struct('sectorSize', rawSectorSize, 'dataOffset', 24, ...
                    'description', 'raw CD image, Mode2/XA Form1 (2352 bytes/sector)');
            else
                % Fallback: assume Mode1 layout
                layout = struct('sectorSize', rawSectorSize, 'dataOffset', 16, ...
                    'description', 'raw CD image, assumed Mode1 (2352 bytes/sector)');
            end
        end
    end

    if mod(fileSize, isoSectorSize) ~= 0 && layout.sectorSize == isoSectorSize
        warning('extractISOFromBin:sizeMismatch', ...
            ['File size is not a multiple of 2048 or 2352 bytes; ' ...
             'attempting to read as a plain ISO anyway.']);
    end
end

% ===================================================================
function data = readLogicalSector(fid, layout, lba)
% Read the 2048 bytes of user data for logical block address "lba".
    offset = double(lba) * layout.sectorSize + layout.dataOffset;
    fseek(fid, offset, 'bof');
    data = fread(fid, 2048, 'uint8=>uint8');
    if numel(data) < 2048
        data(end+1:2048) = 0;
    end
end

% ===================================================================
function data = readLogicalRange(fid, layout, lba, numBytes)
% Read numBytes of user data starting at logical block address "lba",
% concatenating consecutive 2048-byte logical sectors as needed.
    numSectors = ceil(numBytes / 2048);
    data = zeros(numSectors * 2048, 1, 'uint8');
    for s = 0:numSectors-1
        sectorData = readLogicalSector(fid, layout, lba + s);
        data(s*2048+1 : s*2048+2048) = sectorData;
    end
    data = data(1:numBytes);
end

% ===================================================================
function val = le32(bytes)
% Decode a little-endian 32-bit unsigned integer from a 4-byte vector.
    b = double(bytes);
    val = b(1) + b(2)*256 + b(3)*65536 + b(4)*16777216;
end

% ===================================================================
function entry = parseDirRecord(rec)
% Parse a single ISO9660 directory record (variable length, starts
% with its own length as the first byte). rec is a column/row uint8
% vector containing at least the full record.
    entry = struct();
    entry.recLen = double(rec(1));
    if entry.recLen == 0
        return;
    end
    % Location of extent: both-endian, LE copy at bytes 3-6 (1-based)
    entry.lba = le32(rec(3:6));
    % Data length: both-endian, LE copy at bytes 11-14 (1-based)
    entry.dataLen = le32(rec(11:14));
    flags = double(rec(26));
    entry.isDir = bitand(flags, 2) ~= 0;
    idLen = double(rec(33));
    entry.idLen = idLen;
    if idLen > 0
        idBytes = rec(34:33+idLen);
        entry.name = char(idBytes(:)');
    else
        entry.name = '';
    end
end

% ===================================================================
function name = cleanFileName(rawName)
% Strip ISO9660 version suffix (";1") and, for extensionless files,
% the trailing separator dot.
    name = rawName;
    semiIdx = strfind(name, ';');
    if ~isempty(semiIdx)
        name = name(1:semiIdx(1)-1);
    end
    if ~isempty(name) && name(end) == '.'
        name(end) = [];
    end
    if isempty(name)
        name = '_';
    end
end

% ===================================================================
function count = extractDirectory(fid, layout, lba, dataLen, outDir, count)
% Recursively walk a directory extent, extracting files and
% recursing into subdirectories.

    buf = readLogicalRange(fid, layout, lba, dataLen);
    pos = 1;               % 1-based index into buf
    n = numel(buf);

    while pos <= n
        recLen = double(buf(pos));

        if recLen == 0
            % Padding: skip forward to the next 2048-byte sector
            % boundary (directory records never span sectors).
            currentSectorStart = floor((pos-1)/2048)*2048;
            nextBoundary = currentSectorStart + 2048 + 1;
            if nextBoundary > n
                break;
            end
            pos = nextBoundary;
            continue;
        end

        recBytes = buf(pos : min(pos+recLen-1, n));
        entry = parseDirRecord(recBytes);

        isDotEntry = (entry.idLen == 1) && ...
            (double(recBytes(34)) == 0 || double(recBytes(34)) == 1);

        if ~isDotEntry && ~isempty(entry.name)
            if entry.isDir
                subName = cleanFileName(entry.name);
                subOutDir = fullfile(outDir, subName);
                if ~isfolder(subOutDir)
                    mkdir(subOutDir);
                end
                count.dirs = count.dirs + 1;
                fprintf('  [DIR]  %s\n', subOutDir);
                count = extractDirectory(fid, layout, entry.lba, entry.dataLen, subOutDir, count);
            else
                fileName = cleanFileName(entry.name);
                outPath = fullfile(outDir, fileName);
                fileData = readLogicalRange(fid, layout, entry.lba, entry.dataLen);
                ofid = fopen(outPath, 'wb');
                if ofid == -1
                    warning('extractISOFromBin:writeFail', ...
                        'Could not create output file: %s', outPath);
                else
                    fwrite(ofid, fileData, 'uint8');
                    fclose(ofid);
                    count.files = count.files + 1;
                    fprintf('  [FILE] %s (%d bytes)\n', outPath, entry.dataLen);
                end
            end
        end

        pos = pos + recLen;
    end
end
