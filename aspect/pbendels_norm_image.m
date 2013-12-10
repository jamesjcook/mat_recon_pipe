%function norm=pbendels_norm_image(d,imf,noise_box,noise_border,avr_mul,signal_mul)
function norm=pbendels_norm_image(d,image,noise_box,noise_border,avr_mul,signal_mul)


    Nf= d(1);
    Npe=d(2);
    Npe2=d(3);

    noise_box_z=noise_box;
%     signal_box=64;
    noise_border_z=noise_border;

if(d(3)>4)
    if(d(3)<2*noise_box+noise_border*1.5)
        noise_box_z=floor(d(3)/2)-2;
        if(noise_box_z<2)
            noise_box_z=1;
        end
    end
    if(noise_box_z+noise_border_z>floor(d(3)/2))
        noise_border_z=floor(d(3)/2)-noise_box_z-1;
        if(noise_border_z<0)
            noise_border_z=0;
        end
        %    noise_box_z=noise_box_z-1;
    end

    nbox(1,:)=[noise_border+1,noise_border+1,noise_border_z+1];
    nbox(2,:)=[Nf-noise_border-noise_box,noise_border+1,noise_border_z+1];
    nbox(3,:)=[noise_border+1,Npe-noise_border-noise_box,noise_border_z+1];
    nbox(4,:)=[noise_border+1,noise_border+1,Npe2-noise_border_z-noise_box_z];
    nbox(5,:)=[Nf-noise_border-noise_box,Npe-noise_border-noise_box,noise_border_z+1];
    nbox(6,:)=[Nf-noise_border-noise_box,noise_border+1,Npe2-noise_border_z-noise_box_z];
    nbox(7,:)=[noise_border+1,Npe-noise_border-noise_box,Npe2-noise_border_z-noise_box_z];
    nbox(8,:)=[Nf-noise_border-noise_box,Npe-noise_border-noise_box,Npe2-noise_border_z-noise_box_z];

    for i=1:8 avr(i)=mean(mean(mean(image(nbox(i,1):nbox(i,1)+noise_box,nbox(i,2):nbox(i,2)+noise_box,nbox(i,3):nbox(i,3)+noise_box_z)))); end
    min_no=min(avr);
    Nf_1=ceil(Nf/4)+1; Nf_2=floor(Nf*3/4);
    Npe_1=ceil(Npe/4)+1;Npe_2=floor(Npe*3/4);
    Npe2_1=ceil(Npe2/4)+1;Npe2_2=floor(Npe2*3/4);
    mask=image(Nf_1:Nf_2,Npe_1:Npe_2,Npe2_1:Npe2_2)>(min_no*avr_mul);
    norm=sum(sum(sum(image(Nf_1:Nf_2,Npe_1:Npe_2,Npe2_1:Npe2_2).*mask)))/sum(sum(sum(mask)))*signal_mul;
else
    nbox(1,:)=[noise_border+1,noise_border+1];
    nbox(2,:)=[Nf-noise_border-noise_box,noise_border+1];
    nbox(3,:)=[noise_border+1,Npe-noise_border-noise_box];
    nbox(4,:)=[Nf-noise_border-noise_box,Npe-noise_border-noise_box];
    for i=1:4, avr(i)=mean(mean(mean(image(nbox(i,1):nbox(i,1)+noise_box,nbox(i,2):nbox(i,2)+noise_box)))); end
    min_no=min(avr);
    Nf_1=ceil(Nf/4)+1; Nf_2=floor(Nf*3/4);
    Npe_1=ceil(Npe/4)+1;Npe_2=floor(Npe*3/4);
    mask=image(Nf_1:Nf_2,Npe_1:Npe_2,1:Npe2)>(min_no*avr_mul);
    norm=sum(sum(sum(image(Nf_1:Nf_2,Npe_1:Npe_2,1:Npe2).*mask)))/sum(sum(sum(mask)))*signal_mul;
end
