function agilent_save_kspace_magnitude(dir)

[re,im,np,nb,nt,hdr]=agilent_load_fid(dir);
mag=abs(complex(re,im));

[p n ext]=fileparts(dir);
outpath=[p '/' n ext '/' n ext '.afid' '.mag'];
ofid=fopen(outpath,'w+','l');
if ofid == -1
    error('Could not open output file');
end
fwrite(ofid,mag,'single');
fclose(ofid);