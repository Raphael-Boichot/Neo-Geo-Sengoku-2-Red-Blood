Write-Host "Attempting to run MATLAB conversion scripts..." -ForegroundColor Cyan

# Try running MATLAB first
try {
    Write-Host "Running MATLAB batch for MVS..." -ForegroundColor Yellow
    matlab -batch "run('Working_toolchain_MVS/Run_conversion_MVS.m')"
    if ($LASTEXITCODE -ne 0) { throw "MATLAB MVS script exited with code $LASTEXITCODE" }

    Write-Host "Copying MVS generated PNG files..." -ForegroundColor Yellow
    copy ".\Working_toolchain_MVS\*.png" ".\working_toolchain_NGCD\MVS_hack\"
    if ($LASTEXITCODE -ne 0) { throw "Failed to copy PNG files" }

    Write-Host "Running MATLAB batch for NGCD..." -ForegroundColor Yellow
    matlab -batch "run('Working_toolchain_NGCD/Run_conversion_NGCD.m')"
    if ($LASTEXITCODE -ne 0) { throw "MATLAB NGCD script exited with code $LASTEXITCODE" }

    Write-Host "SUCCESS: All steps completed successfully using MATLAB." -ForegroundColor Green
}
catch {
    Write-Host "WARNING: MATLAB execution failed. Error: $_" -ForegroundColor Red
    Write-Host "Falling back to GNU Octave..." -ForegroundColor Cyan

    # Fallback to GNU Octave running the exact same steps
    try {
        Write-Host "Running Octave batch for MVS..." -ForegroundColor Yellow
        octave-cli --eval "run('Working_toolchain_MVS/Run_conversion_MVS.m')"
        if ($LASTEXITCODE -ne 0) { throw "Octave MVS script exited with code $LASTEXITCODE" }

        Write-Host "Copying MVS generated PNG files..." -ForegroundColor Yellow
        copy ".\Working_toolchain_MVS\*.png" ".\working_toolchain_NGCD\MVS_hack\"
        if ($LASTEXITCODE -ne 0) { throw "Failed to copy PNG files" }

        Write-Host "Running Octave batch for NGCD..." -ForegroundColor Yellow
        octave-cli --eval "run('Working_toolchain_NGCD/Run_conversion_NGCD.m')"
        if ($LASTEXITCODE -ne 0) { throw "Octave NGCD script exited with code $LASTEXITCODE" }

        Write-Host "SUCCESS: All steps completed successfully using GNU Octave." -ForegroundColor Green
    }
    catch {
        Write-Host "ERROR: GNU Octave execution also failed. Error: $_" -ForegroundColor Red
    }
}

Read-Host "Script finished. Press ENTER to continue or close the window."