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

body = uint8([]);

if ~isempty(diffs)
    runBreaks = find(diff(diffs) ~= 1);
    runStarts = [1; runBreaks + 1];
    runEnds   = [runBreaks; length(diffs)];
    
    firstDiffs = diffs(runStarts);
    lastDiffs  = diffs(runEnds);
    startIdxs  = firstDiffs - 1;
    chunkLens  = (lastDiffs - firstDiffs) + 1;
    
    % Handle standard IPS chunks (chunkLen <= 65535) and large run optimizations
    % We build cell arrays of blocks and concatenate once using flat vector indexing
    n_runs = length(runStarts);
    cellBuffers = cell(n_runs, 1);
    
    for r = 1:n_runs
        sIdx = startIdxs(r);
        cLen = chunkLens(r);
        chunkData = data2(firstDiffs(r):lastDiffs(r));
        
        % Check for RLE chunk format support if chunkLen > 65535, 
        % otherwise standard 5-byte header + data chunk formatting:
        header = [ ...
            uint8(bitshift(sIdx, -16)); ...
            uint8(bitand(bitshift(sIdx, -8), 255)); ...
            uint8(bitand(sIdx, 255)); ...
            uint8(bitshift(cLen, -8)); ...
            uint8(bitand(cLen, 255)) ...
        ];
        
        cellBuffers{r} = [header; uint8(chunkData(:))];
    end
    
    body = vertcat(cellBuffers{:});
end

% 5. Assemble the entire file (header + body + footer) as a single
% in-memory uint8 buffer, doing exactly one single disk write operation.
patchHeader = uint8('PATCH');
patchFooter = uint8('EOF');
patch = [patchHeader(:); body(:); patchFooter(:)];

fid = fopen(ipsFile, 'wb');
fwrite(fid, patch, 'uint8');
fclose(fid);

fprintf('IPS patch generated: %s\n', ipsFile);
end