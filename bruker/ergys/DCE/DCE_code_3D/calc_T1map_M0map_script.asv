load FAvalues;
load varFAstack;

mat=128;
TR=5; %ms

tic
[T1map, Mo_map, E1]=calcT1map_3D(TR, FAvalues, varFAstack, mat);

current_directory=pwd;
fid=fopen([current_directory '\T1map.raw'], 'w');
fwrite(fid, T1map, 'float32', 'l'); %Little-endian ordering (lab convention)
fclose(fid);

current_directory=pwd;
fid=fopen([current_directory '\Mo_map.raw'], 'w');
fwrite(fid, Mo_map, 'float32', 'l'); %Little-endian ordering (lab convention)
fclose(fid);
toc