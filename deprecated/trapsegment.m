function trapsegment(trap)

% set cavity poly
trap.view; % display cell of interest

h=findobj('Tag',['Trap' trap.id]);
    
    %h.Children(5).Tag
    
hp=findobj(h,'Type','Axes');

for i=1:numel(hp)
   if strfind(hp(i).Title.String,'Raw')
      % i
       break
   end
end
    
% find handle of graph and select ellipse

xc=size(trap.gfp,2)/2;
yc=size(trap.gfp,1)/2;
sizx=5; 
sizy=7;

 windo=[xc-sizx yc-sizy 2*sizx 2*sizy];
 roi = imellipse(hp(i),windo);
 inputpoly = wait(roi);
 delete(roi);
 
cavity=poly2mask(inputpoly(:,1),inputpoly(:,2),size(trap.gfp,1),size(trap.gfp,2));


for fr=1:size(trap.gfp,3)
    
I=trap.gfp(:,:,fr,trap.phasechannel);


bw=logical(trap.track(:,:,fr));

%figure, imshow(bw,[]);
%return;
 %stat=regionprops(bw,'Centroid');
 %xc=round(stat.Centroid(1));
 %yc=round(stat.Centroid(2));


[level em] = graythresh(I);
BW = imbinarize(I,level);

BW=BW | ~cavity;

%figure, imshow(BW,[]);

m=bwdist(BW);
%figure, imshow(BW,[]);

if sum(bw(:))>0
dist(fr)=mean(m(bw));

else
dist(fr)=0;
end

%re=dist(yc,xc)

%imshowpair(I,BW,'montage')

end

figure, plot(dist)


