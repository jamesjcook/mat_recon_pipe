clc

tStart=tic;

runno='00364';
repeat=20;
keyhole=13;
mat=128;

concat_vol=[];
for j=1:repeat
    for i=1:keyhole
        vol_name= ['B' runno '_acq' num2str(j) '_key' num2str(i) '.raw'];
        vol=open_raw(vol_name, mat);
        % vol=permute(vol, [3 1 2]); %reslice in coronal plane
        % you should probably allocate this before going into the loop and
        % fill it in, instead of starting empty and concatenating
        concat_vol=cat(3, concat_vol, vol);
    end
    fclose('all');
end


current_directory=pwd;
fid=fopen(['B' runno '_concat_' num2str(repeat*keyhole) 'volumes.raw' ], 'w');
fwrite(fid, concat_vol, 'float32', 'l'); %Little-endian ordering (lab convention)
fclose(fid);

v=genvarname(['B' runno '_concat_' num2str(repeat*keyhole) 'volumes']);
eval([v '=concat_vol;']);
save(v, v, '-v7.3'); %Need to have for TDC analysis

tElapsed=toc(tStart);
display(['Concatenating ' num2str(keyhole*repeat) ' volumes took ' num2str(tElapsed/60) ' minutes'])