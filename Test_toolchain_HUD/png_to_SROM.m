function png_to_SROM(pngFile, paletteFile, outputFile)
    % 1. Load PNG and Palette
    img = imread(pngFile);
    [~, ~, alpha] = imread(pngFile);
    rgbPalette = loadPalette(paletteFile); % Parses exactly 16 entries (00-15)
    
    [H, W, ~] = size(img);
    sheet_indices = zeros(H, W, 'uint8');

    % 2. Map PNG to Palette Indices (Masked Classification)
    % Index 0 is transparent ONLY if alpha < 128
    isTransparent = (alpha < 128); 
    
    for k = 0:15
        color = rgbPalette(k+1, :);
        mask = (img(:,:,1) == color(1)) & (img(:,:,2) == color(2)) & (img(:,:,3) == color(3));
        mask = mask & ~isTransparent;
        sheet_indices(mask) = k;
    end

    % 3. Inverse Nibble Map
    xoff = [33, 32, 49, 48, 1, 0, 17, 16]; 
    yoff = [0, 2, 4, 6, 8, 10, 12, 14];
    numTiles = (H/8) * (W/8);
    sromData = zeros(numTiles * 32, 1, 'uint8');

    % 4. Packing (Direct 1:1 mapping of indices 0-15)
    for tile = 0:numTiles-1
        tx = mod(tile, 32); ty = floor(tile/32);
        tileImg = sheet_indices(ty*8+(1:8), tx*8+(1:8));
        
        encodedTile = zeros(32, 1, 'uint8');
        for r = 1:8
            for c = 1:8
                addr = yoff(r) + xoff(c);
                byteIdx = floor(addr / 2);
                val = tileImg(r,c);
                
                if mod(addr, 2) == 1
                    encodedTile(byteIdx + 1) = bitor(encodedTile(byteIdx + 1), bitand(val, 15));
                else
                    encodedTile(byteIdx + 1) = bitor(encodedTile(byteIdx + 1), bitshift(val, 4));
                end
            end
        end
        sromData(tile*32+(1:32)) = encodedTile;
    end

    % 5. Save and Call CRC32
    fid = fopen(outputFile, 'wb'); fwrite(fid, sromData, 'uint8'); fclose(fid);
    fprintf('Saved %s.\n', outputFile);
    fprintf('Destination %s (CRC32: %08X)\n', outputFile, computeCRC32(outputFile));
end

% --- Helper: Parse the palette.txt file (16 entries: 00-15) ---
function palette = loadPalette(filename)
    fid = fopen(filename, 'r');
    for i=1:4, fgetl(fid); end % Skip header lines
    palette = zeros(16, 3);
    for i = 1:16
        line = fgetl(fid);
        parts = strsplit(line, '|');
        palette(i, 1) = str2double(parts{2});
        palette(i, 2) = str2double(parts{3});
        palette(i, 3) = str2double(parts{4});
    end
    fclose(fid);
end