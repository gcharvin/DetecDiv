function plottime(mov,trapid)

% plots cells in trap over time 

mov.trap(trapid).view; 
close

gfp=mov.trap(trapid).gfp;

avg=44:56;

im=gfp(avg,:,:,1); 
im=mean(im,1); 
im=permute(im,[2 3 1]);

figure, imshow(im,[]);

