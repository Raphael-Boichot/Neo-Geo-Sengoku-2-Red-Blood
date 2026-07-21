function IPS_generator(originalFile, modifiedFile, ipsFile)
% 1. Calculate and display CRCs
crcOrig = computeCRC32(originalFile);
crcMod = computeCRC32(modifiedFile);
fprintf('File: %s | Original CRC32: %08X | Modified CRC32: %08X\n', ...
    originalFile, crcOrig, crcMod);

% 2. Setup IPS generation
if ~exist('.\IPS_scripts\', 'dir'), mkdir('.\IPS_scripts\'); end

f1 = fopen(originalFile, 'rb'); data1 = fread(f1, inf, 'uint8'); fclose(f1);
f2 = fopen(modifiedFile, 'rb'); data2 = fread(f2, inf, 'uint8'); fclose(f2);

% 3. Identify changes (vectorized run detection)
len = min(length(data1), length(data2));
diffs = find(data1(1:len) ~= data2(1:len));

% 4. Build the entire patch body in memory first, then do a single
% fwrite at the end. Many small fwrite calls (one header + one chunk
% per run) is what makes this slow when there are thousands of runs:
% each call carries fixed interpreter/syscall overhead in Octave that
% dwarfs the actual bytes being written. Concatenating into one buffer
% and writing once amortizes that overhead to effectively zero.
chunks = {};
if ~isempty(diffs)
    runBreaks = find(diff(diffs) ~= 1);
    runStarts = [1; runBreaks + 1];
    runEnds   = [runBreaks; length(diffs)];

    chunks = cell(length(runStarts), 1);
    for r = 1:length(runStarts)
        firstDiffIdx = diffs(runStarts(r));
        lastDiffIdx  = diffs(runEnds(r));
        startIdx = firstDiffIdx - 1;

        chunk = data2(firstDiffIdx:lastDiffIdx);
        chunkLen = length(chunk);

        header = [bitshift(startIdx, -16); bitand(bitshift(startIdx, -8), 255); bitand(startIdx, 255); ...
                  bitshift(chunkLen, -8); bitand(chunkLen, 255)];

        chunks{r} = [header; chunk(:)];
    end
end

body = vertcat(chunks{:});

% 5. Assemble the entire file (header + body + footer) as a single
% in-memory uint8 buffer first, then do exactly one fwrite. This avoids
% any per-call overhead beyond the single write itself, and means the
% full patch content exists in memory before anything touches disk.
patchHeader = uint8('PATCH');
patchFooter = uint8('EOF');
patch = [patchHeader(:); uint8(body(:)); patchFooter(:)];

fid = fopen(ipsFile, 'wb');
fwrite(fid, patch, 'uint8');
fclose(fid);

fprintf('IPS patch generated: %s\n', ipsFile);
end