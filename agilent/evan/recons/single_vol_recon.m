function single_vol_recon(fidpath,workpath,max_blocks,ntraces,npoints,bitdepth,numchunks,voldims,scannercode,runno,res,phase_boolean,headfile)

%% set complex outpath and set volnum=1 for single dataset
complex_outpath=[workpath '/' runno '_complex_out.mat'];
volnum=1;

%% if complex out doesnt exist, create it, if it does, load it in to memory
if ~exist(complex_outpath,'file');
    display('reading fid file in to memory');
    data_buffer=load_fid(fidpath,max_blocks,ntraces,npoints,bitdepth,numchunks,voldims);
    display('applying fermi filter');
    data_buffer=fermi_filter(data_buffer);
    display('doing 3D ifft');
    data_buffer=fft3d(data_buffer);
    display('saving complex output in work directory');
    dummy=0;
    save(complex_outpath,'dummy','-v7.3');%save a dummy variable to avoid MATLAB compression when saving complex data
    save(complex_outpath,'data_buffer','-append'); %must save as v7.3 due to filesize limits in previous versions
else
    display('complex output file found in work directory, ifft will not be redone');
    display('loading complex output from disk');
    load(complex_outpath);
end


%% save output as phase or magnitude etc.

%set booleans for save_agilent_img
if phase_boolean==1
    display('saving phase images');
    magnitude_boolean=0;
    letter='p';
else
    display('saving magnitude images');
    magnitude_boolean=1;
    letter='m';
end
scale_boolean=1; slice_boolean=0;
save_agilent_img(data_buffer,volnum,1,scannercode,runno,res,headfile,scale_boolean,magnitude_boolean,phase_boolean,slice_boolean); %no slices yet

%rolling in y
resp=0;
while ~strcmp(resp,'n')
    resp=input('Would you like to roll your volume data in y? >> ','s');
    if strcmp(resp,'y')
        display('positive numbers will move the image down in y and negative numbers will move it up in y');
        roll=input('What roll? >> ');
            display('rolling dataset');
            data_buffer=circshift(data_buffer,[0 roll 0]);
            save([workpath '/roll.mat'],'roll');
        resp='n';
    elseif ~strcmp(resp,'n');
        display('please enter y or n');
    end
end

%now write slices and rolled volumes 
slice_boolean=1;
save_agilent_img(data_buffer,volnum,1,scannercode,runno,res,headfile,scale_boolean,magnitude_boolean,phase_boolean,slice_boolean); %now slices


%convienience prompts
display('use this to archive your results:');
display(' ');
display(['archiveme ' headfile.U_civmid ' ' runno '_' letter '0']);
display(' ');
