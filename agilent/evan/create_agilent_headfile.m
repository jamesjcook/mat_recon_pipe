function headfile=create_agilent_headfile(procpar,img_format,runno)

%% make output structure
headfile=struct;

%% define key values for archive from procpar
%orientation compatibility fix
if ~strcmp(procpar.orient{1},'ax') && ~strcmp(procpar.orient{1},'cor') && ~strcmp(procpar.orient{1},'sag')
    orient='ax';
else
    orient=procpar.orient{1};%must specify cell index otherwise not a string output
end
headfile.U_rplane=orient; 
headfile.alpha=procpar.flip1;
%headfile.variable_alpha= this is not implemented yet
headfile.bw=procpar.sw/1000; %divide to get kHz
headfile.dim_X=procpar.np/2;
headfile.dim_Y=procpar.nv;
headfile.dim_Z=procpar.nv2;
headfile.fovx=procpar.lro*10; %multiply to get cm
headfile.fovy=procpar.lpe*10; %multiply to get cm
headfile.fovz=procpar.lpe2*10; %multiply to get cm
headfile.te=(procpar.te*1000); %multiply to get miliseconds
headfile.tr=(procpar.tr*1000000); %multiply to get microseconds
headfile.S_recon_type='Matlab_Evan'; %removed Agilent, there is a 16 char limit here.
headfile.PSDName=procpar.seqfil{1}; %the PSD name
%determine field strength
if floor(procpar.sfrq)==300
    tesla='7t';
else
    tesla='9t';
end
headfile.S_tesla=tesla;
headfile.F_imgformat=img_format;
headfile.hfpmcnt=1;
headfile.U_status='ok';
headfile.S_header_type='Matlab_Evan'; %removed Agilent, there is a 16 char limit here.
headfile.S_runno=runno;
headfile.U_coil=procpar.rfcoil{1};
headfile.U_xmit=procpar.tpwr1;
headfile.U_recongui_date=datestr(date,'mm/dd/yy');
headfile.U_focus='whole';%input('enter focus >> ','s');
headfile.U_nucleus=procpar.tn{1}(1); %only want first letter


%% max bvalue for diffusion scans
% this is calculated for all scans but will be zero in non diffusion scans
% consider adding the read gradient contribution
headfile.B_max_bval=agilent_bval_calc(procpar);

%% manual user input stuff
headfile.U_civmid=input('enter CIVM ID >> ','s');
headfile.U_state=input('enter subject state (in vs ex vivo) >> ','s');
headfile.U_optional=input('enter optional info >> ','s');

%only manual if not exist in procpar
%project code
if strcmp(procpar.samplename,'');
    headfile.U_code=input('enter project code >> ','s');
else
    display(['project code = ' procpar.samplename{1}]);
    headfile.U_code=procpar.samplename{1};
end

%subject orient
if strcmp(procpar.position2{1},'')
    headfile.U_orient=input('enter subject orientation >> ','s');
else
    display(['subject orientation = ' procpar.position2{1}]);
    headfile.U_orient=procpar.position2{1};
end

%specimen ID
if strcmp(procpar.ident{1},'')
    headfile.U_specid=input('enter specimen ID >> ','s');
else
    display(['specimen ID = ' procpar.ident{1}]);
    headfile.U_specid=procpar.ident{1};
end

%species
if strcmp(procpar.name{1},'')
    headfile.U_species=input('enter species >> ','s');
else
    display(['species = ' procpar.name{1}]);
    headfile.U_species=procpar.name{1};
end

%type
if strcmp(procpar.anatomy{1},'')
    headfile.U_type=input('enter specimen type >> ','s');
else
    display(['specimen type = ' procpar.anatomy{1}]);
    headfile.U_orient=procpar.anatomy{1};
end

%% the rest of the procpar variables to be included in the headfile
fields=fieldnames(procpar);
for i=1:length(fields)
    value=getfield(procpar,fields{i});
    if ~iscell(value) && ~ischar(value)
        value=num2str(value);
    elseif iscell(value)
        value=value{:};
    else
        value=char(value);
    end
    eval(['headfile.z_Agilent_' fields{i} '=''' value ''';']);
end
        



