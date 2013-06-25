bruker=readBrukerDirectory('/panoramaspace/mge_msme.work');

[ray_padding, ray_length]=bruker_get_pad_ammount(combine_struct(bruker.acqp,bruker.method));

fid=bruker_un_pad_fid(bruker.fid,ray_padding,ray_length);

    
% d_reshape=reshape(fid,[x c e*z y ]);
