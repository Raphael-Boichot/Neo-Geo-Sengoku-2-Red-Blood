function EPROM_merger(oddRomFile, evenRomFile, outputMergedFile)
% Crom_merge  Byte-interleave a Neo Geo C-ROM pair (C1/C2 style) into a
% single merged binary suitable for burning to one EPROM that replaces
% two smaller C-ROM chips.
%
% Interleave order matches MAME's ROM_LOAD16_BYTE convention:
%   merged = [ C1(1) C2(1) C1(2) C2(2) 1(3) C2(3) ... ]
% i.e. even byte offsets (0,2,4,...) = odd file (C1, planes 0/1)
%      odd  byte offsets (1,3,5,...) = even file (C2, planes 2/3)

% 1. Load and verify ROMs
fid1 = fopen(oddRomFile,'rb');  odd  = fread(fid1,Inf,'uint8=>uint8'); fclose(fid1);
fid2 = fopen(evenRomFile,'rb'); even = fread(fid2,Inf,'uint8=>uint8'); fclose(fid2);

fprintf('Source  %s (CRC32: %08X)\n', oddRomFile, computeCRC32(oddRomFile));
fprintf('Source  %s (CRC32: %08X)\n', evenRomFile, computeCRC32(evenRomFile));

if numel(odd) ~= numel(even)
    error('C1 and C2 must be the same size (%d vs %d bytes). Pad the smaller one before merging.', ...
        numel(odd), numel(even));
end

% 2. Byte-interleave: C1 into even positions, C2 into odd positions
n = numel(odd);
merged = zeros(n*2, 1, 'uint8');
merged(1:2:end) = odd;   % offset 0, 2, 4, ... -> C1 (planes 0/1)
merged(2:2:end) = even;  % offset 1, 3, 5, ... -> C2 (planes 2/3)

% 3. Write merged EPROM image
fidOut = fopen(outputMergedFile,'wb');
fwrite(fidOut, merged, 'uint8');
fclose(fidOut);

fprintf('Merged  %s (CRC32: %08X, %d bytes)\n', outputMergedFile, computeCRC32(outputMergedFile), numel(merged));

end