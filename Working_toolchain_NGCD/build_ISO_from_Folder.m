function build_ISO_from_Folder(inputDir, isoFile, opts)
%BUILD_ISO_FROM_FOLDER Build a plain ISO9660 image from a folder of files.
%   This is the inverse operation of extractISOFromBin: it walks a
%   folder (including subfolders), packs everything it finds into a
%   standard ISO9660 filesystem, and writes it out as a 2048
%   byte/sector .iso image.
%
%   build_ISO_from_Folder(inputDir, isoFile)
%   build_ISO_from_Folder(inputDir, isoFile, opts)
%
%   inputDir - folder containing the files/folders to pack (e.g. the
%              output of extractISOFromBin).
%   isoFile  - path of the .iso file to create.
%   opts     - optional struct of advanced settings, all optional:
%
%     opts.SortMode  - how children are ordered within each directory:
%                       'alpha'     (default) - ISO9660 name, ascending
%                       'type'      - by extension, then name
%                       'size_asc'  - by file size, ascending
%                       'size_desc' - by file size, descending
%                       'none'      - keep OS directory listing order
%
%     opts.ReferenceBin - path to an existing .bin or .iso image
%                       (typically the original, unmodified disc). When
%                       given, the following are all copied byte-for-
%                       byte from that reference instead of using
%                       generic defaults:
%                         - PVD text fields (System/Volume/Publisher/
%                           DataPreparer/Application/VolumeSet id)
%                         - PVD creation/modification/expiration/
%                           effective date fields (raw 17-byte fields)
%                         - Per-file directory-record timestamps,
%                           matched by ISO9660 filename. Files with no
%                           match fall back to opts.DefaultFileDate.
%                       This is the mechanism that makes byte-exact
%                       (matching CRC32) reproduction of an original
%                       disc possible, provided the packed file content
%                       is byte-identical and the same file set/order
%                       results from opts.SortMode.
%
%     opts.SystemId, opts.VolumeId, opts.DataPreparerId,
%     opts.ApplicationId, opts.PublisherId, opts.VolumeSetId
%                     - explicit string overrides. Take priority over
%                       whatever opts.ReferenceBin harvested.
%
%     opts.DefaultFileDate - 6-element [YYYY MM DD HH MM SS] used for
%                       any file/directory whose timestamp isn't found
%                       in opts.ReferenceBin. Defaults to now().
%
%   Example (generic use):
%       build_ISO_from_Folder('extracted_files', 'rebuilt.iso')
%
%   Example (byte-exact reproduction of an original disc):
%       opts = struct();
%       opts.ReferenceBin = 'original.bin';
%       opts.SortMode = 'alpha';
%       build_ISO_from_Folder('hacked_files', 'rebuilt.iso', opts);
%
%   NOTE: This produces a plain 2048-byte/sector ISO9660 image (data
%   track only), not a raw 2352-byte/sector .bin/.cue pair. Use
%   build_Raw_Bin_from_Folder to wrap the resulting .iso into a raw
%   Mode1 .bin with correct sync/header/EDC/ECC.
%   Filenames are automatically uppercased and restricted to the
%   ISO9660 character set (A-Z 0-9 _ .); anything else is replaced
%   with an underscore.

    if nargin < 2
        error('build_ISO_from_Folder:nargin', ...
            'Usage: build_ISO_from_Folder(inputDir, isoFile [, opts])');
    end
    if ~isfolder(inputDir)
        error('build_ISO_from_Folder:noDir', 'Input folder not found: %s', inputDir);
    end
    if nargin < 3
        opts = struct();
    end
    opts = fillDefaultOpts(opts);

    refMeta = [];
    if ~isempty(opts.ReferenceBin)
        fprintf('Harvesting metadata from reference "%s" ...\n', opts.ReferenceBin);
        refMeta = harvestReferenceMetadata(opts.ReferenceBin);
        fprintf('  system id: "%s"\n', strtrim(refMeta.systemId));
        fprintf('  volume id: "%s"\n', strtrim(refMeta.volumeId));
        fprintf('  data preparer id: "%s"\n', strtrim(refMeta.dataPreparerId));
        fprintf('  %d per-file timestamps harvested\n', refMeta.fileDates.Count);
        if ~refMeta.usesVersionSuffix
            fprintf('  reference does not use ";1" version suffixes in filenames\n');
        end
    end

    if isempty(opts.OmitVersion)
        if ~isempty(refMeta)
            omitVersion = ~refMeta.usesVersionSuffix;
        else
            omitVersion = false;
        end
    else
        omitVersion = opts.OmitVersion;
    end

    fprintf('Scanning "%s" ...\n', inputDir);
    emptyNodes = struct('name',{},'diskPath',{},'isDir',{},'isoName',{}, ...
        'size',{},'childIdx',{},'parentIdx',{}, ...
        'dirSectors',{},'lba',{},'dirNumber',{},'parentNumber',{});
    [nodes, rootIdx] = scanFolderFlat(emptyNodes, 0, inputDir, '', true, opts.SortMode, omitVersion);

    hasSubdirs = false;
    for i = 1:numel(nodes)
        if nodes(i).isDir && i ~= rootIdx
            hasSubdirs = true;
        end
    end
    if hasSubdirs
        fprintf(['NOTE: subfolders were found in "%s". If you are targeting an\n' ...
                  '  old single-level filesystem (e.g. a console disc), verify that\n' ...
                  '  a flat layout (no subfolders) is actually expected.\n'], inputDir);
    end

    fprintf('Computing directory layouts ...\n');
    for i = 1:numel(nodes)
        if nodes(i).isDir
            recLens = [recordLength(1), recordLength(1)]; % '.' and '..', never have extra bytes
            for c = nodes(i).childIdx
                extraLen = numel(lookupExtra(nodes(c).isoName, refMeta));
                recLens(end+1) = recordLength(numel(nodes(c).isoName)) + extraLen; %#ok<AGROW>
            end
            nodes(i).dirSectors = layoutSectorCountFromRecLens(recLens);
        end
    end

    fprintf('Assigning directory order and numbers ...\n');
    dirOrder = rootIdx;
    nodes(rootIdx).dirNumber = 1;
    nodes(rootIdx).parentNumber = 1;
    qi = 1;
    while qi <= numel(dirOrder)
        ni = dirOrder(qi);
        for c = nodes(ni).childIdx
            if nodes(c).isDir
                dirOrder(end+1) = c; %#ok<AGROW>
                nodes(c).dirNumber = numel(dirOrder);
                nodes(c).parentNumber = nodes(ni).dirNumber;
            end
        end
        qi = qi + 1;
    end

    pathTableSize = 0;
    for i = 1:numel(dirOrder)
        pathTableSize = pathTableSize + pathTableEntryLen(nodes(dirOrder(i)), dirOrder(i) == rootIdx);
    end
    pathTableSectors = max(1, ceil(pathTableSize / 2048));

    % ---- LBA assignment ----
    lba = 18; % after 16 system sectors + PVD(1) + terminator(1)
    lbaLPath = lba; lba = lba + pathTableSectors;
    lbaMPath = lba; lba = lba + pathTableSectors;

    for i = 1:numel(dirOrder)
        idx = dirOrder(i);
        nodes(idx).lba = lba;
        lba = lba + nodes(idx).dirSectors;
    end

    % File nodes: the flat array was built in DFS pre-order by
    % scanFolderFlat, so filtering by ~isDir already gives a stable,
    % consistent traversal order.
    fileOrder = find(~[nodes.isDir]);
    for i = 1:numel(fileOrder)
        idx = fileOrder(i);
        nodes(idx).lba = lba;
        lba = lba + ceil(nodes(idx).size / 2048);
    end

    totalSectors = lba;

    fprintf('Writing "%s" (%d sectors, %.2f MB) ...\n', ...
        isoFile, totalSectors, totalSectors*2048/1e6);

    fid = fopen(isoFile, 'wb');
    if fid == -1
        error('build_ISO_from_Folder:openFail', 'Could not create file: %s', isoFile);
    end
    cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

    % System area: 16 empty sectors
    fwrite(fid, zeros(16*2048,1,'uint8'), 'uint8');

    % Primary Volume Descriptor
    [~, volName] = fileparts(isoFile);
    pvd = buildPVD(nodes(rootIdx), totalSectors, pathTableSize, lbaLPath, lbaMPath, volName, opts, refMeta);
    fwrite(fid, pvd, 'uint8');

    % Volume Descriptor Set Terminator
    term = zeros(2048,1,'uint8');
    term(1) = 255;
    term(2:6) = uint8('CD001');
    term(7) = 1;
    fwrite(fid, term, 'uint8');

    % Path tables (Type-L then Type-M), each padded to full sectors
    Ltab = buildPathTable(nodes, dirOrder, rootIdx, 'L');
    Ltab(end+1:pathTableSectors*2048, 1) = 0;
    fwrite(fid, Ltab, 'uint8');

    Mtab = buildPathTable(nodes, dirOrder, rootIdx, 'M');
    Mtab(end+1:pathTableSectors*2048, 1) = 0;
    fwrite(fid, Mtab, 'uint8');

    % Directory extents, in LBA-assignment order
    for i = 1:numel(dirOrder)
        idx = dirOrder(i);
        if idx == rootIdx
            parentIdx = rootIdx;
        else
            parentIdx = nodes(idx).parentIdx;
        end
        buf = buildDirectoryExtentBytes(nodes, idx, parentIdx, opts, refMeta);
        buf(end+1:nodes(idx).dirSectors*2048, 1) = 0;
        fwrite(fid, buf, 'uint8');
    end

    % File data, in LBA-assignment order
    for i = 1:numel(fileOrder)
        idx = fileOrder(i);
        rfid = fopen(nodes(idx).diskPath, 'rb');
        data = fread(rfid, Inf, 'uint8=>uint8');
        fclose(rfid);
        sectors = max(1, ceil(numel(data) / 2048));
        padded = zeros(sectors*2048, 1, 'uint8');
        padded(1:numel(data)) = data;
        fwrite(fid, padded, 'uint8');
        fprintf('  [FILE] %s (%d bytes)\n', nodes(idx).diskPath, numel(data));
    end

    fprintf('Done. Wrote %d directories and %d files to %s\n', ...
        numel(dirOrder), numel(fileOrder), isoFile);
