function outPath = neosdconv_convert(srcDir, outPath, opts)
%NEOSDCONV_CONVERT Convert a folder of Neo Geo ROMs (MAME/raw format) to .neo
%
%   outPath = NEOSDCONV_CONVERT(srcDir, outPath, opts)
%
%   Faithfully reproduces, byte for byte, the open source tool
%   city41/neosdconv (src/buildNeoFile.ts + src/convertRom.ts, MIT license,
%   https://github.com/city41/neosdconv). The .neo format (TerraOnion NeoSD)
%   is a single container for the chips of a Neo Geo cartridge: a
%   4096-byte header followed by the concatenated P + S + M + V + C data.
%
%   INPUTS
%     srcDir  : folder containing the raw ROM files for A SINGLE game
%               (e.g. the extracted contents of a MAME .zip: "040-p1.p1",
%               "040-s1.s1", "040-m1.m1", "040-v1.v1", "040-v2.v2",
%               "040-c1.c1" ... "040-c4.c4"). Any .zip or .html files
%               present in the folder are ignored (like neosdconv). File
%               names are used to guess the role of each chip (P/S/M/V/C):
%               the standard MAME convention "<text>-<type><n>.<type><n>"
%               (e.g. "040-c1.c1") or "<text><type><n>.rom/.bin" is required.
%     outPath : path of the .neo file to write
%     opts    : struct with the fields
%       .name         (required) game name, <= 33 ASCII characters
%       .year         (required) release year
%       .genre        (required) one of: Other, Action, BeatEmUp,
%                     Sports, Driving, Platformer, Mahjong, Shooter,
%                     Quiz, Fighting, Puzzle  (TerraOnion/genres.ts list)
%       .manufacturer (optional, default 'SNK'), <= 17 ASCII characters
%       .ngh          (optional) NGH number as a HEXADECIMAL string
%                     (e.g. '40' for NGH-040), default '0'
%       .screenshot   (optional) NeoSD screenshot index, default 0
%
%   OUTPUT
%     outPath : the path written to (same as the input, handy for chaining)
%
%   GENERICITY: this function does NOT hard-code any particular game. It
%   detects the role of each file from its NAME, exactly like neosdconv.
%   It therefore works as-is on any hack following the same naming
%   convention (same p/s/m/v/c roles), even if the ROM sizes differ from
%   the original (enlarged P ROM, enlarged C ROM, etc.): everything is
%   recomputed dynamically from the files present in srcDir.
%
%   Example:
%       opts = struct('name','Sengoku 2', 'year',1993, ...
%                      'genre','BeatEmUp', 'manufacturer','SNK', 'ngh','40');
%       neosdconv_convert('roms/sengoku2', 'out/sengoku2.neo', opts);
%
%   See also: NEOSDCONV_DUMP_HEADER

    if nargin < 3
        error('neosdconv_convert:args', 'srcDir, outPath and opts are required');
    end

    opts = fillDefaultOpts(opts);
    validateOpts(opts);

    files = loadFilesIntoMemory(srcDir);

    SIXTY_FOUR_KB    = 64*1024;
    TWO_FIFTY_SIX_KB = 256*1024;

    % ---- Build the data blocks ------------------------------------------
    % (same order and logic as buildNeoFile.ts)
    [v1Size, v2Size] = getVSizes(files);

    cData = padToNearest(getCData(files), TWO_FIFTY_SIX_KB);
    pData = padToNearest(getPData(files), SIXTY_FOUR_KB);
    sData = padToNearest(getData(files, 's', false), SIXTY_FOUR_KB);
    mData = padToNearest(getData(files, 'm', false), SIXTY_FOUR_KB);
    vData = getVData(files);   % already padded internally (v1 then v2)

    % ---- Header (4096 bytes) ---------------------------------------------
    tag = [uint8('NEO'), uint8(1)];   % "NEO" + version byte = 1

    sizes = [u32le(numel(pData)), u32le(numel(sData)), u32le(numel(mData)), ...
             u32le(v1Size),       u32le(v2Size),       u32le(numel(cData))];

    metadata = [u32le(opts.year), u32le(genreCode(opts.genre)), ...
                u32le(opts.screenshot), u32le(parseNGH(opts.ngh))];

    nameField         = asciiField(opts.name, 33);
    manufacturerField = asciiField(opts.manufacturer, 17);

    fillerLength = 128 + 290 + 4096 - 512;   % = 4002, as in buildNeoFile.ts
    filler = zeros(1, fillerLength, 'uint8');

    header = [tag, sizes, metadata, nameField, manufacturerField, filler];

    if numel(header) ~= 4096
        error('neosdconv_convert:header', ...
            'Unexpected header size: %d bytes (expected 4096)', numel(header));
    end

    neoFile = [header, pData, sData, mData, vData, cData];

    % ---- Write to disk -----------------------------------------------------
    fid = fopen(outPath, 'wb');
    if fid == -1
        error('neosdconv_convert:io', 'Unable to write "%s"', outPath);
    end
    cleanupObj = onCleanup(@() fclose(fid));
    fwrite(fid, neoFile, 'uint8');
end

% =======================================================================
% Local functions -- direct port of buildNeoFile.ts / convertRom.ts
% =======================================================================

function opts = fillDefaultOpts(opts)
    if ~isfield(opts, 'manufacturer') || isempty(opts.manufacturer)
        opts.manufacturer = 'SNK';
    end
    if ~isfield(opts, 'ngh') || isempty(opts.ngh)
        opts.ngh = '0';
    end
    if ~isfield(opts, 'screenshot') || isempty(opts.screenshot)
        opts.screenshot = 0;
    end
end

function validateOpts(opts)
    req = {'name', 'year', 'genre'};
    for i = 1:numel(req)
        if ~isfield(opts, req{i}) || isempty(opts.(req{i}))
            error('neosdconv_convert:opts', 'opts.%s is required', req{i});
        end
    end
    if numel(opts.name) > 33
        error('neosdconv_convert:opts', 'name ("%s") exceeds 33 characters', opts.name);
    end
    if numel(opts.manufacturer) > 17
        error('neosdconv_convert:opts', 'manufacturer ("%s") exceeds 17 characters', opts.manufacturer);
    end
end

function files = loadFilesIntoMemory(srcDir)
% Loads every file in the folder (skipping subfolders, .zip, .html) into
% a containers.Map name -> row uint8 vector. Equivalent to
% loadFilesIntoMemory() in convertRom.ts.
    if ~isfolder(srcDir)
        error('neosdconv_convert:io', 'Folder not found: "%s"', srcDir);
    end
    files = containers.Map('KeyType', 'char', 'ValueType', 'any');
    entries = dir(srcDir);
    for i = 1:numel(entries)
        e = entries(i);
        if e.isdir
            continue;
        end
        lname = lower(strtrim(e.name));
        if endsWith(lname, '.html') || endsWith(lname, '.zip')
            continue;
        end
        fid = fopen(fullfile(e.folder, e.name), 'rb');
        if fid == -1
            error('neosdconv_convert:io', 'Unable to read "%s"', e.name);
        end
        data = fread(fid, Inf, '*uint8')';
        fclose(fid);
        files(e.name) = data;
    end
    if files.Count == 0
        error('neosdconv_convert:empty', 'No ROM files found in "%s"', srcDir);
    end
end

function tf = isFileOfType(fileName, fileType, numberIncluded)
% Reproduces isFileOfType(): recognized formats
%   1) <text>-<type><n>.<type><n>   e.g. "040-c1.c1"
%   2) <text>-<type><n>.rom | .bin  e.g. "kof94_p1.rom"
    if nargin < 3
        numberIncluded = false;
    end
    lowerName = lower(fileName);
    if numberIncluded
        numberRegex = '.?';
    else
        numberRegex = '\d.?';
    end
    pat1 = [fileType numberRegex '\.(rom|bin)$'];
    pat2 = [fileType numberRegex '\.' fileType numberRegex '$'];
    tf = ~isempty(regexp(lowerName, pat1, 'once')) || ...
         ~isempty(regexp(lowerName, pat2, 'once'));
