clc
clear
flag = 1;
if not(isfile('.\Working_toolchain_MVS\roms\040-c1.c1') &...
        isfile('.\Working_toolchain_MVS\roms\040-c2.c2') &...
        isfile('.\Working_toolchain_MVS\roms\040-c3.c3') &...
        isfile('.\Working_toolchain_MVS\roms\040-c4.c4') &...
        isfile('.\Working_toolchain_MVS\roms\040-p1.p1') |...
        isfile('.\Working_toolchain_MVS\roms\040-c1.bin') &...
        isfile('.\Working_toolchain_MVS\roms\040-c2.bin') &...
        isfile('.\Working_toolchain_MVS\roms\040-c3.bin') &...
        isfile('.\Working_toolchain_MVS\roms\040-c4.bin') &...
        isfile('.\Working_toolchain_MVS\roms\040-p1.bin'))
    flag=0;
end

if flag==1
    tic
    disp('####################################################################')
    disp('##################### Building the MVS version #####################')
    disp('####################################################################')
    run('Working_toolchain_MVS/Run_conversion_MVS.m')
    toc
else
    warndlg('At least one necessary file is missing for the MVS version !', 'Warning');
    disp('Code termination, MVS version not done !')
end

clear
flag = 1;
if not(isfile('.\Working_toolchain_NGCD\NGCD_track_1_files\AREA1.SPR') &...
        isfile('.\Working_toolchain_NGCD\NGCD_track_1_files\AREA2.SPR') &...
        isfile('.\Working_toolchain_NGCD\NGCD_track_1_files\AREA3.SPR') &...
        isfile('.\Working_toolchain_NGCD\NGCD_track_1_files\AREA4.SPR') &...
        isfile('.\Working_toolchain_NGCD\NGCD_track_1_files\JOUCHU.SPR') &...
        isfile('.\Working_toolchain_NGCD\NGCD_track_1_files\STAFF.SPR') &...
        isfile('.\Working_toolchain_NGCD\NGCD_track_1_files\TITLE.SPR') &...
        isfile('.\Working_toolchain_NGCD\NGCD_track_1_files\P040.PRG') &...
        isfile('.\Working_toolchain_NGCD\NGCD_track_1_binary\Sengoku2_Track_01.bin'))
    flag=0;
end

if flag==1
    tic
    disp('#####################################################################')
    disp('##################### Building the NGCD version #####################')
    disp('#####################################################################')
    copyfile('.\Working_toolchain_MVS\*.png', '.\working_toolchain_NGCD\MVS_hack\');
    run('Working_toolchain_NGCD/Run_conversion_NGCD.m')
    toc
else
    warndlg('At least one necessary file is missing for the NGCD version !', 'Warning');
    disp('Code termination, NGCD version not done !')
end

% Full conversion in about 24 seconds with Matlab
% Full conversion in about 149 seconds with GNU Octave
