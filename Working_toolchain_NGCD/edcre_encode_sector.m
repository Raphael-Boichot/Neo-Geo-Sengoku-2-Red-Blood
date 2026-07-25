function [sector_out, tables] = edcre_encode_sector(mode, adr, sector_in, varargin)
%EDCRE_ENCODE_SECTOR  Regenerate CD-ROM EDC/ECC (Mode 1 / Mode 2 Form 1 / Form 2).
%
%   MATLAB/Octave port of the sector-encoding core of EDCRE
%   (https://alex-free.github.io/edcre), which is itself built on lec.cc
%   from cdrdao (https://github.com/cdrdao/cdrdao). This reproduces the
%   sync pattern, header, EDC (CRC-32) and P/Q (Reed-Solomon) parity
%   generation bit-for-bit.
%
%   sector_out = EDCRE_ENCODE_SECTOR(mode, adr, sector_in)
%   sector_out = EDCRE_ENCODE_SECTOR(mode, adr, sector_in, 'KeepHeader', true, ...
%                                     'ExistingHeader', hdr)
%   [sector_out, tables] = EDCRE_ENCODE_SECTOR(...)
%
%   Inputs
%     mode      - which sector type to encode. One of:
%                   1, 'mode1'                 -> CD-ROM Mode 1
%                   2, 'mode2form1', 'xa1'      -> CD-ROM XA Mode 2 Form 1
%                   3, 'mode2form2', 'xa2'      -> CD-ROM XA Mode 2 Form 2
%     adr       - physical sector address (LBA, includes the 150 sector
%                 pregap) used to build the MM:SS:FF timecode in the
%                 sector header. Ignored when 'KeepHeader' is true.
%     sector_in - 2352-element numeric/uint8 row vector containing the
%                 raw sector. Only the user-data region is actually read;
%                 sync pattern, header, EDC and parity bytes are all
%                 (re)computed and overwritten:
%                   Mode 1          : 2048 bytes of user data at offset 16
%                   Mode 2 Form 1   : 2056 bytes of user data at offset 16
%                   Mode 2 Form 2   : 2332 bytes of user data at offset 16
%                 (offsets are 0-based, matching the C source / ECMA-130).
%                 A shorter vector is zero-padded to 2352 bytes.
%
%   Name-Value options
%     'KeepHeader'     - if true, do not regenerate the MM:SS:FF header
%                         from adr; instead reuse 'ExistingHeader' (or,
%                         if omitted, whatever 4 bytes already sit at
%                         offset 12 of sector_in). Mirrors the -k flag
%                         of the edcre CLI tool. Default: false.
%     'ExistingHeader' - 4-element vector [MM SS FF MODE] used when
%                         'KeepHeader' is true. Default: sector_in(13:16).
%     'Tables'         - a previously-returned `tables` struct (see
%                         below) to reuse instead of rebuilding the GF(8)
%                         log/CRC/parity-coefficient tables. Building the
%                         tables is the only "slow" part of this function
%                         (a few hundred ms), so pass this in when
%                         encoding many sectors in a loop, e.g.:
%
%                           [~, T] = edcre_encode_sector(1, 0, zeros(1,2352));
%                           for k = 1:nSectors
%                               out(k,:) = edcre_encode_sector(1, 150+k-1, ...
%                                              data(k,:), 'Tables', T);
%                           end
%
%     'Verbose'        - if true, print a message whenever the EDC and/or
%                         P/Q parity ("ECC") bytes already present in
%                         sector_in do not match what gets (re)computed --
%                         i.e. sector_in contained invalid EDC/ECC data.
%                         Sync pattern and header differences are not
%                         reported by this flag (use EDCRE_FIX_FILE's
%                         'Verbose' for whole-sector "updated" messages).
%                         Default: false.
%
%   Outputs
%     sector_out - 1x2352 uint8 row vector: the fully-encoded sector
%                  (sync + header + user data + EDC/intermediate field +
%                  P/Q parity, as applicable to the chosen mode).
%     tables     - struct with the precomputed GF(8) log tables, CRC-32
%                  table and Q-parity coefficient table. Pass back in via
%                  'Tables' to skip rebuilding them on repeat calls.
%
%   Example
%       data = uint8(randi([0 255], 1, 2048));
%       sector = zeros(1, 2352, 'uint8');
%       sector(17:17+2047) = data;            % offset 16 (0-based) = index 17
%       sector = edcre_encode_sector(1, 200, sector);
%
%   See also EDCRE_FIX_FILE.

% ------------------------------------------------------------------
% Argument parsing
% ------------------------------------------------------------------
opts = struct('KeepHeader', false, 'ExistingHeader', [], 'Tables', [], 'Verbose', false);
k = 1;
while k <= numel(varargin)
    name = varargin{k};
    if ~ischar(name) && ~isstring(name)
        error('edcre_encode_sector:badArg', 'Expected a name-value pair.');
    end
    if k == numel(varargin)
        error('edcre_encode_sector:badArg', 'Missing value for ''%s''.', name);
    end
    opts.(char(name)) = varargin{k+1};
    k = k + 2;
end

sector = zeros(1, 2352, 'uint8');
n = numel(sector_in);
if n > 2352
    error('edcre_encode_sector:badSector', 'sector_in must be at most 2352 bytes.');
end
sector(1:n) = uint8(sector_in(:).');

if opts.KeepHeader && isempty(opts.ExistingHeader)
    opts.ExistingHeader = sector(13:16);
end

if isempty(opts.Tables)
    tables = build_tables();
else
    tables = opts.Tables;
end

% ------------------------------------------------------------------
% Normalize mode
% ------------------------------------------------------------------
if ischar(mode) || isstring(mode)
    switch lower(char(mode))
        case 'mode1',                      mode = 1;
        case {'mode2form1','xa1'},         mode = 2;
        case {'mode2form2','xa2'},         mode = 3;
        otherwise
            error('edcre_encode_sector:badMode', 'Unknown mode ''%s''.', mode);
    end
end

orig_sector = sector; % keep a copy of what was passed in, before it is overwritten

switch mode
    case 1
        sector = lec_encode_mode1_sector(adr, sector, tables, opts);
    case 2
        sector = lec_encode_mode2_form1_sector(adr, sector, tables, opts);
    case 3
        sector = lec_encode_mode2_form2_sector(adr, sector, tables, opts);
    otherwise
        error('edcre_encode_sector:badMode', 'mode must be 1, 2, 3 (or a mode name).');
end

if opts.Verbose
    report_bad_ecc(orig_sector, sector, mode, adr);
end

sector_out = sector;

end % edcre_encode_sector


% ==================================================================
% Verbose "bad EDC/ECC" reporting
% ==================================================================
function report_bad_ecc(orig, new, mode, adr)
% Compares only the EDC and P/Q-parity ("ECC") byte ranges of orig vs
% new (1-based, inclusive) and prints which ones didn't match what was
% just (re)computed. Sync/header are intentionally not checked here.
switch mode
    case 1 % Mode 1
        regions = {'EDC', 2065, 2068; 'P parity', 2077, 2248; 'Q parity', 2249, 2352};
        label = 'MODE1';
    case 2 % Mode 2 Form 1
        regions = {'EDC', 2073, 2076; 'P parity', 2077, 2248; 'Q parity', 2249, 2352};
        label = 'MODE2_FORM1';
    case 3 % Mode 2 Form 2 (no ECC parity, EDC only)
        regions = {'EDC', 2349, 2352};
        label = 'MODE2_FORM2';
end

bad = {};
for r = 1:size(regions, 1)
    name = regions{r, 1};
    s = regions{r, 2};
    e = regions{r, 3};
    if ~isequal(orig(s:e), new(s:e))
        bad{end+1} = name; %#ok<AGROW>
    end
end

if ~isempty(bad)
    fprintf('Sector at LBA %d (%s): invalid %s\n', adr, label, strjoin(bad, ', '));
end
end


% ==================================================================
% Table construction (GF(8) logs, CRC-32 table, Q-parity coefficients)
% ==================================================================
function tables = build_tables()
GF8_PRIM_POLY = hex2dec('11d'); % x^8 + x^4 + x^3 + x^2 + 1

[GF8_LOG, GF8_ILOG] = gf8_create_log_tables(GF8_PRIM_POLY);
QT = build_q_coeffs_table(GF8_LOG, GF8_ILOG);
CRCTABLE = build_crc_table();

tables = struct('GF8_LOG', GF8_LOG, 'GF8_ILOG', GF8_ILOG, ...
                 'QT', QT, 'CRCTABLE', CRCTABLE);
end

function [GF8_LOG, GF8_ILOG] = gf8_create_log_tables(GF8_PRIM_POLY)
% GF8_LOG(x+1)  = discrete log of x  (1-based indexing, x in 0..255)
% GF8_ILOG(l+1) = alpha^l            (1-based indexing, l in 0..254)
GF8_LOG  = zeros(1, 256);
GF8_ILOG = zeros(1, 256);

b = 1;
for lg = 0:254
    bb = mod(b, 256); % (uint8_t) cast in the original
    GF8_LOG(bb + 1)  = lg;
    GF8_ILOG(lg + 1) = bb;

    b = b * 2;
    if bitand(b, 256) ~= 0
        b = bitxor(b, GF8_PRIM_POLY);
    end
end
end

function r = gf8_div(a, b, GF8_LOG, GF8_ILOG)
% Division in GF(8): subtract logarithms.
if a == 0
    r = 0;
    return;
end
s = GF8_LOG(a + 1) - GF8_LOG(b + 1);
if s < 0
    s = s + 255;
end
r = GF8_ILOG(s + 1);
end

function QT = build_q_coeffs_table(GF8_LOG, GF8_ILOG)
% Precompute, for each of the 43 Q-parity coefficients and each possible
% byte value, the GF(8) product with that coefficient's e0 and e1
% components, packed into a single uint16 (low byte = e0 product,
% high byte = e1 product) -- exactly mirroring CF8_Q_COEFFS_RESULTS_01
% in the original source. The P-parity coefficients are a subset of the
% Q-parity coefficients, so this single table serves both.
HELP = zeros(2, 45);
QC   = zeros(2, 45);

for j = 0:44
    HELP(1, j+1) = 1;                     % e0
    HELP(2, j+1) = GF8_ILOG(44 - j + 1);  % e1
end

% e1' = e1 + e0
for j = 0:44
    QC(2, j+1) = bitxor(HELP(2, j+1), HELP(1, j+1));
end
% e1'' = e1' / (a^1 + 1)
denom1 = QC(2, 44); % j == 43
for j = 0:44
    QC(2, j+1) = gf8_div(QC(2, j+1), denom1, GF8_LOG, GF8_ILOG);
end
% e0' = e0 + e1 / a^1
a1 = GF8_ILOG(2); % GF8_ILOG[1]
for j = 0:44
    QC(1, j+1) = bitxor(HELP(1, j+1), gf8_div(HELP(2, j+1), a1, GF8_LOG, GF8_ILOG));
end
% e0'' = e0' / (1 + 1/a^1)
denom0 = QC(1, 45); % j == 44
for j = 0:44
    QC(1, j+1) = gf8_div(QC(1, j+1), denom0, GF8_LOG, GF8_ILOG);
end

QT = zeros(43, 256, 'uint16');
for j = 0:42
    c0 = QC(1, j+1);
    c1 = QC(2, j+1);
    logc0 = GF8_LOG(c0 + 1);
    logc1 = GF8_LOG(c1 + 1);
    for i = 1:255
        c = GF8_LOG(i+1) + logc0;
        if c >= 255, c = c - 255; end
        lo = GF8_ILOG(c + 1);

        c = GF8_LOG(i+1) + logc1;
        if c >= 255, c = c - 255; end
        hi = GF8_ILOG(c + 1);

        QT(j+1, i+1) = uint16(lo) + bitshift(uint16(hi), 8);
    end
end
end

function r = mirror_bits(d, bits)
% Reverse the low `bits` bits of d.
r = 0;
for i = 1:bits
    r = r * 2;
    if bitand(d, 1) ~= 0
        r = r + 1;
    end
    d = floor(d / 2);
end
end

function CRCTABLE = build_crc_table()
% Reflected CRC-32 lookup table for EDC_POLY = 0x8001801b
% ( = (x^16+x^15+x^2+1)(x^16+x^2+x+1) ).
EDC_POLY = hex2dec('8001801b');
CRCTABLE = zeros(1, 256);

for i = 0:255
    r = mirror_bits(i, 8);
    r = r * 2^24; % r <<= 24

    for j = 0:7
        topbit = (r >= 2^31); % r & 0x80000000
        r = mod(r * 2, 2^32); % r <<= 1  (32-bit wraparound)
        if topbit
            r = bitxor(r, EDC_POLY);
        end
    end

    r = mirror_bits(r, 32);
    CRCTABLE(i + 1) = r;
end
end


% ==================================================================
% EDC (CRC-32) calculation
% ==================================================================
function crc = calc_edc(data, CRCTABLE)
% data: uint8 row vector. Returns a double holding the 32-bit CRC value.
crc = 0;
for k = 1:numel(data)
    idx = bitand(bitxor(crc, double(data(k))), 255);
    crc = bitxor(CRCTABLE(idx + 1), bitshift(crc, -8));
end
end

function sector = write_u32le(sector, offset0, value)
% offset0 is a 0-based byte offset. value is a double 0..2^32-1.
idx = offset0 + 1;
sector(idx)     = uint8(bitand(value, 255));
sector(idx + 1) = uint8(bitand(bitshift(value, -8),  255));
sector(idx + 2) = uint8(bitand(bitshift(value, -16), 255));
sector(idx + 3) = uint8(bitand(bitshift(value, -24), 255));
end

function sector = calc_mode1_edc(sector, tables)
LEC_MODE1_DATA_LEN  = 2048;
LEC_MODE1_EDC_OFFSET = 2064;
crc = calc_edc(sector(1:(LEC_MODE1_DATA_LEN + 16)), tables.CRCTABLE);
sector = write_u32le(sector, LEC_MODE1_EDC_OFFSET, crc);
end

function sector = calc_mode2_form1_edc(sector, tables)
LEC_DATA_OFFSET = 16;
LEC_MODE2_FORM1_DATA_LEN = 2048 + 8;
LEC_MODE2_FORM1_EDC_OFFSET = 2072;
crc = calc_edc(sector((LEC_DATA_OFFSET+1):(LEC_DATA_OFFSET+LEC_MODE2_FORM1_DATA_LEN)), tables.CRCTABLE);
sector = write_u32le(sector, LEC_MODE2_FORM1_EDC_OFFSET, crc);
end

function sector = calc_mode2_form2_edc(sector, tables)
LEC_DATA_OFFSET = 16;
LEC_MODE2_FORM2_DATA_LEN = 2324 + 8;
LEC_MODE2_FORM2_EDC_OFFSET = 2348;
crc = calc_edc(sector((LEC_DATA_OFFSET+1):(LEC_DATA_OFFSET+LEC_MODE2_FORM2_DATA_LEN)), tables.CRCTABLE);
sector = write_u32le(sector, LEC_MODE2_FORM2_EDC_OFFSET, crc);
end


% ==================================================================
% Sync pattern / header
% ==================================================================
function sector = set_sync_pattern(sector)
sector(1)     = 0;
sector(2:11)  = 255;
sector(12)    = 0;
end

function b = bin2bcd(v)
b = uint8(bitor(bitand(bitshift(uint8(floor(v/10)),4), 240), bitand(uint8(mod(v,10)), 15)));
end

function sector = set_sector_header(md, adr, sector, opts)
LEC_HEADER_OFFSET = 12;
idx = LEC_HEADER_OFFSET + 1;
if opts.KeepHeader
    hdr = uint8(opts.ExistingHeader(:).');
    sector(idx:idx+3) = hdr(1:4);
else
    sector(idx)   = bin2bcd(floor(adr / (60*75)));
    sector(idx+1) = bin2bcd(mod(floor(adr/75), 60));
    sector(idx+2) = bin2bcd(mod(adr, 75));
    sector(idx+3) = uint8(md);
end
end


% ==================================================================
% P / Q parity (Reed-Solomon, GF(8))
% ==================================================================
function sector = calc_P_parity(sector, tables)
LEC_HEADER_OFFSET     = 12;
LEC_MODE1_P_PARITY_OFFSET = 2076;
QT = tables.QT;

p_lsb_start = LEC_HEADER_OFFSET;
p1 = LEC_MODE1_P_PARITY_OFFSET;
p0 = LEC_MODE1_P_PARITY_OFFSET + 2*43;

for i = 0:42
    p_lsb = p_lsb_start;
    p01_lsb = uint16(0);
    p01_msb = uint16(0);

    for j = 19:42
        d0 = sector(p_lsb + 1);
        d1 = sector(p_lsb + 2);

        p01_lsb = bitxor(p01_lsb, QT(j+1, double(d0)+1));
        p01_msb = bitxor(p01_msb, QT(j+1, double(d1)+1));

        p_lsb = p_lsb + 2*43;
    end

    sector(p0+1) = uint8(bitand(p01_lsb, 255));
    sector(p0+2) = uint8(bitand(p01_msb, 255));
    sector(p1+1) = uint8(bitshift(p01_lsb, -8));
    sector(p1+2) = uint8(bitshift(p01_msb, -8));

    p0 = p0 + 2;
    p1 = p1 + 2;
    p_lsb_start = p_lsb_start + 2;
end
end

function sector = calc_Q_parity(sector, tables)
LEC_HEADER_OFFSET         = 12;
LEC_MODE1_Q_PARITY_OFFSET = 2248;
QT = tables.QT;

q_lsb_start = LEC_HEADER_OFFSET;
q_start = LEC_MODE1_Q_PARITY_OFFSET;
q1 = LEC_MODE1_Q_PARITY_OFFSET;
q0 = LEC_MODE1_Q_PARITY_OFFSET + 2*26;

for i = 0:25
    q_lsb = q_lsb_start;
    q01_lsb = uint16(0);
    q01_msb = uint16(0);

    for j = 0:42
        d0 = sector(q_lsb + 1);
        d1 = sector(q_lsb + 2);

        q01_lsb = bitxor(q01_lsb, QT(j+1, double(d0)+1));
        q01_msb = bitxor(q01_msb, QT(j+1, double(d1)+1));

        q_lsb = q_lsb + 2*44;
        if q_lsb >= q_start
            q_lsb = q_lsb - 2*1118;
        end
    end

    sector(q0+1) = uint8(bitand(q01_lsb, 255));
    sector(q0+2) = uint8(bitand(q01_msb, 255));
    sector(q1+1) = uint8(bitshift(q01_lsb, -8));
    sector(q1+2) = uint8(bitshift(q01_msb, -8));

    q0 = q0 + 2;
    q1 = q1 + 2;
    q_lsb_start = q_lsb_start + 2*43;
end
end


% ==================================================================
% Full-sector encoders
% ==================================================================
function sector = lec_encode_mode1_sector(adr, sector, tables, opts)
LEC_MODE1_INTERMEDIATE_OFFSET = 2068;

sector = set_sync_pattern(sector);
sector = set_sector_header(1, adr, sector, opts);
sector = calc_mode1_edc(sector, tables);

sector(LEC_MODE1_INTERMEDIATE_OFFSET+1 : LEC_MODE1_INTERMEDIATE_OFFSET+8) = 0;

sector = calc_P_parity(sector, tables);
sector = calc_Q_parity(sector, tables);
end

function sector = lec_encode_mode2_form1_sector(adr, sector, tables, opts)
LEC_HEADER_OFFSET = 12;

sector = set_sync_pattern(sector);
sector = calc_mode2_form1_edc(sector, tables);

% P/Q parity must not include the sector header, so clear it first ...
sector(LEC_HEADER_OFFSET+1 : LEC_HEADER_OFFSET+4) = 0;

sector = calc_P_parity(sector, tables);
sector = calc_Q_parity(sector, tables);

% ... then write the real header afterwards.
sector = set_sector_header(2, adr, sector, opts);
end

function sector = lec_encode_mode2_form2_sector(adr, sector, tables, opts)
sector = set_sync_pattern(sector);
sector = calc_mode2_form2_edc(sector, tables);
sector = set_sector_header(2, adr, sector, opts);
end
