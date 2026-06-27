% Palette_extractor_final.m
clear; clc;

inputFile  = 'Sengoku2_dump.bin';
outputM    = 'parsed_dump_exact.m';
outputTxt  = 'Palettes_Data.txt';
outputPng  = 'All_Palettes.png';

fin  = fopen(inputFile, 'rt');
foutM = fopen(outputM, 'wt');
foutT = fopen(outputTxt, 'wt');

if fin == -1, error('Could not open file: %s', inputFile); end

all_rgb = []; 
paletteCount = 0;

while ~feof(fin)
    line1 = fgetl(fin); line2 = fgetl(fin);
    if ~ischar(line1) || ~ischar(line2), break; end
    
    words1 = regexp(line1, '[0-9A-Fa-f]{4}', 'match');
    words2 = regexp(line2, '[0-9A-Fa-f]{4}', 'match');
    
    if numel(words1) >= 9 && numel(words2) >= 9
        % Extract address for variable name
        addr1 = regexp(line1, '^([0-9A-Fa-f]+):', 'tokens');
        addr2 = regexp(line2, '^([0-9A-Fa-f]+):', 'tokens');
        addrName = [addr1{1}{1}, '_', addr2{1}{1}];
        
        % Data includes the 8 words from each line (excluding the address at index 1)
        rawHex = [words1(2:9), words2(2:9)];
        
        % 1. Write HEX to .m file in requested format
        fprintf(foutM, 'address_%s = [', addrName);
        for k = 1:numel(rawHex)
            fprintf(foutM, '0x%s%s', upper(rawHex{k}), ...
                char(ifThenElse(k < numel(rawHex), ", ", "")));
        end
        fprintf(foutM, '];\n');
        
        % 2. Calculate RGB for PNG/TXT
        rgbValues = zeros(16, 3);
        for i = 1:16
            c = uint16(hex2dec(rawHex{i}));
            dark = bitget(c, 16);
            r = bitshift(bitand(c, hex2dec('0F00')), -8);
            g = bitshift(bitand(c, hex2dec('00F0')), -4);
            b = bitand(c, hex2dec('000F'));
            rgbValues(i,:) = uint8(round(double([bitor(bitshift(r,1),dark), ...
                                                 bitor(bitshift(g,1),dark), ...
                                                 bitor(bitshift(b,1),dark)])*255/31));
        end
        
        % Write to TXT
        fprintf(foutT, 'Palette at %s:\nIdx | R | G | B\n', addrName);
        for i = 1:16, fprintf(foutT, '%02d  | %3d | %3d | %3d\n', i-1, rgbValues(i,1), rgbValues(i,2), rgbValues(i,3)); end
        fprintf(foutT, '\n');
        
        all_rgb = [all_rgb; rgbValues];
        paletteCount = paletteCount + 1;
    end
end

% Generate PNG
img = zeros(paletteCount * 32, 16 * 32, 3, 'uint8');
for p = 1:paletteCount
    for i = 1:16
        y_range = ((p-1)*32 + 1) : (p*32);
        x_range = ((i-1)*32 + 1) : (i*32);
        img(y_range, x_range, :) = repmat(reshape(all_rgb((p-1)*16 + i, :), [1, 1, 3]), [32, 32, 1]);
    end
end
imwrite(img, outputPng);

fclose(fin); fclose(foutM); fclose(foutT);
disp('Parsing complete. Saved to parsed_dump_exact.m, Palettes_Data.txt, and All_Palettes.png');

% Helper function for clean string output
function val = ifThenElse(condition, trueVal, falseVal)
    if condition, val = trueVal; else, val = falseVal; end
end