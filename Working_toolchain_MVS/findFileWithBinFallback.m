function resolvedFile = findFileWithBinFallback(filename)
% FINDFILEWITHBINFALLBACK Checks for a file, replaces its extension 
% with .bin if missing, or errors out if neither exists.
%
%   resolvedFile = findFileWithBinFallback(filename) returns the 
%   path/name of the file that was successfully found.

    % Step 1: Check if the exact file exists
    if exist(filename, 'file') == 2
        resolvedFile = filename;
        disp(['Found exact file: ', resolvedFile]);
        
    else
        % Remove any existing extension and try with .bin
        [filepath, name, ~] = fileparts(filename);
        binFilename = fullfile(filepath, [name, '.bin']);
        
        % Step 2: Check if the .bin version exists
        if exist(binFilename, 'file') == 2
            resolvedFile = binFilename;
            disp(['Found file with .bin extension: ', resolvedFile]);
            
        % Step 3: If still not present, throw an error and halt execution
        else
            error('FileError:NotFound', ...
                  'The specified file could not be found. Tried "%s" and "%s".', ...
                  filename, binFilename);
        end
    end
end