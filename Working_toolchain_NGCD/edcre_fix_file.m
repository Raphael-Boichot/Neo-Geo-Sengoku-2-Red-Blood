function stats = edcre_fix_file(data_track_file, varargin)
%EDCRE_FIX_FILE  Regenerate EDC/ECC across a whole CD-ROM data-track .bin,
%   the same job the compiled `edcre` CLI tool does.
%
%   stats = EDCRE_FIX_FILE(data_track_file)
%   stats = EDCRE_FIX_FILE(data_track_file, 'StartSector', 16, ...)
%   stats = EDCRE_FIX_FILE(data_track_file, 'Sectors', [16, 17, 105], ...)
%
%   Name-Value options (mirroring the edcre CLI flags + custom extensions)
%     'StartSector' - sector index (0-based, relative to the start of
%                      the file / LBA-150) to begin at. Same as -s N.
%                      Default: 0 (ignored if 'Sectors' is specified).
%     'Sectors'      - vector of specific 0-based sector indices to target.
%                      If specified, sequential scanning is bypassed and
%                      only these specific sectors are checked/fixed.
%                      Default: [].
%     'TestOnly'     - true = don't modify the file, just report which
%                      sectors would change. Same as -t. Default: false.
%     'KeepHeader'   - true = don't regenerate the MM:SS:FF header from
%                      the running LBA counter; reuse each sector's own
%                      existing header bytes instead. Same as -k.
%                      Default: false.
%     'Verbose'      - true = print a line for every sector that
%                      changes (or, with 'TestOnly', every invalid
%                      sector). Same as -v. Default: false.
%     'Pregap'       - pregap length in sectors added to the LBA shown
%                      in messages / used for MM:SS:FF when not keeping
%                      the header. Default: 150.
%
%   Output
%     stats - struct with fields: mode1, mode2form1, mode2form2 (sector
%             counts by type) and fixed (number of sectors whose
%             contents changed).
%
%   See also EDCRE_ENCODE_SECTOR.

p = struct('StartSector', 0, 'Sectors', [], 'TestOnly', false, ...
           'KeepHeader', false, 'Verbose', false, 'Pregap', 150);
k = 1;
while k <= numel(varargin)
    p.(char(varargin{k})) = varargin{k+1};
    k = k + 2;
end

if ~exist(data_track_file, 'file')
    error('edcre_fix_file:noFile', 'Cannot open data track bin file: %s', data_track_file);
end

if p.TestOnly
    fid = fopen(data_track_file, 'rb');
else
    fid = fopen(data_track_file, 'r+b');
end
if fid < 0
    error('edcre_fix_file:noFile', 'Cannot open data track bin file: %s', data_track_file);
end
cleanupObj = onCleanup(@() fclose(fid));

stats = struct('mode1', 0, 'mode2form1', 0, 'mode2form2', 0, 'fixed', 0);
[~, T] = edcre_encode_sector(1, 0, zeros(1, 2352)); % prebuild tables once

% Determine target sectors layout (either explicit list or sequential scan)
if ~isempty(p.Sectors)
    target_sectors = p.Sectors(:)'; % ensure row vector
else
    target_sectors = []; 
end