end

% ===================================================================
function opts = fillDefaultOpts(opts)
    if ~isfield(opts, 'SortMode') || isempty(opts.SortMode)
        opts.SortMode = 'alpha';
    end
    if ~isfield(opts, 'ReferenceBin')
        opts.ReferenceBin = '';
    end
    if ~isfield(opts, 'SystemId'),        opts.SystemId = ''; end
    if ~isfield(opts, 'VolumeId'),        opts.VolumeId = ''; end
    if ~isfield(opts, 'DataPreparerId'),  opts.DataPreparerId = ''; end
    if ~isfield(opts, 'ApplicationId'),   opts.ApplicationId = ''; end
    if ~isfield(opts, 'PublisherId'),     opts.PublisherId = ''; end
    if ~isfield(opts, 'VolumeSetId'),     opts.VolumeSetId = ''; end
    if ~isfield(opts, 'DefaultFileDate') || isempty(opts.DefaultFileDate)
        c = round(clock);
        opts.DefaultFileDate = c(1:6);
    end
    if ~isfield(opts, 'OmitVersion')
        opts.OmitVersion = []; % [] = auto-detect from ReferenceBin, else false
    end
end

% ===================================================================
function meta = harvestReferenceMetadata(refPath)
    [sectorSize, dataOffset] = detectLayout(refPath);

    fid = fopen(refPath, 'rb');
    if fid == -1
        error('build_ISO_from_Folder:refOpenFail', 'Could not open reference: %s', refPath);
    end
    cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

    pvd = readLogicalSector(fid, sectorSize, dataOffset, 16);

    meta = struct();
    meta.systemId       = char(pvd(9:40))';
    meta.volumeId        = char(pvd(41:72))';
    meta.volumeSetId     = char(pvd(191:318))';
    meta.publisherId     = char(pvd(319:446))';
    meta.dataPreparerId  = char(pvd(447:574))';
    meta.applicationId   = char(pvd(575:702))';
    meta.creationDate     = pvd(814:830);
    meta.modificationDate = pvd(831:847);
    meta.expirationDate   = pvd(848:864);
    meta.effectiveDate    = pvd(865:881);
    meta.rootDate         = pvd(175:181); % date embedded in the PVD's own root dir record

    % Root directory record -> walk it to harvest per-file dates
    rootRec = pvd(157:190);
    rootLba = le32(rootRec(3:6));
    rootLen = le32(rootRec(11:14));

    buf = readLogicalRange(fid, sectorSize, dataOffset, rootLba, rootLen);

    meta.fileDates = containers.Map('KeyType', 'char', 'ValueType', 'any');
    meta.fileExtra = containers.Map('KeyType', 'char', 'ValueType', 'any');
    meta.usesVersionSuffix = false;
    pos = 1;
    n = numel(buf);
    while pos <= n
        recLen = double(buf(pos));
        if recLen == 0
            nextBoundary = floor((pos-1)/2048)*2048 + 2048 + 1;
            if nextBoundary > n
                break;
            end
            pos = nextBoundary;
            continue;
        end
        rec = buf(pos:min(pos+recLen-1, n));
        idLen = double(rec(33));
        isDotEntry = (idLen == 1) && (double(rec(34)) == 0 || double(rec(34)) == 1);
        if ~isDotEntry && idLen > 0
            name = char(rec(34:33+idLen))';
            if any(name == ';')
                meta.usesVersionSuffix = true;
            end
            dateBytes = rec(19:25);
            meta.fileDates(name) = dateBytes;
            % Anything after the identifier (and its ISO9660 pad byte,
            % present only when idLen is even) is vendor-specific
            % System Use data (e.g. an old Mac mastering tool's Apple
            % ISO extension: HFS type/creator codes). Capture it
            % verbatim so it can be reproduced exactly on rebuild.
            extraStart = 34 + idLen;
            if mod(idLen, 2) == 0
                extraStart = extraStart + 1; % skip the pad byte
            end
            if extraStart <= numel(rec)
                extraBytes = rec(extraStart:end);
            else
                extraBytes = uint8([]);
            end
            meta.fileExtra(name) = extraBytes;
        end
        pos = pos + recLen;
    end

    % Also report total raw sector count, for build_Raw_Bin_from_Folder
    fseek(fid, 0, 'eof');
    fileSize = ftell(fid);
    meta.totalRawSectors = floor(fileSize / sectorSize);
    meta.sectorSize = sectorSize;
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
            mode = header(16);
            sectorSize = 2352;
            if mode == 2
                dataOffset = 24;
            else
                dataOffset = 16;
            end
        end
    end
