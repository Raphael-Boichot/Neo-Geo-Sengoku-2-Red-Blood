function info = neosdconv_dump_header(neoPath)
%NEOSDCONV_DUMP_HEADER Display/return the metadata of a .neo file
%
%   info = NEOSDCONV_DUMP_HEADER(neoPath)
%
%   Reproduces neosdconv's dumpHeader.ts: reads back the first 4096
%   bytes of a .neo file and extracts all its metadata. Handy for
%   checking the output of NEOSDCONV_CONVERT (on Sengoku 2, its hack,
%   or any other .neo). If no output is requested, prints a summary
%   to the console (like `neosdconv --dump`).
%
%   See also: NEOSDCONV_CONVERT

    fid = fopen(neoPath, 'rb');
    if fid == -1
        error('neosdconv_dump_header:io', 'Unable to open "%s"', neoPath);
    end
    h = fread(fid, 4096, '*uint8')';
    fclose(fid);

    if numel(h) < 4096
        error('neosdconv_dump_header:size', ...
            'File too short for a .neo header (%d < 4096 bytes)', numel(h));
    end

    info.tag     = char(h(1:3));
    info.version = double(h(4));

    info.sizes.p  = fromU32le(h(5:8));
    info.sizes.s  = fromU32le(h(9:12));
    info.sizes.m  = fromU32le(h(13:16));
    info.sizes.v1 = fromU32le(h(17:20));
    info.sizes.v2 = fromU32le(h(21:24));
    info.sizes.c  = fromU32le(h(25:28));

    info.year       = fromU32le(h(29:32));
    genreVal        = fromU32le(h(33:36));
    info.genre      = genreName(genreVal);
    info.screenshot = fromU32le(h(37:40));
    info.ngh        = fromU32le(h(41:44));

    nameRaw = h(45:45+32);    % offset 0x2C, 33 bytes
    manRaw  = h(78:78+16);    % offset 0x4D, 17 bytes
    info.name         = char(nameRaw(nameRaw ~= 0));
    info.manufacturer = char(manRaw(manRaw ~= 0));

    if nargout == 0
        fprintf('%s - %s, %d, %s, NGH-%s, screenshot %d\n', ...
            info.name, info.manufacturer, info.year, info.genre, ...
            dec2hex(info.ngh), info.screenshot);
        fprintf('P=%d S=%d M=%d V1=%d V2=%d C=%d\n', ...
            info.sizes.p, info.sizes.s, info.sizes.m, ...
            info.sizes.v1, info.sizes.v2, info.sizes.c);
        clear info
    end
end

function v = fromU32le(bytes4)
    b = double(bytes4);
    v = b(1) + b(2)*256 + b(3)*65536 + b(4)*16777216;
end

function name = genreName(code)
    names = {'Other','Action','BeatEmUp','Sports','Driving','Platformer', ...
             'Mahjong','Shooter','Quiz','Fighting','Puzzle'};
    if code >= 0 && code < numel(names)
        name = names{code+1};
    else
        name = 'Other';
    end
end
