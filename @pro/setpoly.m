function setpoly(obj,trapnumber)

% set different polygons used to classify divisions

obj.cavity.inputpoly=[]; % total cavity region, also used by fake nuclei to set nuclei size; % also provides the center of the cavity
obj.cavity.rect=[]; % window at the top of cavity



if nargin==1
    trapnumber=1;
end

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
    
% first generate the perimeter of the whole cavity

xc=size(obj.trap(trapnumber).gfp,2)/2;
yc=size(obj.trap(trapnumber).gfp,1)/2;
sizx=15; 
sizy=15;

windo=[xc-sizx yc-sizy 2*sizx 2*sizy];
 
roi = imellipse(hp(i),windo);

 inputpoly = wait(roi);
 delete(roi);
 obj.cavity.inputpoly=inputpoly;

 xc=mean(inputpoly(:,1));
 yc=mean(inputpoly(:,2));
 
 % second generate rectangle for different regions in the cavity 
 
 sizx=[7 7 10 15];
 sizy=1.5;
 
offsety=[-12 10 13 16];

for k=1:4
 x=[xc-sizx(k) xc-sizx(k) xc+sizx(k) xc+sizx(k) xc-sizx(k)];
 y=[yc-sizy+offsety(k) yc+sizy+offsety(k) yc+sizy+offsety(k) yc-sizy+offsety(k) yc-sizy+offsety(k)];
 
 obj.cavity.rect(:,:,k)=[x'  y'];
 h=line(x,y,'Color','r');
end
 

for i=1:numel(obj.trap)
    obj.trap(i).data.cavity=obj.cavity;
end