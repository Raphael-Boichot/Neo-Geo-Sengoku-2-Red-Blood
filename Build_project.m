clc
clear
tic
run('Working_toolchain_MVS/Run_conversion_MVS.m')
copyfile('.\Working_toolchain_MVS\*.png', '.\working_toolchain_NGCD\MVS_hack\');
run('Working_toolchain_NGCD/Run_conversion_NGCD.m')
toc

% Full conversion in about 50s with Matlab