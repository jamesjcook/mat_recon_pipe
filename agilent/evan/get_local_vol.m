function local_volume=get_local_vol

%check for standard hostname-space volume
[status hostname]=system('echo $HOSTNAME | cut -d ''.'' -f 1');

if exist(['/Volumes/' hostname(1:end-1) 'space'],'dir');
    local_volume=['/Volumes/' hostname(1:end-1) 'space'];
else
    display('cannot determine local disk, making some guesses')
    if exist('/Volumes/androsspace','dir')
        local_volume='/Volumes/androsspace';
    elseif exist('/Volumes/naxosspace','dir')
        local_volume='/Volumes/naxosspace';
    elseif exist('/Volumes/syrosspace','dir')
        local_volume='/Volumes/syrosspace';
    elseif exist('/Volumes/delosspace','dir')
        local_volume='/Volumes/delosspace';
    else
        error('no appropriate local disk found!');
    end
end