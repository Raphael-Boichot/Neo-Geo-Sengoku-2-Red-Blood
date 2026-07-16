function EPROM_merger(oddRomFile, evenRomFile, outputMergedFile)
% EPROM_merger_reversed - Byte-interleave with reversed endianness
% Interleave order:
%   merged = [ C2(1) C1(1) C2(2) C1(2) C2(3) C1(3) ... ]

% 1. Load and verify ROMs
fid1 = fopen(oddRomFile,'rb');  odd  = fread(fid1,Inf,'uint8=>uint8'); fclose(fid1);
fid2 = fopen(evenRomFile,'rb'); even = fread(fid2,Inf,'uint8=>uint8'); fclose(fid2);

if numel(odd) ~= numel(even)
    error('C1 and C2 must be the same size. Pad the smaller one before merging.');
end

% 2. Byte-interleave: Reversed Endian
n = numel(odd);
merged = zeros(n*2, 1, 'uint8');

% SWAPPED ASSIGNMENTS:
merged(1:2:end) = even;  % offset 0, 2, 4, ... -> C2
merged(2:2:end) = odd;   % offset 1, 3, 5, ... -> C1

% 3. Write merged EPROM image
fidOut = fopen(outputMergedFile,'wb');
fwrite(fidOut, merged, 'uint8');
fclose(fidOut);

fprintf('Successfully created merged file: %s\n', outputMergedFile);
end