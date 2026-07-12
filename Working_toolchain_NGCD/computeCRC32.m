function crc = computeCRC32(filename)
    % Efficient CRC32 implementation using a Look-Up Table (LUT)
    persistent crc32Table;
    if isempty(crc32Table)
        poly = uint32(hex2dec('EDB88320'));
        crc32Table = zeros(256, 1, 'uint32');
        for i = 0:255
            c = uint32(i);
            for j = 1:8
                if bitand(c, 1)
                    c = bitxor(bitshift(c, -1), poly);
                else
                    c = bitshift(c, -1);
                end
            end
            crc32Table(i+1) = c;
        end
    end

    fid = fopen(filename, 'rb');
    data = fread(fid, inf, 'uint8');
    fclose(fid);

    crc = uint32(hex2dec('FFFFFFFF'));
    for i = 1:length(data)
        idx = bitand(bitxor(crc, uint32(data(i))), 255) + 1;
        crc = bitxor(bitshift(crc, -8), crc32Table(idx));
    end
    crc = bitxor(crc, uint32(hex2dec('FFFFFFFF')));
end