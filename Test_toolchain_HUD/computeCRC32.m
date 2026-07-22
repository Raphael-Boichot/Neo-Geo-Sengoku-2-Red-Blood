function crc = computeCRC32(filename)
    % Check runtime environment
    isOctave = exist('OCTAVE_VERSION', 'builtin') ~= 0;

    if isOctave
        % --- OCTAVE PATH: Compile and use a high-speed C-MEX file ---
        mexName = 'computeCRC32_c';
        mexExtStr = mexext(); 
        
        % Check if the compiled MEX binary already exists
        if isempty(dir([mexName, '.', mexExtStr])) && isempty(dir([mexName, '.mex*']))
            disp('Octave detected: Compiling CRC32 C-MEX file automatically...');
            
            % 1. Create the C source file on the fly
            cFile = [mexName, '.c'];
            fid = fopen(cFile, 'w');
            fwrite(fid, get_c_source());
            fclose(fid);
            
            % 2. Compile it using Octave's built-in mkoctfile wrapper
            try
                mkoctfile('--mex', cFile);
                disp('Compilation successful!');
            catch err
                error('Failed to compile CRC32 MEX file in Octave: %s', err.message);
            end
        end
        
        % 3. Read file data and call the compiled C-MEX function
        fid = fopen(filename, 'rb');
        data = fread(fid, inf, '*uint8');
        fclose(fid);
        
        % Invoke the compiled C function
        crc = computeCRC32_c(data);

    else
        % --- MATLAB PATH: Run optimized MATLAB implementation ---
        persistent table
        if isempty(table)
            table = zeros(256, 1, 'uint32');
            poly = uint32(3988292384); % 0xEDB88320
            for i = 0:255
                c = uint32(i);
                for k = 1:8
                    if bitand(c, 1)
                        c = bitxor(bitshift(c, int32(-1)), poly);
                    else
                        c = bitshift(c, int32(-1));
                    end
                end
                table(i+1) = c;
            end
        end

        fid = fopen(filename, 'rb');
        data = fread(fid, inf, '*uint8');
        fclose(fid);

        crc = uint32(4294967295); % 0xFFFFFFFF
        for i = 1:length(data)
            idx = double(bitand(bitxor(crc, uint32(data(i))), uint32(255))) + 1;
            crc = bitxor(bitshift(crc, int32(-8)), table(idx));
        end
        crc = bitxor(crc, uint32(4294967295));
    end
end

function c_code = get_c_source()
    % Clean C source code container using a cell array of strings to prevent syntax/keyword bugs
    lines = {
        '#include "mex.h"',
        'static unsigned int crc_table[256];',
        'static int initialised = 0;',
        'void crc32_setup(void) {',
        '    unsigned int i, j, k;',
        '    for (i = 0; i < 256; i++) {',
        '        k = i;',
        '        for (j = 0; j < 8; j++) {',
        '            if (k & 1) k = (k >> 1) ^ 0xEDB88320;',
        '            else k >>= 1;',
        '        }',
        '        crc_table[i] = k;',
        '    }',
        '}',
        'void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {',
        '    unsigned int crc = 0xFFFFFFFF;',
        '    unsigned char *data;',
        '    size_t len, i;',
        '    if (!initialised) { crc32_setup(); initialised = 1; }',
        '    data = (unsigned char *)mxGetData(prhs[0]);',
        '    len = mxGetNumberOfElements(prhs[0]);',
        '    for (i = 0; i < len; i++) {',
        '        crc = (crc >> 8) ^ crc_table[(crc ^ data[i]) & 0xFF];',
        '    }',
        '    crc ^= 0xFFFFFFFF;',
        '    plhs[0] = mxCreateNumericMatrix(1, 1, mxUINT32_CLASS, mxREAL);',
        '    *(unsigned int *)mxGetData(plhs[0]) = crc;',
        '}'
    };
    c_code = strjoin(lines, '\n');
end