end

% ===================================================================
function data = readLogicalSector(fid, sectorSize, dataOffset, lba)
    offset = double(lba) * sectorSize + dataOffset;
    fseek(fid, offset, 'bof');
    data = fread(fid, 2048, 'uint8=>uint8');
    if numel(data) < 2048
        data(end+1:2048) = 0;
    end
end

% ===================================================================
function data = readLogicalRange(fid, sectorSize, dataOffset, lba, numBytes)
    numSectors = ceil(numBytes / 2048);
    data = zeros(numSectors * 2048, 1, 'uint8');
    for s = 0:numSectors-1
        data(s*2048+1:s*2048+2048) = readLogicalSector(fid, sectorSize, dataOffset, lba+s);
    end
    data = data(1:numBytes);
end

% ===================================================================
function val = le32(bytes)
    b = double(bytes);
    val = b(1) + b(2)*256 + b(3)*65536 + b(4)*16777216;
end

% ===================================================================
function [nodes, idx] = scanFolderFlat(nodes, parentIdx, diskPath, name, isDir, sortMode, omitVersion)
    node = struct('name', name, 'diskPath', diskPath, 'isDir', isDir, ...
        'isoName', '', 'size', 0, 'childIdx', [], 'parentIdx', parentIdx, ...
        'dirSectors', 0, 'lba', 0, 'dirNumber', 0, 'parentNumber', 0);
    nodes(end+1) = node;
    idx = numel(nodes);

    if ~isDir
        info = dir(diskPath);
        nodes(idx).size = info(1).bytes;
        return;
    end

    d = dir(diskPath);
    names = {d.name};
    keep = ~ismember(names, {'.','..'}) & ~strncmp(names, '.', 1);
    d = d(keep);

    tempChildIdx = [];
    for k = 1:numel(d)
        childPath = fullfile(diskPath, d(k).name);
        [nodes, cIdx] = scanFolderFlat(nodes, idx, childPath, d(k).name, d(k).isdir, sortMode, omitVersion);
        if nodes(cIdx).isDir
            nodes(cIdx).isoName = sanitizeName(nodes(cIdx).name, false, omitVersion);
        else
            nodes(cIdx).isoName = sanitizeName(nodes(cIdx).name, true, omitVersion);
        end
        tempChildIdx(end+1) = cIdx; %#ok<AGROW>
    end

    tempChildIdx = sortChildren(nodes, tempChildIdx, sortMode);
    nodes(idx).childIdx = tempChildIdx;
