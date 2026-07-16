function []=File_merger(file_in,file_out,repeat)

fid_in = fopen(file_in, 'rb');
data_in = fread(fid_in, inf, 'uint8');
fclose(fid_in);

fid_Out = fopen(file_out, 'wb');

data_out=[];
for i=1:1:repeat
data_out = [data_out,data_in];% stack ROMs to fill a chip instead of just padding
end

fwrite(fid_Out, data_out, 'uint8');
fclose(fid_Out);
disp(['Concatenated ',fid_Out, ' created'])