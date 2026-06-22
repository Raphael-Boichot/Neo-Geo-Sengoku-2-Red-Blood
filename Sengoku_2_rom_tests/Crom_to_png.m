clear
clc

%% Files
oddRomFile  = '040-c1.c1';
evenRomFile = '040-c2.c2';
outputPng   = 'Tileset.png';

%% User palette (Neo Geo format)
palette = [0x0010,0x7810,0x0C74,0x5FC9,0x5409,0x1A0F,0x1F9F,0x0800,0x0C00,0x4F93,0x0666,0x7AAA,0x0EEE,0x7334,0x4500,0x7111];
TILES_PER_ROW = 17;
MAGENTA = uint8([255 0 255]);

%% Read ROMs
fid = fopen(oddRomFile,'rb');
odd = fread(fid,Inf,'uint8=>uint8');
fclose(fid);
fid = fopen(evenRomFile,'rb');
even = fread(fid,Inf,'uint8=>uint8');
fclose(fid);
if numel(odd) ~= numel(even)
    error('ROM sizes differ.');
end
numTiles = numel(odd)/64;
fprintf('Tiles : %d\n',numTiles);

%% Output image
tileW = 16;
tileH = 16;
rows = ceil(numTiles/TILES_PER_ROW);
sheet = zeros(rows*tileH,TILES_PER_ROW*tileW,3,'uint8');
sheet(:,:,1)=255;
sheet(:,:,2)=0;
sheet(:,:,3)=255;

%% Convert NeoGeo palette to RGB
rgbPalette = zeros(16,3,'uint8');
for i=1:16
    c = uint16(palette(i));
    dark = bitget(c,16);
    r = bitshift(bitand(c,hex2dec('0F00')),-8);
    g = bitshift(bitand(c,hex2dec('00F0')),-4);
    b = bitand(c,hex2dec('000F'));
    r = bitor(bitshift(r,1),dark);
    g = bitor(bitshift(g,1),dark);
    b = bitor(bitshift(b,1),dark);
    rgbPalette(i,:) = uint8(round(double([r g b])*255/31));
end

%% Block arrangement
blockX = [0 0 8 8];
blockY = [0 8 0 8];

%% Decode
for tile=0:numTiles-1
    tilePixels=zeros(16,16,'uint8');
    oddBase=tile*64;
    evenBase=tile*64;
    for block=0:3
        xOfs=blockX(block+1);
        yOfs=blockY(block+1);
        blockOffset=block*16;
        for row=0:7
            idx=blockOffset+row*2;
            bp0=odd(oddBase+idx+1);
            bp1=odd(oddBase+idx+2);
            bp2=even(evenBase+idx+1);
            bp3=even(evenBase+idx+2);
            for pixel=0:7
                bitPos=7-pixel;
                colour = ...
                    bitget(bp0,bitPos+1) + ...
                    bitshift(bitget(bp1,bitPos+1),1) + ...
                    bitshift(bitget(bp2,bitPos+1),2) + ...
                    bitshift(bitget(bp3,bitPos+1),3);
                tilePixels(yOfs+row+1,xOfs+pixel+1)=uint8(colour);
            end
        end
    end
    tx=mod(tile,TILES_PER_ROW);
    ty=floor(tile/TILES_PER_ROW);
    dstX=tx*16;
    dstY=ty*16;
    for y=1:16
        for x=1:16
            c=tilePixels(y,x);
            if c==0
                rgb=MAGENTA;
            else
                rgb=rgbPalette(double(c)+1,:);
            end
            sheet(dstY+y,dstX+x,:)=reshape(rgb,[1 1 3]);
        end
    end
end
imwrite(sheet,outputPng);

%% Generate Palette Image (16 squares, 32x32 pixels each)
palW = 32; 
palH = 32;
palSheet = zeros(palH, 16 * palW, 3, 'uint8');

for i = 0:15
    % Retrieve the RGB color from the already processed rgbPalette
    rgb = rgbPalette(i+1, :);
    
    % Fill the 32x32 square
    startCol = i * palW + 1;
    endCol = (i + 1) * palW;
    palSheet(1:palH, startCol:endCol, 1) = rgb(1);
    palSheet(1:palH, startCol:endCol, 2) = rgb(2);
    palSheet(1:palH, startCol:endCol, 3) = rgb(3);
end

% Save the palette visualization
imwrite(palSheet, 'Palette.png');


fprintf('Done.\n');