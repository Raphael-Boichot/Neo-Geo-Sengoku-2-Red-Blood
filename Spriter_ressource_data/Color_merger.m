% 1. Load and prepare the image
img_orig = im2double(imread('Sword_guard_main.png'));
[h, w, c] = size(img_orig);
pixels = reshape(img_orig, [], 3);

% 2. Extract initial unique colors and counts
[unique_colors, ~, idx] = unique(pixels, 'rows');
counts = histcounts(idx, 1:size(unique_colors, 1)+1)';

fprintf('Initial number of colors: %d\n', size(unique_colors, 1));

% 3. Target: Number of colors to reach (e.g., 2)
target_colors = 16; 

% 4. Iteratively merge the two closest colors
while size(unique_colors, 1) > target_colors
    
    % Calculate distance matrix between all unique colors
    dist_matrix = pdist2(unique_colors, unique_colors);
    
    % Set diagonal to infinity so we don't pick the same color as closest
    dist_matrix(logical(eye(size(dist_matrix)))) = inf;
    
    % Find indices of the two closest colors
    [~, min_idx] = min(dist_matrix(:));
    [idx1, idx2] = ind2sub(size(dist_matrix), min_idx);
    
    % Merge colors: Weighted average based on pixel frequency
    total_count = counts(idx1) + counts(idx2);
    unique_colors(idx1, :) = (unique_colors(idx1, :) * counts(idx1) + ...
                             unique_colors(idx2, :) * counts(idx2)) / total_count;
    counts(idx1) = total_count;
    
    % Remove the second color from the list
    unique_colors(idx2, :) = [];
    counts(idx2) = [];
    
    % Update the index map to point to the new merged color
    idx(idx == idx2) = idx1;
    idx(idx > idx2) = idx(idx > idx2) - 1;
    
    % Calculate current MSE to track quality degradation
    reduced_img = reshape(unique_colors(idx, :), h, w, c);
    mse_val = mean((img_orig(:) - reduced_img(:)).^2);
    
    % Output progress
    fprintf('Colors remaining: %d | MSE: %.6f\n', size(unique_colors, 1), mse_val);
end

% 5. Write the final reduced image
imwrite(reduced_img, 'Sword_guard_reduced.png');
imshow(reduced_img);
title(['Result with ', num2str(target_colors), ' colors']);