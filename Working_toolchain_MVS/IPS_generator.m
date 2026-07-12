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

fid = fopen(ipsFile, 'wb');
fwrite(fid, 'PATCH', 'char');

% 3. Identify and write changes
len = min(length(data1), length(data2));
diffs = find(data1(1:len) ~= data2(1:len));

i = 1;
while i <= length(diffs)
    startIdx = diffs(i) - 1;
    chunk = data2(diffs(i));

    while (i + 1 <= length(diffs)) && (diffs(i+1) == diffs(i) + 1)
        i = i + 1;
        chunk = [chunk; data2(diffs(i))];
    end

    fwrite(fid, [bitshift(startIdx, -16), bitand(bitshift(startIdx, -8), 255), bitand(startIdx, 255)], 'uint8');
    fwrite(fid, [bitshift(length(chunk), -8), bitand(length(chunk), 255)], 'uint8');
    fwrite(fid, chunk, 'uint8');
    i = i + 1;
end

fwrite(fid, 'EOF', 'char');
fclose(fid);
fprintf('IPS patch generated: %s\n', ipsFile);
end
