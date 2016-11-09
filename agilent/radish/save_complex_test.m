function save_complex_test
% this tries to test the save_complex function for correct outputs. But we
% run into floating point error issues so the test isnt perfect.

% this worekd. 
% re=ones(50,50,50);
% im=zeros(50,50,50);
% 
% re=zeros(1050,50,50);
% im=ones(1050,50,50);
% re(1)=0.5;

% %aprox 2 second test
% re=rand(500,250,125);
% im=rand(500,250,125);
% %aprox 15 second test
re=rand(500,500,500);
im=rand(500,500,500);
% vol=complex(re,im);
% %aprox 9 second test
vol=complex(single(re),single(im));

path='/delosspace/cplx.rp';

%new_code
delete(path);
nt=tic;
save_complex(vol,path)
system(['ls -lh ' path]);
nt=toc(nt);

%old_code
delete(path);
ot=tic;
save_complex(vol,path,1)
system(['ls -lh ' path]);
ot=toc(ot);
fprintf('Old code=%f\nNew code=%f\n----\ndiff is =%f\nPositive is faster.\n',ot,nt,ot-nt);
vol_back=load_complex(path,size(vol),class(vol),'l',0,0);

status=sum(vol(:)-vol_back(:));
if status
    error('write failure');
else
    disp('Success');
end