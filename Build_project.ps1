matlab -batch "run('Working_toolchain_MVS/Run_conversion_MVS.m')"
copy ".\Working_toolchain_MVS\*.png" ".\working_toolchain_NGCD\MVS_hack\"
matlab -batch "run('Working_toolchain_NGCD/Run_conversion_NGCD.m')"
Read-Host "MATLAB script finished. Press ENTER to continue or close the window."