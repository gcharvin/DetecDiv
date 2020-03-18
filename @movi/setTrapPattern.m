function setTrapPattern(obj,sizesquare)

% load first phase image 

img1=readImage(obj,1,obj.PhaseChannel);

if nargin==2
    sz=sizesquare;
else
    sz=100;
end

windo=[783 91; 783+sz  91; 783+sz 91+sz; 783 91+sz];

display=1;

[poly,pattern]=setPattern(img1,windo,display);

obj.pattern=pattern;


%eval(['save ' obj.filename '-pattern.mat' ])

function [poly,pattern]=setPattern(img1,windo,display)
% this function sets a window to identify patterns in image


if display==1
hfig=figure('Position',[100 100 1000 1000]);

warning off all
imshow(img1,[]);
warning on all

title('Please double click on ROI when done !');
hax=gca;

roi = impoly(hax,windo);
poly = wait(roi);
else
poly=windo;    
end


minex=round(min(poly(:,1)));
maxex=round(max(poly(:,1)));

miney=round(min(poly(:,2)));
maxey=round(max(poly(:,2)));

pattern= img1(miney:maxey,minex:maxex);

if display==1
close(hfig);
end

%figure, imshow(pattern,[]);
%uiwait(hfig); disp('figure closed')
