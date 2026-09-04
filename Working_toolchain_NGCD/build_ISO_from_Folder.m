function build_ISO_from_Folder(inputDir, isoFile)
%BUILDISOFROMFOLDER Build a plain ISO9660 image from a folder of files.
%   This is the inverse operation of extractISOFromBin: it walks a
%   folder (including subfolders), packs everything it finds into a
%   standard ISO9660 filesystem, and writes it out as a 2048
%   byte/sector .iso image.
%
%   buildISOFromFolder(inputDir, isoFile)
%
%   inputDir - folder containing the files/folders to pack (e.g. the
%              output of extractISOFromBin).
%   isoFile  - path of the .iso file to create.
%
%   Example:
%       buildISOFromFolder('extracted_files', 'rebuilt.iso')
%
%   NOTE: This produces a plain 2048-byte/sector ISO9660 image (data
%   track only), not a raw 2352-byte/sector .bin/.cue pair. Most
%   emulators, disc utilities and CD burning tools can convert a
%   plain .iso to .bin/.cue if a raw image is specifically needed.
%   Filenames are automatically uppercased and restricted to the
%   ISO9660 character set (A-Z 0-9 _ .); anything else is replaced
%   with an underscore.

    if nargin < 2
        error('buildISOFromFolder:nargin', ...
            'Usage: buildISOFromFolder(inputDir, isoFile)');
    end
    if ~isfolder(inputDir)
        error('buildISOFromFolder:noDir', 'Input folder not found: %s', inputDir);
    end

    fprintf('Scanning "%s" ...\n', inputDir);
    emptyNodes = struct('name',{},'diskPath',{},'isDir',{},'isoName',{}, ...
        'size',{},'childIdx',{},'parentIdx',{}, ...
        'dirSectors',{},'lba',{},'dirNumber',{},'parentNumber',{});
    [nodes, rootIdx] = scanFolderFlat(emptyNodes, 0, inputDir, '', true);

    fprintf('Computing directory layouts ...\n');
    for i = 1:numel(nodes)
        if nodes(i).isDir
            idLens = [1, 1]; % '.' and '..'
            for c = nodes(i).childIdx
                idLens(end+1) = numel(nodes(c).isoName); %#ok<AGROW>
            end
            nodes(i).dirSectors = layoutSectorCount(idLens);
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
        error('buildISOFromFolder:openFail', 'Could not create file: %s', isoFile);
    end
    cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

    % System area: 16 empty sectors
    fwrite(fid, zeros(16*2048,1,'uint8'), 'uint8');

    % Primary Volume Descriptor
    [~, volName] = fileparts(isoFile);
    pvd = buildPVD(nodes(rootIdx), totalSectors, pathTableSize, lbaLPath, lbaMPath, volName);
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
        buf = buildDirectoryExtentBytes(nodes, idx, parentIdx);
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
function [nodes, idx] = scanFolderFlat(nodes, parentIdx, diskPath, name, isDir)
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
        [nodes, cIdx] = scanFolderFlat(nodes, idx, childPath, d(k).name, d(k).isdir);
        if nodes(cIdx).isDir
            nodes(cIdx).isoName = sanitizeName(nodes(cIdx).name, false);
        else
            nodes(cIdx).isoName = sanitizeName(nodes(cIdx).name, true);
        end
        tempChildIdx(end+1) = cIdx; %#ok<AGROW>
    end

    if ~isempty(tempChildIdx)
        isoNames = {nodes(tempChildIdx).isoName};
        [~, order] = sort(isoNames);
        tempChildIdx = tempChildIdx(order);
    end
    nodes(idx).childIdx = tempChildIdx;
end

% ===================================================================
function name = sanitizeName(rawName, isFile)
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
        name = [base ';1'];
    else
        name = base;
    end
end

% ===================================================================
function sectors = layoutSectorCount(idLens)
    sectorRemain = 2048;
    sector = 0;
    for i = 1:numel(idLens)
        recLen = recordLength(idLens(i));
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
    entries{1} = struct('idBytes', uint8(0), 'isDir', true, ...
        'lba', node.lba, 'dataLen', node.dirSectors*2048);
    entries{2} = struct('idBytes', uint8(1), 'isDir', true, ...
        'lba', parentNode.lba, 'dataLen', parentNode.dirSectors*2048);
    for c = node.childIdx
        cn = nodes(c);
        if cn.isDir
            dataLen = cn.dirSectors * 2048;
        else
            dataLen = cn.size;
        end
        entries{end+1} = struct('idBytes', uint8(cn.isoName), 'isDir', cn.isDir, ...
            'lba', cn.lba, 'dataLen', dataLen); %#ok<AGROW>
    end
end

