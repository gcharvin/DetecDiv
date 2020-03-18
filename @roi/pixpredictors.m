function pred=pixpredictors(obj)

pred=[];
pred.img=[];
pred.fcn=[];

cc=1;
% pred 1

pred(cc).fcn=@(x) x;  % raw image
cc=cc+1;
% pred 2 

sigma=[1 2 3 4 5 6];
for i=1:length(sigma)
pred(cc).fcn=@(x) imgaussfilt(x,sigma(i)); % gaussian filter
cc=cc+1;
end

sigma=[ 0.5 1 2 5];
for i=1:length(sigma)
pred(cc).fcn=@(x) imfilter(x,fspecial('log',10,sigma(i)),'replicate'); % laplacian of gaussian filter
cc=cc+1;
end

pred(cc).fcn=@(x) medfilt2(x);
cc=cc+1;

pred(cc).fcn=@(x) stdfilt(x);
cc=cc+1;

pred(cc).fcn=@(x) rangefilt(x);
cc=cc+1;

pred(cc).fcn=@(x) entropyfilt(x);
cc=cc+1;


