function outpath=rigid_affine(fixed,moving,do_warp,do_avg,is_rigid,outpath)

ANTS='/Applications/SegmentationSoftware/ANTS/';

if ~iscell(fixed)
    fixed={fixed};
end

if ~iscell(moving)
    moving={moving};
end

if ~exist('is_rigid','var')
    is_rigid=1;
end

if is_rigid==1
    rigid=' --rigid-affine true ';
else
    rigid=' ';
end

for i=1:length(moving);
    [path name ext]=fileparts(moving{i});
    [path1 name1 ext1]=fileparts(fixed{i});
    affine_cmd=horzcat(ANTS,'ANTS 3 -m MI[ ',fixed{i},',',moving{i},',1,8] -o ',path,'/',name,'_to_',name1,'_ -i 0',rigid,' --affine-gradient-descent-option 0.1x0.5x0.0001x0.0001 --number-of-affine-iterations 3000x3000x3000x3000');
    display(affine_cmd)
    if ~exist([path,'/',name,'_to_',name1,'_Affine.txt'],'file')
        system(affine_cmd);
    end
end
if exist('do_warp','var')
    if do_warp==1;
        for i=1:length(moving);
            [path name ext]=fileparts(moving{i});
            if exist('outpath','var')
            else
                outpath=[moving{i}(1:end-4),'_affine.nii'];
            end
            warp_cmd=horzcat(ANTS,'WarpImageMultiTransform 3 ',moving{i},' ',outpath,' -R ',fixed{i},' ',path,'/',name,'_to_',name1,'_Affine.txt');
            display(warp_cmd);
            system(warp_cmd);
            
            if exist('do_avg','var')
                if do_avg==1;
                    avg_niis(fixed{i},outpath);
                end
            end
        end
    end
end