% ===================================================================
function buf = buildDirectoryExtentBytes(nodes, idx, parentIdx)
    node = nodes(idx);
    entries = generateDirEntries(nodes, idx, parentIdx);
    buf = zeros(node.dirSectors*2048, 1, 'uint8');
    sectorRemain = 2048;
    sector = 0;
    for i = 1:numel(entries)
        e = entries{i};
        idLen = numel(e.idBytes);
        recLen = recordLength(idLen);
        if recLen > sectorRemain
            sector = sector + 1;
            sectorRemain = 2048;
        end
        offset = sector*2048 + (2048 - sectorRemain); % 0-based
        rec = buildDirRecordBytes(e.idBytes, e.lba, e.dataLen, e.isDir);
        buf(offset+1:offset+recLen) = rec;
        sectorRemain = sectorRemain - recLen;
    end
end

% ===================================================================
function rec = buildDirRecordBytes(idBytes, lba, dataLen, isDir)
    idLen = numel(idBytes);
    recLen = recordLength(idLen);
    rec = zeros(recLen, 1, 'uint8');
    rec(1) = recLen;
    rec(2) = 0;
    rec(3:10) = bothEndian32(lba);
    rec(11:18) = bothEndian32(dataLen);
    rec(19:25) = nowDirDateTime();
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
            rec(3:6) = le32(node.lba);
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
function pvd = buildPVD(rootNode, totalSectors, pathTableSize, lbaL, lbaM, volName)
    rootRec = buildDirRecordBytes(uint8(0), rootNode.lba, rootNode.dirSectors*2048, true);
    rootRec34 = zeros(34,1,'uint8');
    rootRec34(1:numel(rootRec)) = rootRec;

    pieces = {};
    pieces{end+1} = uint8(1);                            % type
    pieces{end+1} = reshape(uint8('CD001'), [], 1);        % std id
    pieces{end+1} = uint8(1);                             % version
    pieces{end+1} = uint8(0);                             % unused
    pieces{end+1} = padTo('MATLAB', 32, 32);               % system id
    pieces{end+1} = padTo(volName, 32, 32);                % volume id
    pieces{end+1} = zeros(8,1,'uint8');                    % unused
    pieces{end+1} = bothEndian32(totalSectors);            % volume space size
    pieces{end+1} = zeros(32,1,'uint8');                   % unused
    pieces{end+1} = bothEndian16(1);                       % volume set size
    pieces{end+1} = bothEndian16(1);                       % volume seq number
    pieces{end+1} = bothEndian16(2048);                    % logical block size
    pieces{end+1} = bothEndian32(pathTableSize);           % path table size
    pieces{end+1} = le32(lbaL);                            % L path table LBA
    pieces{end+1} = le32(0);                               % optional L
    pieces{end+1} = be32(lbaM);                            % M path table LBA
    pieces{end+1} = be32(0);                               % optional M
    pieces{end+1} = rootRec34;                             % root dir record
    pieces{end+1} = padTo('', 128, 32);                    % volume set id
    pieces{end+1} = padTo('', 128, 32);                    % publisher id
    pieces{end+1} = padTo('', 128, 32);                    % data preparer id
    pieces{end+1} = padTo('MATLAB ISO BUILDER', 128, 32);  % application id
    pieces{end+1} = padTo('', 38, 32);                     % copyright file id
    pieces{end+1} = padTo('', 36, 32);                     % abstract file id
    pieces{end+1} = padTo('', 37, 32);                     % bibliographic file id
    pieces{end+1} = isoDateTimeUnset();                    % creation
    pieces{end+1} = isoDateTimeUnset();                    % modification
    pieces{end+1} = isoDateTimeUnset();                    % expiration
    pieces{end+1} = isoDateTimeUnset();                    % effective
    pieces{end+1} = uint8(1);                              % file structure version
    pieces{end+1} = uint8(0);                              % reserved
    pieces{end+1} = zeros(512,1,'uint8');                  % application used

    allBytes = vertcat(pieces{:});
    pvd = zeros(2048,1,'uint8');
    pvd(1:numel(allBytes)) = allBytes;
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
function dt = nowDirDateTime()
    c = round(clock);
    dt = uint8([max(0,c(1)-1900), c(2), c(3), c(4), c(5), c(6), 0]);
    dt = dt(:);
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

function b = le32(v)
    v = double(v);
    b = uint8([mod(v,256), mod(floor(v/256),256), mod(floor(v/65536),256), floor(v/16777216)]);
    b = b(:);
end

function b = be32(v)
    b = flipud(le32(v));
end

function b = bothEndian16(v)
    b = [le16(v); be16(v)];
end

function b = bothEndian32(v)
    b = [le32(v); be32(v)];
end