end

% ===================================================================
function childIdx = sortChildren(nodes, childIdx, sortMode)
    if isempty(childIdx)
        return;
    end
    switch sortMode
        case 'type'
            exts = cell(1, numel(childIdx));
            bases = cell(1, numel(childIdx));
            for i = 1:numel(childIdx)
                n = nodes(childIdx(i)).isoName;
                dotPos = find(n == '.', 1, 'last');
                if isempty(dotPos)
                    exts{i} = '';
                    bases{i} = n;
                else
                    exts{i} = n(dotPos+1:end);
                    bases{i} = n(1:dotPos-1);
                end
            end
            keys = strcat(exts, {'|'}, bases);
            [~, order] = sort(keys);
            childIdx = childIdx(order);
        case 'size_asc'
            sizes = arrayfun(@(i) sizeOfNode(nodes(i)), childIdx);
            [~, order] = sort(sizes, 'ascend');
            childIdx = childIdx(order);
        case 'size_desc'
            sizes = arrayfun(@(i) sizeOfNode(nodes(i)), childIdx);
            [~, order] = sort(sizes, 'descend');
            childIdx = childIdx(order);
        case 'none'
            % keep as-is (OS listing order)
        otherwise % 'alpha'
            isoNames = {nodes(childIdx).isoName};
            [~, order] = sort(isoNames);
            childIdx = childIdx(order);
    end
