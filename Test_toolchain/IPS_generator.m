function IPS_generator(originalFile,modifiedFile,ipsFile)
% Read files
f1 = fopen(originalFile, 'rb'); data1 = fread(f1, inf, 'uint8'); fclose(f1);
f2 = fopen(modifiedFile, 'rb'); data2 = fread(f2, inf, 'uint8'); fclose(f2);

fid = fopen(ipsFile, 'wb');

% Write IPS Header
fwrite(fid, 'PATCH', 'char');

% Identify changes
len = min(length(data1), length(data2));
diffs = find(data1(1:len) ~= data2(1:len));

% Group consecutive changes into records
i = 1;
while i <= length(diffs)
    startIdx = diffs(i) - 1; % 0-based offset
    chunk = [data2(diffs(i))];

    % Look for contiguous differences
    while (i + 1 <= length(diffs)) && (diffs(i+1) == diffs(i) + 1)
        i = i + 1;
        chunk = [chunk; data2(diffs(i))];
    end

    % Write Record Offset (3 bytes, Big Endian)
    offsetBytes = [bitshift(startIdx, -16); bitand(bitshift(startIdx, -8), 255); bitand(startIdx, 255)];
    fwrite(fid, offsetBytes, 'uint8');

    % Write Record Size (2 bytes, Big Endian)
    sizeVal = length(chunk);
    sizeBytes = [bitshift(sizeVal, -8); bitand(sizeVal, 255)];
    fwrite(fid, sizeBytes, 'uint8');

    % Write Data
    fwrite(fid, chunk, 'uint8');
    i = i + 1;
end

% Write EOF
fwrite(fid, 'EOF', 'char');
fclose(fid);
fprintf('IPS patch generated: %s\n', ipsFile);
