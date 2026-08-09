function EPROM_merger(oddRomFile, evenRomFile, outputMergedFile)
% Crom_merge  Byte-interleave a Neo Geo C-ROM pair (C1/C2 style) into a
% single merged binary suitable for burning to one EPROM that replaces
% two smaller C-ROM chips.
%
% MAME's ROM_LOAD16_BYTE loads C1 at offset 0 / C2 at offset 1 within a
% BIG-ENDIAN 16-bit region, i.e. word = (C1<<8)|C2 -> C1 is the HIGH byte.
% On the target chip, byte address 2N (A-1=0) is always the LOW byte of
% word N. So to reproduce the correct word value, C2 (low byte) must sit
% at the even offsets and C1 (high byte) at the odd offsets -- the
% opposite of a naive "C1 first" concatenation of the byte stream.
%   merged = [ C2(1) C1(1) C2(2) C1(2) C2(3) C1(3) ... ]
% i.e. even byte offsets (0,2,4,...) = even file (C2, planes 2/3, LOW byte)
%      odd  byte offsets (1,3,5,...) = odd  file (C1, planes 0/1, HIGH byte)

% 1. Load and verify ROMs
fid1 = fopen(oddRomFile,'rb');  odd  = fread(fid1,Inf,'uint8=>uint8'); fclose(fid1);
fid2 = fopen(evenRomFile,'rb'); even = fread(fid2,Inf,'uint8=>uint8'); fclose(fid2);

fprintf('Source  %s (CRC32: %08X)\n', oddRomFile, computeCRC32(oddRomFile));
fprintf('Source  %s (CRC32: %08X)\n', evenRomFile, computeCRC32(evenRomFile));

if numel(odd) ~= numel(even)
    error('C1 and C2 must be the same size (%d vs %d bytes). Pad the smaller one before merging.', ...
        numel(odd), numel(even));
end

% 2. Byte-interleave: C2 (low byte) into even positions, C1 (high byte) into odd positions
n = numel(odd);
merged = zeros(n*2, 1, 'uint8');
merged(1:2:end) = even;  % offset 0, 2, 4, ... -> C2 (planes 2/3, LOW byte)
merged(2:2:end) = odd;   % offset 1, 3, 5, ... -> C1 (planes 0/1, HIGH byte)

% 3. Write merged EPROM image
fidOut = fopen(outputMergedFile,'wb');
fwrite(fidOut, merged, 'uint8');
fclose(fidOut);

fprintf('Merged  %s (CRC32: %08X, %d bytes)\n', outputMergedFile, computeCRC32(outputMergedFile), numel(merged));

end
