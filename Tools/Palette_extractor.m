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
all_labels = {}; % Store labels for each palette
paletteCount = 0;

% --- Font Definition ---
font.Chars = ['0':'9', 'A':'F', '_'];
font.Data = zeros(7, 5, 17);
font.Data(:,:,1) = [0,1,1,1,0; 1,0,0,0,1; 1,0,0,1,1; 1,0,1,0,1; 1,1,0,0,1; 1,0,0,0,1; 0,1,1,1,0]; % 0
font.Data(:,:,2) = [0,0,1,0,0; 0,1,1,0,0; 0,0,1,0,0; 0,0,1,0,0; 0,0,1,0,0; 0,0,1,0,0; 0,1,1,1,0]; % 1
font.Data(:,:,3) = [0,1,1,1,0; 1,0,0,0,1; 0,0,0,0,1; 0,0,1,1,0; 0,1,0,0,0; 1,0,0,0,0; 1,1,1,1,1]; % 2
font.Data(:,:,4) = [1,1,1,1,0; 0,0,0,0,1; 0,0,0,0,1; 0,1,1,1,0; 0,0,0,0,1; 0,0,0,0,1; 1,1,1,1,0]; % 3
font.Data(:,:,5) = [0,0,0,1,0; 0,0,1,1,0; 0,1,0,1,0; 1,0,0,1,0; 1,1,1,1,1; 0,0,0,1,0; 0,0,0,1,0]; % 4
font.Data(:,:,6) = [1,1,1,1,1; 1,0,0,0,0; 1,1,1,1,0; 0,0,0,0,1; 0,0,0,0,1; 1,0,0,0,1; 0,1,1,1,0]; % 5
font.Data(:,:,7) = [0,0,1,1,0; 0,1,0,0,0; 1,0,0,0,0; 1,1,1,1,0; 1,0,0,0,1; 1,0,0,0,1; 0,1,1,1,0]; % 6
font.Data(:,:,8) = [1,1,1,1,1; 0,0,0,0,1; 0,0,0,1,0; 0,0,1,0,0; 0,1,0,0,0; 0,1,0,0,0; 0,1,0,0,0]; % 7
font.Data(:,:,9) = [0,1,1,1,0; 1,0,0,0,1; 1,0,0,0,1; 0,1,1,1,1; 0,0,0,0,1; 0,0,0,0,1; 0,1,1,1,0]; % 8
font.Data(:,:,10)= [0,1,1,1,0; 1,0,0,0,1; 1,0,0,0,1; 0,1,1,1,1; 0,0,0,0,1; 0,0,0,1,0; 0,1,1,0,0]; % 9
font.Data(:,:,11)= [0,1,1,1,0; 1,0,0,0,1; 1,0,0,0,1; 1,1,1,1,1; 1,0,0,0,1; 1,0,0,0,1; 1,0,0,0,1]; % A
font.Data(:,:,12)= [1,1,1,1,0; 1,0,0,0,1; 1,0,0,0,1; 1,1,1,1,0; 1,0,0,0,1; 1,0,0,0,1; 1,1,1,1,0]; % B
font.Data(:,:,13)= [0,1,1,1,1; 1,0,0,0,0; 1,0,0,0,0; 1,0,0,0,0; 1,0,0,0,0; 1,0,0,0,0; 0,1,1,1,1]; % C
font.Data(:,:,14)= [1,1,1,1,0; 1,0,0,0,1; 1,0,0,0,1; 1,0,0,0,1; 1,0,0,0,1; 1,0,0,0,1; 1,1,1,1,0]; % D
font.Data(:,:,15)= [1,1,1,1,1; 1,0,0,0,0; 1,0,0,0,0; 1,1,1,1,0; 1,0,0,0,0; 1,0,0,0,0; 1,1,1,1,1]; % E
font.Data(:,:,16)= [1,1,1,1,1; 1,0,0,0,0; 1,0,0,0,0; 1,1,1,1,0; 1,0,0,0,0; 1,0,0,0,0; 1,0,0,0,0]; % F
font.Data(:,:,17)= [0,0,0,0,0; 0,0,0,0,0; 0,0,0,0,0; 0,0,0,0,0; 0,0,0,0,0; 0,0,0,0,0; 1,1,1,1,1]; % _

while ~feof(fin)
    line1 = fgetl(fin); line2 = fgetl(fin);
    if ~ischar(line1) || ~ischar(line2), break; end
    
    words1 = regexp(line1, '[0-9A-Fa-f]{4}', 'match');
    words2 = regexp(line2, '[0-9A-Fa-f]{4}', 'match');
    
    if numel(words1) >= 9 && numel(words2) >= 9
        addr1 = regexp(line1, '^([0-9A-Fa-f]+):', 'tokens');
        addr2 = regexp(line2, '^([0-9A-Fa-f]+):', 'tokens');
        addrName = [addr1{1}{1}, '_', addr2{1}{1}];
        
        rawHex = [words1(2:9), words2(2:9)];
        
        % Store label: Address + "_" + First Word
        all_labels{end+1} = [addrName, '_', upper(rawHex{1})];
        
        % Write M and TXT...
        fprintf(foutM, 'address_%s = [', addrName);
        for k = 1:numel(rawHex)
            fprintf(foutM, '0x%s%s', upper(rawHex{k}), ifThenElse(k < numel(rawHex), ", ", ""));
        end
        fprintf(foutM, '];\n');
        
        rgbValues = zeros(16, 3);
        for i = 1:16
            c = uint16(hex2dec(rawHex{i}));
            dark = bitget(c, 16);
            r = bitshift(bitand(c, hex2dec('0F00')), -8);
            g = bitshift(bitand(c, hex2dec('00F0')), -4);
            b = bitand(c, hex2dec('000F'));
            rgbValues(i,:) = uint8(round(double([bitor(bitshift(r,1),dark), bitor(bitshift(g,1),dark), bitor(bitshift(b,1),dark)])*255/31));
        end
        
        fprintf(foutT, 'Palette at %s:\nIdx | R | G | B\n', addrName);
        for i = 1:16, fprintf(foutT, '%02d  | %3d | %3d | %3d\n', i-1, rgbValues(i,1), rgbValues(i,2), rgbValues(i,3)); end
        fprintf(foutT, '\n');
        
        all_rgb = [all_rgb; rgbValues];
        paletteCount = paletteCount + 1;
    end
end

fclose(fin); fclose(foutM); fclose(foutT);

% --- PNG Generation ---
img = zeros(paletteCount * 32, 16 * 32, 3, 'uint8');
for p = 1:paletteCount
    % Draw colors
    for i = 1:16
        img(((p-1)*32 + 1) : (p*32), ((i-1)*32 + 1) : (i*32), :) = repmat(reshape(all_rgb((p-1)*16 + i, :), [1, 1, 3]), [32, 32, 1]);
    end
    
    % Draw Labels
    str = all_labels{p};
    startX = 6; startY = ((p - 1) * 32) + 12;
    img(startY-3:startY+9, startX-2:startX+(length(str)*6)+4, :) = 20;
    for c = 1:length(str)
        idx = find(font.Chars == str(c), 1);
        if ~isempty(idx)
            glyph = font.Data(:,:,idx);
            for r_f = 1:7, for c_f = 1:5
                if glyph(r_f, c_f) == 1, img(startY+r_f-1, startX+c_f-1, :) = 255; end
            end, end
        end
        startX = startX + 6;
    end
end

imwrite(img, outputPng);
disp('Parsing complete.');

function val = ifThenElse(condition, trueVal, falseVal)
    if condition, val = trueVal; else, val = falseVal; end
end