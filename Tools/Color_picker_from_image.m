function Color_picker_from_image()
    % 1. Load the image template
    img = imread('matlab_jet_labelbar.png');
    
    % Ensure image is RGB (if grayscale, convert to RGB)
    if size(img, 3) == 1
        img = cat(3, img, img, img);
    end

    % Setup Figure
    fig = figure('Name', 'Neo Geo Color Inspector (Template Mode)', ...
                 'NumberTitle', 'off', 'MenuBar', 'none', 'ToolBar', 'none', ...
                 'Units', 'pixels', 'Position', [100 100 650 620], 'Color', 'k');
    
    txt_display = uicontrol('Style', 'text', 'String', 'Select a color', ...
        'Position', [50 550 550 50], 'FontSize', 14, 'FontWeight', 'bold', ...
        'ForegroundColor', 'w', 'BackgroundColor', 'k');
    
    ax = axes('Parent', fig, 'Position', [0.05 0.1 0.7 0.75], ...
              'Units', 'normalized', 'XColor', 'w', 'YColor', 'w');
    h_img = imshow(img, 'Parent', ax);
    
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
    
    % Clamp coordinates
    x = max(1, min(x, cols)); y = max(1, min(y, rows));
    
    % Extract raw pixel data
    raw_pixel = double(squeeze(img_data(y, x, :)))';
    
    % Normalize RGB_255 correctly based on image class
    if isa(img_data, 'uint8')
        rgb_255 = raw_pixel;
    else
        % If image is double/single range 0-1
        rgb_255 = round(raw_pixel * 255);
    end
    
    % Update Swatch
    set(swatch_img, 'CData', reshape(rgb_255 / 255, [1, 1, 3]));
    
    % Neo Geo Conversion Logic
    % 1. Convert 8-bit to 5-bit (0-31 range)
    r = floor(rgb_255(1) / 8);
    g = floor(rgb_255(2) / 8);
    b = floor(rgb_255(3) / 8);
    
    % 2. Extract the LSB (Dark bit) 
    dark_bit = bitand(r, 1); 
    
    % 3. Mask the MSBs (bits 4-1 of the 5-bit value)
    r_msb = bitshift(r, -1);
    g_msb = bitshift(g, -1);
    b_msb = bitshift(b, -1);
    
    % 4. Pack into 16-bit format:
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