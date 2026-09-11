function EPROM_merger(mainRomFile, smallRomFile, outputMergedFile)
% EPROM_merger
% Rebuild the 4 MiB EPROM image used by the Sengoku 2 bootleg.
%
% The supplied MX26LV6420 dumps show that each 4 MiB useful bank is
% organized as follows (addresses are byte offsets in the EPROM):
%
%   000000-0FFFFF : first 1 MiB of the 2 MiB C-ROM
%   100000-1FFFFF : 512 KiB C-ROM repeated twice
%   200000-2FFFFF : second 1 MiB of the 2 MiB C-ROM
%   300000-3FFFFF : 512 KiB C-ROM repeated twice
%
% Therefore:
%
%   Chip 1 = 040-c1.c1 + 040-c3.c3
%   Chip 2 = 040-c2.c2 + 040-c4.c4
%
% The small C-ROM is NOT byte-interleaved with the large C-ROM.  The
% original bootleg simply places/repeats the small ROM in the 1 MiB
% regions between the two halves of the large ROM.
%
% This function creates an exact 4 MiB image suitable for programming
% into a 4 MiB EPROM/flash device used in place of the bootleg chip.
%
% Example:
%   EPROM_merger('040-c1.c1','040-c3.c3','Chip_1_4MB.bin');
%   EPROM_merger('040-c2.c2','040-c4.c4','Chip_2_4MB.bin');
%
% The input files are checked for the expected sizes and CRC32 values are
% printed for source and output files.  If an output file is supplied,
% its CRC32 can be compared directly with a known-good bootleg dump.

TARGET_SIZE = 4 * 1024 * 1024;
MAIN_SIZE   = 2 * 1024 * 1024;
SMALL_SIZE  = 512 * 1024;
BANK_SIZE   = 1 * 1024 * 1024;

%% 1. Read source ROMs
mainRom  = readBinary(mainRomFile);
smallRom = readBinary(smallRomFile);

fprintf('============================================================\n');
fprintf('Sengoku 2 bootleg 4 MiB EPROM merger\n');
fprintf('============================================================\n');
fprintf('Main ROM  : %s\n', mainRomFile);
fprintf('  Size    : %d bytes (0x%X)\n', numel(mainRom), numel(mainRom));
fprintf('  CRC32   : %08X\n', computeCRC32(mainRomFile));
fprintf('Small ROM : %s\n', smallRomFile);
fprintf('  Size    : %d bytes (0x%X)\n', numel(smallRom), numel(smallRom));
fprintf('  CRC32   : %08X\n', computeCRC32(smallRomFile));

%% 2. Validate expected Sengoku 2 C-ROM sizes
if numel(mainRom) ~= MAIN_SIZE
    error(['Main ROM must be exactly 2 MiB (0x200000 bytes). ' ...
        'Got %d bytes (0x%X).'], numel(mainRom), numel(mainRom));
end

if numel(smallRom) ~= SMALL_SIZE
    error(['Small ROM must be exactly 512 KiB (0x80000 bytes). ' ...
        'Got %d bytes (0x%X).'], numel(smallRom), numel(smallRom));
end

%% 3. Reconstruct the observed physical EPROM organization
%
% The 2 MiB ROM is split into two 1 MiB halves.
% Each 512 KiB ROM is repeated twice to fill a 1 MiB region.
mainFirstHalf  = mainRom(1:BANK_SIZE);
mainSecondHalf = mainRom(BANK_SIZE+1:MAIN_SIZE);
smallBank      = [smallRom; smallRom];

merged = [mainFirstHalf; ...
    smallBank; ...
    mainSecondHalf; ...
    smallBank];

%% 4. Verify generated image size
if numel(merged) ~= TARGET_SIZE
    error('Internal error: generated image is %d bytes, expected %d.', ...
        numel(merged), TARGET_SIZE);
end

%% 5. Write 4 MiB EPROM image
fidOut = fopen(outputMergedFile, 'wb');
if fidOut < 0
    error('Cannot open output file for writing: %s', outputMergedFile);
end

cleanupObj = onCleanup(@() fclose(fidOut));
fwrite(fidOut, merged, 'uint8');
clear cleanupObj;

%% 6. Verify output by reading it back
written = readBinary(outputMergedFile);

if numel(written) ~= TARGET_SIZE
    error('Output verification failed: output size is %d bytes.', numel(written));
end

if ~isequal(written, merged)
    error('Output verification failed: written data differs from generated data.');
end

outputCRC = computeCRC32(outputMergedFile);
fprintf('\nLayout written to %s:\n', outputMergedFile);
fprintf('  000000-0FFFFF : %s [main ROM bytes 000000-0FFFFF]\n', mainRomFile);
fprintf('  100000-1FFFFF : %s repeated twice\n', smallRomFile);
fprintf('  200000-2FFFFF : %s [main ROM bytes 100000-1FFFFF]\n', mainRomFile);
fprintf('  300000-3FFFFF : %s repeated twice\n', smallRomFile);
fprintf('\nMerged size : %d bytes (0x%X)\n', numel(written), numel(written));
fprintf('Merged CRC32: %08X\n', outputCRC);
fprintf('Verification : OK\n');
fprintf('============================================================\n');
end


function data = readBinary(filename)
% Read a binary file as a column vector of uint8.
fid = fopen(filename, 'rb');
if fid < 0
    error('Cannot open input file: %s', filename);
end

cleanupObj = onCleanup(@() fclose(fid));
data = fread(fid, Inf, '*uint8');
clear cleanupObj;

end
