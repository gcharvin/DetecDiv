function [row,col,match] = refineAnchorShift(ref,mov,r0,c0,tileH,tileW,estimateRow,estimateCol,subpixel)
% Refine a proposed translation against unresampled image pixels.
row=NaN; col=NaN; match=NaN;
ir=round(estimateRow); ic=round(estimateCol); radius=2;
[H,W]=size(ref);
rr=max([r0,1,1-ir+radius]):min([r0+tileH-1,H,H-ir-radius]);
cc=max([c0,1,1-ic+radius]):min([c0+tileW-1,W,W-ic-radius]);
if numel(rr)<16 || numel(cc)<16, return; end
rr=rr(1:max(1,ceil(numel(rr)/128)):end);
cc=cc(1:max(1,ceil(numel(cc)/128)):end);
a=ref(rr,cc); a=a-mean(a(:)); aa=sum(a(:).^2);
if aa<=eps, return; end
correlation=zeros(2*radius+1);
for dy=-radius:radius
    for dx=-radius:radius
        b=mov(rr+ir+dy,cc+ic+dx); b=b-mean(b(:));
        correlation(dy+radius+1,dx+radius+1)=sum(a(:).*b(:))/ ...
            max(eps,sqrt(aa*sum(b(:).^2)));
    end
end
[peak,ix]=max(correlation(:)); [py,px]=ind2sub(size(correlation),ix); match=peak;
if py==1 || px==1 || py==size(correlation,1) || px==size(correlation,2), return; end
row=ir+py-radius-1; col=ic+px-radius-1;
if subpixel && peak<1-1e-10
    row=row+quadraticOffset(correlation(py-1,px),correlation(py,px),correlation(py+1,px));
    col=col+quadraticOffset(correlation(py,px-1),correlation(py,px),correlation(py,px+1));
end
end

function value=quadraticOffset(a,b,c)
d=a-2*b+c;
if abs(d)<1e-12, value=0; else, value=max(-.5,min(.5,.5*(a-c)/d)); end
end
