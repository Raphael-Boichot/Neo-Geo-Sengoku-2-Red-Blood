function Color_picker()
    % Generate a 512x512 matrix
    % Columns (X): Hue
    % Rows (Y): Saturation and Value combination for Black -> White -> Colors
    width = 512; height = 512;
    
    % We create a vertical gradient: 0 = White, 0.5 = Saturated Colors, 1 = Black
    [H, Y] = meshgrid(linspace(0, 1, width), linspace(0, 1, height));
    
    % S and V logic to create White (bottom) -> Color (mid) -> Black (top)
    S = ones(height, width);
    V = ones(height, width);
    
    % This logic creates the specific transition:
    % Top rows (Y < 0.5): V scales from 0 to 1 (Black to Color)
    % Bottom rows (Y > 0.5): S scales from 1 to 0 (Color to White)
    mask_top = Y < 0.5;
    mask_bot = Y >= 0.5;
    
    V(mask_top) = Y(mask_top) * 2;
    S(mask_bot) = (1 - (Y(mask_bot) - 0.5) * 2);
    
    hsv_img = hsv2rgb(cat(3, H, S, V));

    fig = figure('Name', 'Neo Geo Color Inspector', 'NumberTitle', 'off', ...
                 'MenuBar', 'none', 'ToolBar', 'none', 'Units', 'pixels', ...
                 'Position', [100 100 650 620], 'Color', 'k');
    
    txt_display = uicontrol('Style', 'text', 'String', 'Inspect your colors', ...
        'Position', [50 550 550 50], 'FontSize', 14, 'FontWeight', 'bold', ...
        'ForegroundColor', 'w', 'BackgroundColor', 'k');
    
    ax = axes('Parent', fig, 'Position', [0.05 0.1 0.7 0.75], ...
              'Units', 'normalized', 'XColor', 'w', 'YColor', 'w');
    h_img = imshow(hsv_img, 'Parent', ax);
    
    swatch_ax = axes('Parent', fig, 'Position', [0.8 0.5 0.15 0.15], 'XColor', 'w', 'YColor', 'w');
    swatch_img = imshow(zeros(1,1,3), 'Parent', swatch_ax);
    title(swatch_ax, 'Selection', 'Color', 'w');
    
    set(fig, 'WindowButtonMotionFcn', @(src, event) update_info(ax, h_img, swatch_img, txt_display));
end

function update_info(ax, h_img, swatch_img, txt_display)
    cp = get(ax, 'CurrentPoint');
    x = round(cp(1,1)); y = round(cp(1,2));
    img_data = get(h_img, 'CData');
    [rows, cols, ~] = size(img_data);
    
    x = max(1, min(x, cols)); y = max(1, min(y, rows));
    
    rgb_float = squeeze(img_data(y, x, :))';
    rgb_255 = round(rgb_float * 255);
    
    set(swatch_img, 'CData', reshape(rgb_float, [1, 1, 3]));
    
    % 1. Convert 8-bit to 5-bit (0-31 range)
    r = floor(rgb_255(1) / 8);
    g = floor(rgb_255(2) / 8);
    b = floor(rgb_255(3) / 8);
    
    % 2. Extract the LSB (Dark bit) 
    % A common approach is to use the LSB of the Red channel, 
    % or define it based on total intensity.
    dark_bit = bitand(r, 1); 
    
    % 3. Mask the MSBs (bits 4-1 of the 5-bit value)
    r_msb = bitshift(r, -1);
    g_msb = bitshift(g, -1);
    b_msb = bitshift(b, -1);
    
    % 4. Pack into 16-bit format:
    % Bit 15: Dark bit
    % Bit 14: R0, Bit 13: G0, Bit 12: B0
    % Bits 11-8: R4-R1, Bits 7-4: G4-G1, Bits 3-0: B4-B1
    ng_hex = bitshift(dark_bit, 15) + ...
             bitshift(bitand(r, 1), 14) + ...
             bitshift(bitand(g, 1), 13) + ...
             bitshift(bitand(b, 1), 12) + ...
             bitshift(r_msb, 8) + ...
             bitshift(g_msb, 4) + ...
             bitshift(b_msb, 0);
    
    set(txt_display, 'String', sprintf('RGB: [%d, %d, %d] | Neo Geo: 0x%04X', ...
        rgb_255(1), rgb_255(2), rgb_255(3), ng_hex));
end