end

function sz = getSize(files, fileType)
    sz = 0;
    ks = keys(files);
    for i = 1:numel(ks)
        if isFileOfType(ks{i}, fileType, false)
            sz = sz + numel(files(ks{i}));
        end
    end
end

function data = getData(files, fileType, numberIncluded)
% Concatenates, in alphabetical (case-insensitive) order of file names,
% the data of every file matching fileType.
    if nargin < 3
        numberIncluded = false;
    end
    ks = keys(files);
    [~, order] = sort(lower(ks));
    ks = ks(order);
    data = uint8([]);
    for i = 1:numel(ks)
        if isFileOfType(ks{i}, fileType, numberIncluded)
            d = files(ks{i});
            data = [data, d(:)'];
        end
    end
end

function [v1Size, v2Size] = getVSizes(files)
% V ROMs come in two flavors: a true v1/v2 combo (separate ADPCM-A /
% ADPCM-B hardware regions, rare -- e.g. League Bowling), or several
% chips v1,v2,v3... that ALL belong to the same ADPCM-A region (the
% most common case, and the one used by Sengoku 2).
    SIXTY_FOUR_KB = 64*1024;
    v2Raw = getSize(files, 'v2');
    if v2Raw > 0
        v1Raw = getSize(files, 'v1');
        v1Size = roundUpToNearest(v1Raw, SIXTY_FOUR_KB);
        v2Size = roundUpToNearest(v2Raw, SIXTY_FOUR_KB);
    else
        v1Size = roundUpToNearest(getSize(files, 'v'), SIXTY_FOUR_KB);
        v2Size = 0;
    end
end

function data = getVData(files)
    SIXTY_FOUR_KB = 64*1024;
    v1Data = getData(files, 'v1', false);
    v2Data = getData(files, 'v2', false);
    if isempty(v1Data)
        v1Data = getData(files, 'v', false);
    end
    v1Data = padToNearest(v1Data, SIXTY_FOUR_KB);
    v2Data = padToNearest(v2Data, SIXTY_FOUR_KB);
    data = [v1Data, v2Data];
end

function out = interleaveBytes(twoBankArray, leafSize)
% Interleaves the two halves of an array, "leafSize" bytes at a time.
    n = numel(twoBankArray);
    half = n / 2;
    out = zeros(1, n, 'uint8');
    ilbi = 0;
    for i = 0:leafSize:(half-1)
        for f = 0:(leafSize-1)
            out(ilbi + f + 1)            = twoBankArray(i + f + 1);
            out(ilbi + leafSize + f + 1) = twoBankArray(i + half + f + 1);
        end
        ilbi = ilbi + leafSize*2;
    end
end

function data = getCData(files)
% C ROM pairs (c1/c2, c3/c4, c5/c6, c7/c8) are interleaved byte by
% byte -- this is what the Neo Geo bus actually sees.
    data = uint8([]);
    idx = 1;
    oddData  = getData(files, sprintf('c%d', idx),   true);
    evenData = getData(files, sprintf('c%d', idx+1), true);
    while ~isempty(oddData)
        pairData    = [oddData, evenData];
        interleaved = interleaveBytes(pairData, 1);
        data = [data, interleaved]; %#ok<AGROW>
        idx = idx + 2;
        oddData  = getData(files, sprintf('c%d', idx),   true);
        evenData = getData(files, sprintf('c%d', idx+1), true);
    end
end

function out = swapMegs(data)
% 2MB P ROMs are bank-switched on the Neo Geo (the 68k only addresses
% 1MB at a time): the second meg must be written first in the .neo
% (see TerraOnion forums, referenced in buildNeoFile.ts).
    ONE_MEG  = 1024*1024;
    TWO_MEGS = 2*ONE_MEG;
    if numel(data) ~= TWO_MEGS
        error('neosdconv_convert:swapMegs', ...
            'expected exactly 2MB, got %d bytes', numel(data));
    end
    out = [data(ONE_MEG+1:TWO_MEGS), data(1:ONE_MEG)];
end

function data = getPData(files)
    TWO_MEGS = 2*1024*1024;
    data = getData(files, 'p', false);
    if numel(data) == TWO_MEGS
        data = swapMegs(data);
    end
end

function v = roundUpToNearest(value, multiple)
    amountToAdd = multiple - mod(value, multiple);
    if amountToAdd == multiple
        v = value;
    else
        v = value + amountToAdd;
    end
end

function out = padToNearest(data, byteMultiple)
% Pads with 0xFF (blank EPROM/flash convention), like neosdconv.
    amountToPad = byteMultiple - mod(numel(data), byteMultiple);
    if amountToPad == byteMultiple
        out = data;
    else
        out = [data, repmat(uint8(255), 1, amountToPad)];
    end
end

function b = u32le(x)
% Encodes x as a little-endian uint32 (4 bytes), independent of the
% host machine's endianness.
    x = uint32(x);
    b = uint8([bitand(x, 255), ...
               bitand(bitshift(x, -8),  255), ...
               bitand(bitshift(x, -16), 255), ...
               bitand(bitshift(x, -24), 255)]);
end

function out = asciiField(str, fieldLen)
    if numel(str) > fieldLen
        error('neosdconv_convert:field', '"%s" exceeds %d characters', str, fieldLen);
    end
    out = zeros(1, fieldLen, 'uint8');
    if ~isempty(str)
        out(1:numel(str)) = uint8(str);
    end
end

function code = genreCode(name)
    names = {'Other','Action','BeatEmUp','Sports','Driving','Platformer', ...
             'Mahjong','Shooter','Quiz','Fighting','Puzzle'};
    codes = 0:10;
    idx = find(strcmpi(names, name), 1);
    if isempty(idx)
        error('neosdconv_convert:genre', ...
            'Unknown genre "%s". Valid values: %s', name, strjoin(names, ', '));
    end
    code = codes(idx);
end

function n = parseNGH(nghStr)
% Reproduces getNGHNumber(): the string is parsed as HEXADECIMAL.
    if isnumeric(nghStr)
        n = double(nghStr);
        return;
    end
    if isempty(nghStr)
        n = 0;
        return;
    end
    s = strtrim(nghStr);
    if numel(s) > 1 && strcmpi(s(1:2), '0x')
        s = s(3:end);
    end
    try
        n = hex2dec(s);
    catch
        warning('neosdconv_convert:ngh', 'Invalid NGH "%s", using 0', nghStr);
        n = 0;
    end
end
