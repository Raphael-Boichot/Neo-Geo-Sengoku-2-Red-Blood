print("--------------------------------------------------")
print("Neo Geo Engine - Real-Time Tracking + Capture Engine")
print("--------------------------------------------------")

local main_mem = nil
local frame_counter = 0

local function get_program_space()
    local cpu = manager.machine.devices[":maincpu"]
    if cpu and cpu.spaces["program"] then
        return cpu.spaces["program"]
    end
end

--------------------------------------------------
-- SAFE VRAM READ HELPER
--------------------------------------------------
local function read_vram(addr)
    main_mem:write_u16(0x3C0000, addr)
    return main_mem:read_u16(0x3C0002) or 0
end

--------------------------------------------------
-- OFFICIAL NEOGEODEV WIKI 16-BIT COLOR DECODER
--------------------------------------------------
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
    frame_counter = frame_counter + 1
    if frame_counter < 300 then return end

    if not main_mem then
        main_mem = get_program_space()
        if not main_mem then return end
    end

    --------------------------------------------------
    -- REAL-TIME DATA SCAN
    --------------------------------------------------
    local current_sprites = {}
    local current_palettes = {}
    local found_palettes = {}
    
    local active_x = 0
    local active_y = 0

    for sprite_id = 1, 380 do
        local scb3_word = read_vram(0x8200 + (sprite_id - 1))
        local scb4_word = read_vram(0x8400 + (sprite_id - 1))

        local tile_count = scb3_word & 0x3F
        local is_linked = ((scb3_word >> 6) & 1) == 1
        local y_reg_val = (scb3_word >> 7) & 0x1FF

        if is_linked then
            if #current_sprites > 0 then
                active_x = current_sprites[#current_sprites].x1 + 16
            else
                active_x = active_x + 16
            end
        else
            active_x = (scb4_word >> 7)
            local y = (scb3_word >> 7) & 0x1FF
            if y > 255 then y = y - 512 end
            active_y = 496 - y
        end

        if tile_count > 0 and tile_count <= 32 and y_reg_val < 0x1F0 then
            local hardware_palette_index = 0
            local scb1_base = (sprite_id - 1) * 64
            
            for t = 0, (tile_count - 1) do
                local scb1_attr = read_vram(scb1_base + (t * 2) + 1)
                local check_pal = (scb1_attr >> 8) & 0xFF
                if check_pal > 0 then
                    hardware_palette_index = check_pal
                    break
                end
            end
            
            if hardware_palette_index == 0 then
                hardware_palette_index = (read_vram(scb1_base + 1) >> 8) & 0xFF
            end

            local palette_ram_addr = 0x400000 + (hardware_palette_index * 32)
            local color_zero_word = main_mem:read_u16(palette_ram_addr)

            local base_x = active_x
            if base_x > 320 then base_x = base_x - 512 end
            local base_y = active_y
            if base_y > 224 then base_y = base_y - 512 end

            if (base_x + 16) > 0 and base_x < 320 and (base_y + 16) > 0 and base_y < 224 then
                found_palettes[hardware_palette_index] = true
                table.insert(current_sprites, {
                    x1 = base_x, y1 = base_y,
                    text = string.format("0x%02X", color_zero_word & 0xFF)
                })
            end
        end
    end

    for pal_idx in pairs(found_palettes) do
        table.insert(current_palettes, pal_idx)
    end
    table.sort(current_palettes)

    --------------------------------------------------
    -- RENDER ONSCREEN GRAPHICS
    --------------------------------------------------
    for _, screen in pairs(manager.machine.screens) do
        if screen then
            -- Sprite Labels: Black text on Cyan background (Aligned to x1, y1)
            for _, spr in ipairs(current_sprites) do
                screen:draw_box(spr.x1-2, spr.y1, spr.x1 + 16, spr.y1 + 8, 0xFF00FFFF, 0xFF00FFFF)
                screen:draw_text(spr.x1, spr.y1, spr.text, 0xFF000000)
            end

            -- Palette matrix: Black text on Cyan background
            local start_x = 4
            local start_y = 4
            local row_height = 8   
            local square_size = 4  

            for row_idx, pal_idx in ipairs(current_palettes) do
                local grid_y = start_y + ((row_idx - 1) * row_height)
                screen:draw_box(start_x-2, grid_y, start_x + 16, grid_y + 8, 0xFF00FFFF, 0xFF00FFFF)
                screen:draw_text(start_x, grid_y, string.format("0x%02X:", pal_idx), 0xFF000000)

                for color_idx = 0, 15 do
                    local color_word = main_mem:read_u16(0x400000 + (pal_idx * 32) + (color_idx * 2))
                    local draw_color = neogeo_to_argb(color_word)
                    local sq_x1 = start_x + 22 + (color_idx * square_size)
                    local sq_y1 = grid_y + 1
                    local sq_x2 = sq_x1 + (square_size - 1)
                    local sq_y2 = sq_y1 + (square_size * 1.5)
                    screen:draw_box(sq_x1, sq_y1, sq_x2, sq_y2, draw_color, draw_color)
                end
            end
        end
    end

    if frame_counter % 60 == 0 then
        manager.machine.video:snapshot()
    end
end)