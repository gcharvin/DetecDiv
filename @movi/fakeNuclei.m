function fakeNuclei(obj,trapnumber,inputpoly)

if nargin==2
    inputpoly=[];
end

if numel(inputpoly)==0 % have to pick up poly
obj.trap(trapnumber).view; % display cell of interest

h=findobj('Tag',['Trap' obj.trap(trapnumber).id]);
    
    %h.Children(5).Tag
    
hp=findobj(h,'Type','Axes');

for i=1:numel(hp)
   if strfind(hp(i).Title.String,'Raw')
      % i
       break
   end
end
    
% find handle of graph and select ellipse

xc=size(obj.trap(trapnumber).gfp,2)/2;
yc=size(obj.trap(trapnumber).gfp,1)/2;
sizx=5; 
sizy=7;

 windo=[xc-sizx yc-sizy 2*sizx 2*sizy];
 roi = imellipse(hp(i),windo);
 inputpoly = wait(roi);
 delete(roi);
end

obj.cavity.inputpoly=inputpoly;
 % create structure for segmentation

bw=poly2mask(inputpoly(:,1),inputpoly(:,2),size(obj.trap(trapnumber).gfp,1),size(obj.trap(trapnumber).gfp,2));

bwtot=bw;
bwtot2=~bw;
zer=zeros(size(bw));
zertot=zeros(size(bw));

for i=1:obj.nframes-1
    bwtot=cat(3,bwtot,bw);
    bwtot2=cat(3,bwtot2,~bw);
    zertot=cat(3,zertot,zer);
end

%size(bwtot),size(bwtot2),size(zertot)

classi=uint8(cat(4,255*bwtot2,255*bwtot,zertot));
classi=permute(classi,[1 2 4 3]);

track=bwtot;

traintrack=uint8(cat(4,255*bwtot,128*bwtot,zertot));
traintrack=permute(traintrack,[1 2 4 3]);


for i=1:numel(obj.trap)
obj.trap(i).load ; % load trap data

obj.trap(i).classi=classi;

%size(track)
obj.trap(i).track=track;
obj.trap(i).traintrack=traintrack;
obj.trap(i).computefluo;

obj.trap(i).save
end

 
 
 
 
 
 