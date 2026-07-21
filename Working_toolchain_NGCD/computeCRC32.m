function crc = computeCRC32(filename)
    persistent table
    if isempty(table)
        table = zeros(256, 1, 'uint32');
        poly = uint32(3988292384); % reversed polynomial 0xEDB88320
        for i = 0:255
            c = uint32(i);
            for k = 1:8
                if bitand(c, 1)
                    c = bitxor(bitshift(c, -1), poly);
                else
                    c = bitshift(c, -1);
                end
            end
            table(i+1) = c;
        end
    end

    fid = fopen(filename, 'rb');
    data = fread(fid, inf, 'uint8=>uint32');
    fclose(fid);

    crc = uint32(4294967295); % 0xFFFFFFFF
    for i = 1:length(data)
        idx = bitand(bitxor(crc, data(i)), 255) + 1;
        crc = bitxor(bitshift(crc, -8), table(idx));
    end
    crc = bitxor(crc, uint32(4294967295));
end