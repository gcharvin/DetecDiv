function [positions scores]=loadData_findTraps(img,pattern,thr)

% position provides the list of boundaries for the traps
%img = rgb2gray(img);

c = normxcorr2(pattern,img);

%figure, imshow(img)
%figure, imshow(pattern,[])
%figure, surf(c), shading flat

%thr=0.5; % threshold for detected peaks

BW = im2bw(c,thr);

pp = regionprops(BW,'centroid');
pos = round(cat(1, pp.Centroid));

% orien=imrotate(img,180);
% c2 = normxcorr2(pattern,orien);
% 
% BW = im2bw(c2,thr);
% BW=imrotate(BW,180);
% 
% pp = regionprops(BW,'centroid');
% pos2 = round(cat(1, pp.Centroid));
% 
% pos=[pos ; pos2];


%    [tmppos2 scores2]=findTraps(orien,obj.processing.roi.pattern,thr);
%    tmppos=[tmppos; tmppos2];
%    scores=[scores scores2]; % HERE 
   
%positions=fliplr(positions);

%positions=zeros(1,4);
%scores=0;
positions=[];
scores=[];
%positions.minex=[];
%positions.maxex=[];
%positions.miney=[];
%positions.maxey=[];

cc=1;
%figure;
%size(img)
%size(pattern)

for ex=1:size(pos,1)
    
    minex=pos(ex,1)-size(pattern,2);
    maxex=pos(ex,1);
    miney=pos(ex,2)-size(pattern,1);
    maxey=pos(ex,2);
    
    if minex<1
        continue
    end
    if miney<1
        continue
    end
    if maxex>size(img,2)
        continue
    end
    
    if maxey>size(img,1)
        continue
    end
    
    positions(cc,1)=miney;
    positions(cc,3)=minex;
    positions(cc,2)=maxey;
    positions(cc,4)=maxex;
    
    scores(cc)=c(pos(ex,2),pos(ex,1)); % computing scores 
    
    
    %imgout=img(minex:maxex,miney:maxey);
    %imshow(imgout,[]);
    %title(num2str(ex));
    %pause(0.1);
    %close
    
    cc=cc+1;
end


end