end

% ===================================================================
function s = sizeOfNode(node)
    if node.isDir
        s = 0;
    else
        s = node.size;
    end
end

% ===================================================================
function name = sanitizeName(rawName, isFile, omitVersion)
    base = regexprep(upper(rawName), '[^A-Z0-9_.]', '_');
    if isempty(base)
        base = '_';
    end
    maxBase = 60;
    if numel(base) > maxBase
        base = base(1:maxBase);
    end
    if isFile
        if isempty(strfind(base, '.')) %#ok<STREMP>
            base = [base '.'];
        end
        if omitVersion
            name = base;
        else
            name = [base ';1'];
        end
    else
        name = base;
    end
end

% ===================================================================
function key = baseKey(isoName)
    % Strips a trailing ";N" version suffix, if present, so lookups
    % against a reference (which may or may not use version suffixes)
    % work regardless of this build's own OmitVersion setting.
    semiIdx = strfind(isoName, ';');
    if isempty(semiIdx)
        key = isoName;
    else
        key = isoName(1:semiIdx(1)-1);
    end
end

% ===================================================================
function extraBytes = lookupExtra(isoName, refMeta)
    extraBytes = uint8([]);
    if ~isempty(refMeta) && isKey(refMeta.fileExtra, baseKey(isoName))
        extraBytes = refMeta.fileExtra(baseKey(isoName));
    end
