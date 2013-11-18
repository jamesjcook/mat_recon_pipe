
% bruker tests
% test recons all data from scanner.
all_methods={'AdjRefG','DtiEpi','DtiStandard','EPI','FC2D_ANGIO','FLASH',...
    'Fastmap','FieldMap','GEFC','MDEFT','MGE','MSME','Out','PRESS','RARE',...
    'RAREVTR','SINGLEPULSE','T1_EPI','UTE','UTE3D','ute3d_keyhole',''};
fprintf('All Methods\n ');
fprintf('%s,\n ',all_methods{:});
% known_methods={'MDEFT','MGE','MSME','RARE','UTE3D','ute3d_keyhole'};
% known_methods={'MGE'};
known_methods={'ute3d_keyhole','UTE3D'};
fprintf('Known/tested Methods\n ');
fprintf('%s,\n ',known_methods{:});
dataroot='/opt/PV5.1/data/nmrsu/nmr/';
verbosity=0;
scanner_list={'dory','nemo'};
fail_list='';
test_brukerextract=false;
test_rad_mat=true;

for scanner_num=1:numel(scanner_list)
    scanner=scanner_list{scanner_num};
    % to get all methods currently avaialable on scanner
    [s, method_list]=system([ 'ssh nmrsu@' scanner ' grep Method= ' dataroot '*/*/method | cut -d "=" -f2 |sort -u']);
    method_list(end)=[];
    method_list=strsplit(method_list,'\n');
    fprintf('Available Test Methods\n ');
    fprintf('%s,\n ',method_list{:});
    for mnum=1:numel(method_list)
        method=method_list{mnum};
        % get all scans for current method,
        recon_status=false;
        if regexp(method,strjoin(known_methods,'|'))
            fprintf('Procesing scans for method: %s\n',method);
            [s, acq_list]=system( ['ssh nmrsu@' scanner ' grep Method= ' dataroot '*/*/method | grep ' method '|cut -d ":" -f 1' ]);
            acq_list=strsplit(acq_list,'\n');
            acq_list(end)=[];
            % patient_id='20131025';
            % nums=[ 9 10 12 14 15 16 17 18 19 20 21 22 23 24 25 26 27 ];
            fprintf('\t parsing %d acquistions with method.',numel(acq_list));
            patients=struct;
            last_patient_dir='';
            for acq_num=1:numel(acq_list)
                fprintf('.');
                acq=acq_list{acq_num};
                details=strsplit(acq,'/');
                patient_dir=details{end-2};
                if ~strcmp(patient_dir,last_patient_dir)
                    [s, study_val] = system([ 'ssh nmrsu@' scanner ' grep -HiC 1 study_name= ' dataroot '/' patient_dir '/subject | tail -n 1 | cut -d "<" -f2']);
                    study_fieldname=['sid_' study_val(1:end-2)];
                    if isempty(study_fieldname) ||isempty(study_val) % check for spaces.
                        error('studyblank');
                        patient_studyname='BLANK';
                    end
                    
                    if regexp(study_fieldname,'-')  % check for spaces.
                        patient_studyname=regexprep(study_fieldname,'-','___');
                        if  verbosity>0
                            warning('dash in name, replacing with triple underscore_');%, ka boom, note this condition should be fixed, as sally allowed this.(bleh).');
                            fprintf('%s',study_fieldname);
                        end
                    end

                    last_patient_dir=patient_dir;
                end
                patient_fieldname=['pid_' patient_dir(1:end-4)];
                if isempty(patient_fieldname)  % check for spaces.
                    error('patient_id');
                    patient_fieldname='BLANK';
                end
                if regexp(patient_fieldname,'-')  % check for spaces.
                    patient_fieldname=regexprep(patient_fieldname,'-','___');
                    if  verbosity>0
                        warning('dash in name, replacing with triple underscore_');%, ka boom, note this condition should be fixed, as sally allowed this.(bleh).');
                        fprintf('%s',patient_fieldname);
                    end
                end
                if isfield(patients,patient_fieldname)
                    if isfield(patients.(patient_fieldname),study_fieldname)
                        patients.(patient_fieldname).(study_fieldname)=[patients.(patient_fieldname).(study_fieldname) str2double(details{end-1})];
                    else
                        patients.(patient_fieldname).(study_fieldname)=[str2double(details{end-1})];
                    end
                else
                    patients.(patient_fieldname).(study_fieldname)=[str2double(details{end-1})];
                end
            end
            clear last_patient_dir details acq_list acq acq_num study_fieldname patient_fieldname details
            fprintf('\n');
            patient_names=fieldnames(patients);
            fprintf('Found %d patients with data for method %s\n',numel(patient_names),method);
            for p_num=1:numel(patient_names)
                pname=patient_names{p_num};
                patient_id=pname;
                if regexp(patient_id,'___')  % check for spaces.
                    patient_id=regexprep(patient_id,'___','-');
                    if  verbosity>0
                        warning('reverting dash in name');%, ka boom, note this condition should be fixed, as sally allowed this.(bleh).');
                        fprintf('%s',patient_id);
                    end
                end
                patient_id=patient_id(5:end);
                study_names=fieldnames(patients.(pname));
                fprintf('Found %d studies for patient id %s\n',numel(study_names),patient_id);
                for s_num=1:numel(study_names)
                    sname=study_names{s_num};
                    studyname=sname;
                    if regexp(studyname,'-')  % check for spaces.
                        studyname=regexprep(studyname,'___','-');
                        if  verbosity>0
                            warning('reverting dash in name');%, ka boom, note this condition should be fixed, as sally allowed this.(bleh).');
                            fprintf('%s',studyname);
                        end
                    end
                    studyname=studyname(5:end);
                    acquisition_numbers=patients.(pname).(sname);
                    fprintf('Found %d scans in study %s\n',numel(acquisition_numbers),studyname);
                    for acq_num=1:1 %numel(acquisition_numbers) %only do first acq to collect traj files
                        num=acquisition_numbers(acq_num);
                        if ~recon_status
                            if test_rad_mat
                                try
                                    [img,recon_status ]=rad_mat(scanner,...
                                        ['test_RM_' scanner '_' method '_' patient_id '_' studyname '_s' sprintf('%02d',num)],...
                                        {patient_id,num2str(num)},...
                                        {'warning_pause=0'
                                        'debug_mode=0'
                                        ['study=' studyname]
                                        'overwrite'
                                        'existing_data'
                                        'testmode'
                                        'write_unscaled_nD'
                                        'skip_write_civm_raw'
                                        'skip_write_headfile'
                                        'ignore_errors'
                                        'skip_fft'
                                        'skip_regrid'
                                        'skip_filter'
                                        'skip_write'
                                        }');
                                    recon_status=false;
                                    
                                    %         if s==0
                                    %         fail_list=sprintf('%s\n%s',fail_list,num2str(num));
                                    %         else
                                    %         end
                                catch err
                                    %         if s==0
                                    err_m=[err.message ];
                                    for e=1:length(err.stack)
                                        err_m=sprintf('%s\n \t%s:%i',err_m,err.stack(e).name,err.stack(e).line);
                                    end
                                    fail_list=sprintf('%sbad_scan:%s\nerr_m%s',fail_list,num2str(num),err_m);
                                %         else
                                %         end
                                end
                            end
                            if test_brukerextract
                                system(['brukerextract',' ','-p',' ','test.param',' ',scanner,' ','nmrsu',' ',patient_id,' ',studyname,' ',num2str(num),' ',['test_BE_' scanner '_' method '_' patient_id '_' studyname '_s' sprintf('%02d',num) ]],'-echo');
                            end
                        end
                    end
                end
            end
            
        end
    end
end
%         img=rad_mat('nemo',['Btest_' patient_id '_' num2str(num)],{patient_id,num2str(num)},{'warning_pause=0','study=Rat','overwrite','testmode','write_unscaled'});

fprintf('List of failed runs:%s\n',fail_list);
