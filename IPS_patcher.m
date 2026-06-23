function IPS_patcher(targetFile, patchFile)
    % Open files
    fTarget = fopen(targetFile, 'r+');
    fPatch = fopen(patchFile, 'r');
    
    % Verify Header 'PATCH'
    header = char(fread(fPatch, 5, 'char')');
    if ~strcmp(header, 'PATCH')
        error('Invalid IPS patch file: Missing PATCH header.');
    end
    
    try
        while ~feof(fPatch)
            % Read 3-byte offset
            offsetBytes = fread(fPatch, 3, 'uint8');
            if isempty(offsetBytes), break; end
            
            % Convert 3 bytes (Big Endian) to integer
            offset = offsetBytes(1) * 65536 + offsetBytes(2) * 256 + offsetBytes(3);
            
            % Check for EOF marker
            if offset == 11451967 % "EOF" string (0x45, 0x4F, 0x46)
                break;
            end
            
            % Read 2-byte size
            sizeBytes = fread(fPatch, 2, 'uint8');
            patchSize = sizeBytes(1) * 256 + sizeBytes(2);
            
            if patchSize > 0
                % Normal record
                data = fread(fPatch, patchSize, 'uint8');
                fseek(fTarget, offset, 'bof');
                fwrite(fTarget, data, 'uint8');
            else
                % RLE (Run-Length Encoding) record
                rleSize = fread(fPatch, 2, 'uint8');
                rleSize = rleSize(1) * 256 + rleSize(2);
                rleByte = fread(fPatch, 1, 'uint8');
                
                fseek(fTarget, offset, 'bof');
                fwrite(fTarget, repmat(rleByte, 1, rleSize), 'uint8');
            end
        end
    catch ME
        fclose(fTarget);
        fclose(fPatch);
        rethrow(ME);
    end
    
    fclose(fTarget);
    fclose(fPatch);
    fprintf('Patch applied successfully.\n');
end