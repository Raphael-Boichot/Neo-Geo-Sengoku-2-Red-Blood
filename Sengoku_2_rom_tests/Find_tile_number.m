% Prompt the user for coordinates
x = 266;
y = 42;

% Constants
TILE_SIZE = 16;
TILES_PER_ROW = 32;

% Calculate tile number (assuming 0-indexed x,y input)
% If your input is 1-indexed (e.g. 1-16), subtract 1 from x and y first.
tileIdx = floor(y / TILE_SIZE) * TILES_PER_ROW + floor(x / TILE_SIZE);

% Display result
fprintf('The tile number is: %d\n', tileIdx);