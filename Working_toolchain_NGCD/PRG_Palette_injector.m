function [data]=PRG_Palette_injector(data, palette_old, palette_new)

% 3. Prepare Patterns
get_be_bytes = @(p) reshape([bitshift(p, -8); bitand(p, 255)], 1, []);
search_pattern = get_be_bytes(palette_old);
replace_pattern = get_be_bytes(palette_new);

% 4. Search and Inject (Vectorized, fast)
if length(search_pattern) == length(replace_pattern)
    data_row = data(:)';
    pattern_len = length(search_pattern);

    % Fast vectorized byte-pattern search via strfind
    % (uint8 values map 1:1 to char codes, so this is safe for binary data)
    idx = strfind(char(data_row), char(search_pattern));

    if isempty(idx)
        error('Palette not found in file.');
    end

    % Apply replacement at every match location
    for i = 1:length(idx)
        data_row(idx(i) : idx(i) + pattern_len - 1) = replace_pattern;
    end
    data = data_row(:);
    numInjections = length(idx);
    fprintf('Palette pattern found and injected at %d location(s).\n', numInjections);
else
    error('This fast version requires palettes of the same length.');
end
