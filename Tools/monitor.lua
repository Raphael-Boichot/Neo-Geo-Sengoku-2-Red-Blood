print("--------------------------------------------------")
print("Neo Geo Ultra-Compact Color Ribbon Monitor Active")
print("--------------------------------------------------")

local main_mem = nil
local frame_counter = 0  -- Global frame counter for the snapshot routine

local function get_program_space()
    local cpu = manager.machine.devices[":maincpu"]
    if cpu and cpu.spaces["program"] then
        return cpu.spaces["program"]
    end
    return nil
end

-- Official NeoGeoDev Wiki 16-bit color decoder
local function neogeo_to_argb(raw_word)
    local dark_bit = (raw_word >> 15) & 1

    local r0 = (raw_word >> 14) & 1
    local g0 = (raw_word >> 13) & 1
    local b0 = (raw_word >> 12) & 1

    if r0 == 0 then r0 = dark_bit end
    if g0 == 0 then g0 = dark_bit end
    if b0 == 0 then b0 = dark_bit end

    local r4_1 = (raw_word >> 8) & 0x0F
    local g4_1 = (raw_word >> 4) & 0x0F
    local b4_1 = raw_word & 0x0F

    local r5 = (r4_1 << 1) | r0
    local g5 = (g4_1 << 1) | g0
    local b5 = (b4_1 << 1) | b0

    local r8 = math.floor((r5 / 31.0) * 255)
    local g8 = math.floor((g5 / 31.0) * 255)
    local b8 = math.floor((b5 / 31.0) * 255)

    return (0xFF << 24) | (r8 << 16) | (g8 << 8) | b8
end

emu.register_frame_done(function()
    frame_counter = frame_counter + 1  -- Increment counter every frame

    if not main_mem then
        main_mem = get_program_space()
        if not main_mem then return end
    end

    local active_palette_flags = {}
    for p = 0, 255 do active_palette_flags[p] = false end

    -- Fast scan of the active sprite allocation list in Work RAM
    for addr = 0x100000, 0x107F00, 8 do
        local status_word = main_mem:read_u16(addr)
        local attr_word   = main_mem:read_u16(addr + 2)
        local x_pos_word  = main_mem:read_u16(addr + 4)
        local y_pos_word  = main_mem:read_u16(addr + 6)

        if status_word > 0 and status_word ~= 0xFFFF then
            local raw_x = x_pos_word & 0x1FF
            local raw_y = y_pos_word & 0x1FF
            
            if raw_x > 0 and raw_x < 320 and raw_y > 0 and raw_y < 224 then
                local palette_id = (attr_word >> 8) & 0xFF
                active_palette_flags[palette_id] = true
            end
        end
    end

    for _, screen in pairs(manager.machine.screens) do
        if screen then
            -- Ultra low-profile minimal header
            screen:draw_text(10, 4, "68K ADDR  PALETTES", 0xff00ff00, 0xbb000000)
            
            local y_offset = 12
            local lines_printed = 0
            
            -- Swatch dimensions optimized for dense merging
            local swatch_w = 6
            local swatch_h = 5
            local start_x_swatches = 65

            for pal_row = 0, 255 do
                if active_palette_flags[pal_row] == true then
                    local absolute_68k_addr = 0x400000 + (pal_row * 0x20)
                    
                    -- Render address tag
                    local addr_str = string.format("0x%06X:", absolute_68k_addr)
                    screen:draw_text(10, y_offset - 1, addr_str, 0xffffffff, 0xaa000000)
                    
                    for color_col = 0, 15 do
                        local color_word_addr = absolute_68k_addr + (color_col * 2)
                        local raw_color_hex = main_mem:read_u16(color_word_addr) or 0x0000
                        
                        local draw_color = neogeo_to_argb(raw_color_hex)
                        
                        -- Removing the blank padding multiplier merges the chips seamlessly
                        local box_x1 = start_x_swatches + (color_col * swatch_w)
                        local box_y1 = y_offset
                        local box_x2 = box_x1 + swatch_w
                        local box_y2 = box_y1 + swatch_h
                        
                        screen:draw_box(box_x1, box_y1, box_x2, box_y2, draw_color, draw_color)
                    end
                    
                    -- Vertical stride dropped to 6 pixels for maximum text compression
                    y_offset = y_offset + 6 
                    lines_printed = lines_printed + 1
                    
                    if lines_printed >= 32 then break end
                end
            end
        end
    end

    -- Snapshot routine: Triggers every 20 frames using the standard MAME video system
    if frame_counter % 20 == 0 then
        manager.machine.video:snapshot()
    end
end)