end

% ===================================================================
function sectors = layoutSectorCountFromRecLens(recLens)
    sectorRemain = 2048;
    sector = 0;
    for i = 1:numel(recLens)
        recLen = recLens(i);
        if recLen > sectorRemain
            sector = sector + 1;
            sectorRemain = 2048;
        end
        sectorRemain = sectorRemain - recLen;
    end
    sectors = sector + 1;
end

% ===================================================================
function len = recordLength(idLen)
    len = 33 + idLen;
    if mod(idLen, 2) == 0
        len = len + 1;
    end
end

% ===================================================================
function len = recordLengthWithExtra(idLen, extraLen)
    len = recordLength(idLen) + extraLen;
end

% ===================================================================
function len = pathTableEntryLen(node, isRoot)
    if isRoot
        idLen = 1;
    else
        idLen = numel(node.isoName);
    end
    len = 8 + idLen;
    if mod(idLen, 2) == 1
        len = len + 1;
    end
end

% ===================================================================
function entries = generateDirEntries(nodes, idx, parentIdx)
    node = nodes(idx);
    parentNode = nodes(parentIdx);
    entries = {};
    entries{1} = struct('idBytes', uint8(0), 'isDir', true, 'isoName', '.', ...
        'lba', node.lba, 'dataLen', node.dirSectors*2048);
    entries{2} = struct('idBytes', uint8(1), 'isDir', true, 'isoName', '..', ...
        'lba', parentNode.lba, 'dataLen', parentNode.dirSectors*2048);
    for c = node.childIdx
        cn = nodes(c);
        if cn.isDir
            dataLen = cn.dirSectors * 2048;
        else
            dataLen = cn.size;
        end
        entries{end+1} = struct('idBytes', uint8(cn.isoName), 'isDir', cn.isDir, ...
            'isoName', cn.isoName, 'lba', cn.lba, 'dataLen', dataLen); %#ok<AGROW>
    end
end

% ===================================================================
function buf = buildDirectoryExtentBytes(nodes, idx, parentIdx, opts, refMeta)
    node = nodes(idx);
    entries = generateDirEntries(nodes, idx, parentIdx);
    buf = zeros(node.dirSectors*2048, 1, 'uint8');
    sectorRemain = 2048;
    sector = 0;
    for i = 1:numel(entries)
        e = entries{i};
        idLen = numel(e.idBytes);
        % '.' and '..' never carry extension bytes (matches observed
        % reference discs); real entries may.
        if strcmp(e.isoName, '.') || strcmp(e.isoName, '..')
            extraBytes = uint8([]);
        else
            extraBytes = lookupExtra(e.isoName, refMeta);
        end
        recLen = recordLengthWithExtra(idLen, numel(extraBytes));
        if recLen > sectorRemain
            sector = sector + 1;
            sectorRemain = 2048;
        end
        offset = sector*2048 + (2048 - sectorRemain); % 0-based
        dateBytes = lookupDate(e.isoName, opts, refMeta);
        rec = buildDirRecordBytes(e.idBytes, e.lba, e.dataLen, e.isDir, dateBytes, extraBytes);
        buf(offset+1:offset+recLen) = rec;
        sectorRemain = sectorRemain - recLen;
    end
end

% ===================================================================
function dateBytes = lookupDate(isoName, opts, refMeta)
    dateBytes = [];
    if (strcmp(isoName, '.') || strcmp(isoName, '..')) && ~isempty(refMeta) && isfield(refMeta, 'rootDate')
        dateBytes = refMeta.rootDate;
    elseif ~isempty(refMeta) && isKey(refMeta.fileDates, baseKey(isoName))
        dateBytes = refMeta.fileDates(baseKey(isoName));
    else
        c = opts.DefaultFileDate;
        dateBytes = uint8([max(0,c(1)-1900), c(2), c(3), 0, 0, 0, 0]);
    end
