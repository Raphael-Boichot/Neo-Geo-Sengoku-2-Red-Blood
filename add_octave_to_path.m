function add_octave_to_path()
% ADD_OCTAVE_TO_PATH  Persist this Octave installation's bin folder into
% the current Windows user's PATH environment variable, so that typing
% "octave" or "octave-cli" in a new PowerShell window works without
% having to launch it from the Start Menu shortcut.
%
% Run this once, from inside Octave:
%   add_octave_to_path()
%
% Then close and reopen PowerShell (environment variables are only
% picked up by new processes).

    if ~ispc()
        error('add_octave_to_path: this is only meaningful on Windows.');
    end

    bin_dir = fullfile(OCTAVE_HOME(), 'bin');
    if ~isfolder(bin_dir)
        error('add_octave_to_path: could not locate Octave bin folder at %s', bin_dir);
    end
    fprintf('Detected Octave bin directory: %s\n', bin_dir);

    % Write a small PowerShell script to a temp file and run it, rather
    % than trying to build one giant quoted system() command line --
    % nesting Octave's system()/cmd.exe quoting with PowerShell's own
    % quoting rules is fragile, a .ps1 file sidesteps that entirely.
    ps_script = fullfile(tempdir(), 'add_octave_path.ps1');
    fid = fopen(ps_script, 'w');
    if fid == -1
        error('add_octave_to_path: could not create temp script %s', ps_script);
    end

    fprintf(fid, '$binDir = "%s"\n', bin_dir);
    fprintf(fid, '$current = [Environment]::GetEnvironmentVariable(''Path'', ''User'')\n');
    fprintf(fid, 'if ($null -eq $current) { $current = '''' }\n');
    fprintf(fid, '$parts = $current -split '';'' | Where-Object { $_ -ne '''' }\n');
    fprintf(fid, 'if ($parts -contains $binDir) {\n');
    fprintf(fid, '    Write-Host "Already present in User PATH: $binDir"\n');
    fprintf(fid, '} else {\n');
    fprintf(fid, '    $new = if ($current.Trim() -eq '''') { $binDir } else { "$current;$binDir" }\n');
    fprintf(fid, '    [Environment]::SetEnvironmentVariable(''Path'', $new, ''User'')\n');
    fprintf(fid, '    Write-Host "Added to User PATH: $binDir"\n');
    fprintf(fid, '    Write-Host "Close and reopen PowerShell for this to take effect."\n');
    fprintf(fid, '}\n');
    fclose(fid);

    % -NoProfile: skip user profile scripts (faster, avoids surprises)
    % -ExecutionPolicy Bypass: only affects this one invocation, does
    %   not change the system-wide execution policy
    cmd = sprintf('powershell -NoProfile -ExecutionPolicy Bypass -File "%s"', ps_script);
    [status, out] = system(cmd);
    fprintf('%s', out);

    delete(ps_script);

    if status ~= 0
        error('add_octave_to_path: PowerShell command failed (exit code %d).', status);
    end
end