if ~isempty(target_sectors)
    % --- MODE A: Direct targeting of specific sectors ---
    for s_idx = target_sectors
        byte_offset = s_idx * 2352;
        
        status = fseek(fid, byte_offset, 'bof');
        if status ~= 0
            warning('edcre_fix_file:seekError', 'Could not seek to sector %u (beyond EOF?)', s_idx);
            continue;
        end
        
        buf1 = fread(fid, 2352, 'uint8=>uint8')';
        if numel(buf1) < 2352
            warning('edcre_fix_file:eof', 'Sector %u is truncated or past EOF.', s_idx);
            continue;
        end

        if ~is_sync_pattern(buf1)
            warning('edcre_fix_file:noSync', 'Sector %u does not have a valid sync pattern. Skipping.', s_idx);
            continue;
        end

        lba = p.Pregap + s_idx;
        [buf2, label] = process_sector_buffer(buf1, lba, p, T);
        
        switch label
            case 'MODE1'
                stats.mode1 = stats.mode1 + 1;
            case 'MODE2_FORM1'
                stats.mode2form1 = stats.mode2form1 + 1;
            case 'MODE2_FORM2'
                stats.mode2form2 = stats.mode2form2 + 1;
        end

        if ~isequal(buf1, buf2)
            stats.fixed = stats.fixed + 1;
            if p.Verbose
                if p.TestOnly
                    fprintf('Sector %u (LBA: %u) (%s) is not valid\n', s_idx, lba, label);
                else
                    fprintf('Updated sector %u (LBA: %u) (%s)\n', s_idx, lba, label);
                end
            end

            if ~p.TestOnly
                fseek(fid, byte_offset, 'bof');
                fwrite(fid, buf2, 'uint8');
            end
        end
    end

else
    % --- MODE B: Original sequential streaming scan ---
    byte_offset = p.StartSector * 2352;
    fseek(fid, byte_offset, 'bof');
    lba = p.Pregap + p.StartSector;

    while true
        pos = ftell(fid);
        buf1 = fread(fid, 2352, 'uint8=>uint8')';
        if numel(buf1) < 2352
            break; % EOF
        end

        if ~is_sync_pattern(buf1)
            fprintf('CDDA sectors detected, data sector read complete.\n');
            break;
        end

        [buf2, label] = process_sector_buffer(buf1, lba, p, T);
        
        switch label
            case 'MODE1'
                stats.mode1 = stats.mode1 + 1;
            case 'MODE2_FORM1'
                stats.mode2form1 = stats.mode2form1 + 1;
            case 'MODE2_FORM2'
                stats.mode2form2 = stats.mode2form2 + 1;
        end

        if ~isequal(buf1, buf2)
            stats.fixed = stats.fixed + 1;
            if p.Verbose
                if p.TestOnly
                    fprintf('Sector %u (LBA: %u) (%s) is not valid\n', lba - p.Pregap, lba, label);
                else
                    fprintf('Updated sector %u (LBA: %u) (%s)\n', lba - p.Pregap, lba, label);
                end
            end

            if ~p.TestOnly
                fseek(fid, pos, 'bof');
                fwrite(fid, buf2, 'uint8');
            end
        end

        lba = lba + 1;
    end
end

% Final summary messages
if p.TestOnly
    if stats.fixed == 0
        fprintf('All targeted sectors already contain valid ECC/EDC data\n');
    else
        fprintf('Found invalid EDC/ECC data in %u sector(s)\n', stats.fixed);
    end
else
    if stats.fixed == 0
        fprintf('No sectors needed EDC/ECC regeneration, nothing done\n');
    else
        fprintf('Updated EDC/ECC in %u sector(s)\n', stats.fixed);
    end
end

end % edcre_fix_file


function [buf2, label] = process_sector_buffer(buf1, lba, p, T)
    mode_byte = buf1(16); % 0-based offset 15 -> 1-based index 16

    encode_opts = {'Tables', T, 'KeepHeader', p.KeepHeader};
    if p.KeepHeader
        encode_opts = [encode_opts, {'ExistingHeader', buf1(13:16)}];
    end

    switch mode_byte
        case 1
            buf2 = edcre_encode_sector(1, lba, buf1, encode_opts{:});
            label = 'MODE1';
        case 2
            if bitand(buf1(19), 32) ~= 0 % offset 12+4+2=18 (0-based) -> index19
                buf2 = edcre_encode_sector(3, lba, buf1, encode_opts{:});
                label = 'MODE2_FORM2';
            else
                buf2 = edcre_encode_sector(2, lba, buf1, encode_opts{:});
                label = 'MODE2_FORM1';
            end
        otherwise
            buf2 = buf1;
            label = '';
    end
end

function tf = is_sync_pattern(buf)
tf = buf(1) == 0 && buf(12) == 0 && all(buf(2:11) == 255);
end