end

% ===================================================================
function rec = buildDirRecordBytes(idBytes, lba, dataLen, isDir, dateBytes, extraBytes)
    if nargin < 6
        extraBytes = uint8([]);
    end
    idLen = numel(idBytes);
    recLen = recordLengthWithExtra(idLen, numel(extraBytes));
    rec = zeros(recLen, 1, 'uint8');
    rec(1) = recLen;
    rec(2) = 0;
    rec(3:10) = bothEndian32(lba);
    rec(11:18) = bothEndian32(dataLen);
    rec(19:25) = dateBytes(:);
    flags = 0;
    if isDir
        flags = bitor(flags, 2);
    end
    rec(26) = flags;
    rec(27) = 0;
    rec(28) = 0;
    rec(29:32) = bothEndian16(1);
    rec(33) = idLen;
    rec(34:33+idLen) = idBytes(:);
    tail = 34 + idLen;
    if mod(idLen, 2) == 0
        rec(tail) = 0; % ISO9660 pad byte
        tail = tail + 1;
    end
    if ~isempty(extraBytes)
        rec(tail:tail+numel(extraBytes)-1) = extraBytes(:);
    end
end

% ===================================================================
function bytes = buildPathTable(nodes, dirOrder, rootIdx, tableType)
    parts = {};
    for i = 1:numel(dirOrder)
        idx = dirOrder(i);
        node = nodes(idx);
        isRoot = (idx == rootIdx);
        if isRoot
            idBytes = uint8(0);
        else
            idBytes = uint8(node.isoName);
        end
        idLen = numel(idBytes);
        entryLen = pathTableEntryLen(node, isRoot);
        rec = zeros(entryLen, 1, 'uint8');
        rec(1) = idLen;
        rec(2) = 0;
        if tableType == 'L'
            rec(3:6) = le32enc(node.lba);
            rec(7:8) = le16(node.parentNumber);
        else
            rec(3:6) = be32(node.lba);
            rec(7:8) = be16(node.parentNumber);
        end
        rec(9:8+idLen) = idBytes(:);
        parts{end+1} = rec; %#ok<AGROW>
    end
    if isempty(parts)
        bytes = zeros(0,1,'uint8');
    else
        bytes = vertcat(parts{:});
    end
end

% ===================================================================
function pvd = buildPVD(rootNode, totalSectors, pathTableSize, lbaL, lbaM, volName, opts, refMeta)
    dateBytes = lookupDate('.', opts, refMeta); % root's own date, best-effort
    rootRec = buildDirRecordBytes(uint8(0), rootNode.lba, rootNode.dirSectors*2048, true, dateBytes);
    rootRec34 = zeros(34,1,'uint8');
    rootRec34(1:numel(rootRec)) = rootRec;

    systemId       = resolveField(opts.SystemId,       refMeta, 'systemId',       'MATLAB');
    volumeId        = resolveField(opts.VolumeId,        refMeta, 'volumeId',        volName);
    volumeSetId      = resolveField(opts.VolumeSetId,     refMeta, 'volumeSetId',     '');
    publisherId      = resolveField(opts.PublisherId,     refMeta, 'publisherId',     '');
    dataPreparerId   = resolveField(opts.DataPreparerId,  refMeta, 'dataPreparerId',  '');
    applicationId    = resolveField(opts.ApplicationId,   refMeta, 'applicationId',   'MATLAB ISO BUILDER');

    if ~isempty(refMeta)
        creationBytes     = refMeta.creationDate;
        modificationBytes = refMeta.modificationDate;
        expirationBytes   = refMeta.expirationDate;
        effectiveBytes    = refMeta.effectiveDate;
    else
        creationBytes     = isoDateTimeUnset();
        modificationBytes = isoDateTimeUnset();
        expirationBytes   = isoDateTimeUnset();
        effectiveBytes    = isoDateTimeUnset();
    end

    pieces = {};
    pieces{end+1} = uint8(1);                            % type
    pieces{end+1} = reshape(uint8('CD001'), [], 1);        % std id
    pieces{end+1} = uint8(1);                             % version
    pieces{end+1} = uint8(0);                             % unused
    pieces{end+1} = padTo(systemId, 32, 32);                % system id
    pieces{end+1} = padTo(volumeId, 32, 32);                % volume id
    pieces{end+1} = zeros(8,1,'uint8');                    % unused
    pieces{end+1} = bothEndian32(totalSectors);            % volume space size
    pieces{end+1} = zeros(32,1,'uint8');                   % unused
    pieces{end+1} = bothEndian16(1);                       % volume set size
    pieces{end+1} = bothEndian16(1);                       % volume seq number
    pieces{end+1} = bothEndian16(2048);                    % logical block size
    pieces{end+1} = bothEndian32(pathTableSize);           % path table size
    pieces{end+1} = le32enc(lbaL);                         % L path table LBA
    pieces{end+1} = le32enc(0);                            % optional L
    pieces{end+1} = be32(lbaM);                            % M path table LBA
    pieces{end+1} = be32(0);                               % optional M
    pieces{end+1} = rootRec34;                             % root dir record
    pieces{end+1} = padTo(volumeSetId, 128, 32);           % volume set id
    pieces{end+1} = padTo(publisherId, 128, 32);           % publisher id
    pieces{end+1} = padTo(dataPreparerId, 128, 32);        % data preparer id
    pieces{end+1} = padTo(applicationId, 128, 32);         % application id
    pieces{end+1} = padTo('', 38, 32);                     % copyright file id
    pieces{end+1} = padTo('', 36, 32);                     % abstract file id
    pieces{end+1} = padTo('', 37, 32);                     % bibliographic file id
    pieces{end+1} = creationBytes(:);                      % creation
    pieces{end+1} = modificationBytes(:);                  % modification
    pieces{end+1} = expirationBytes(:);                    % expiration
    pieces{end+1} = effectiveBytes(:);                     % effective
    pieces{end+1} = uint8(1);                              % file structure version
    pieces{end+1} = uint8(0);                              % reserved
    pieces{end+1} = zeros(512,1,'uint8');                  % application used

    allBytes = vertcat(pieces{:});
    pvd = zeros(2048,1,'uint8');
    pvd(1:numel(allBytes)) = allBytes;
end

% ===================================================================
function val = resolveField(explicitVal, refMeta, refField, defaultVal)
    if ~isempty(explicitVal)
        val = explicitVal;
    elseif ~isempty(refMeta) && isfield(refMeta, refField)
        val = strtrim(refMeta.(refField));
    else
        val = defaultVal;
    end
end

% ===================================================================
function out = padTo(str, len, padVal)
    s = upper(str);
    out = repmat(uint8(padVal), len, 1);
    n = min(numel(s), len);
    if n > 0
        out(1:n) = uint8(s(1:n));
    end
end

% ===================================================================
function b = isoDateTimeUnset()
    b = uint8([double('0')*ones(1,16), 0]);
    b = b(:);
end

% ===================================================================
function b = le16(v)
    v = double(v);
    b = uint8([mod(v,256), floor(v/256)]);
    b = b(:);
end

function b = be16(v)
    v = double(v);
    b = uint8([floor(v/256), mod(v,256)]);
    b = b(:);
end

function b = le32enc(v)
    v = double(v);
    b = uint8([mod(v,256), mod(floor(v/256),256), mod(floor(v/65536),256), floor(v/16777216)]);
    b = b(:);
end

function b = be32(v)
    b = flipud(le32enc(v));
end

function b = bothEndian16(v)
    b = [le16(v); be16(v)];
end

function b = bothEndian32(v)
    b = [le32enc(v); be32(v)];
end
