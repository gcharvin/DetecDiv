  function [M,Y]=collectDivTrapData(obj)
   % collect division training events in a given trap 
   
   if numel(obj.gfp)==0
              obj.load;
   end

      frames=1:size(obj.traintrack,4);
%end

if sum(obj.div.reject)==0 % quit if the trap is not a training set 
    M=[];
    Y=[];
    return;
end


% use training set for building classification tree

ns=1;
M=zeros(1,2*ns+1); % takes peak + 3 time pints on the left and 3 on the right
Y=[]; % ground truth % puts '1' when peak is real, and '0' otherwise

cc=1;

fra=[];

goodframes=ones(1,size(obj.gfp,3)-1);
goodframes(min(size(obj.gfp,3)-1,obj.div.stop+1):end)=0;

%size(goodframes),size(obj.div.raw)
nevents=sum(obj.div.raw & goodframes);
peaks=find(obj.div.raw==1 & goodframes);


fluo=obj.data.fluo(:,obj.gfpchannel);
fluodiff=obj.data.fluodiff; % change intensity of gfp channel
phc=obj.data.phc; % phase image intensity in 4 different locations (fixed roi)
dist=obj.data.dist; % distance of nucleus to border of cell (as defined using ph contrast image)
cv=obj.data.cv; % cv of fluo in a specific time window
isfirst=obj.data.isfirst;
motion= obj.data.motion; % displacement of nucleus over time from n-1th to nth frame
area= obj.data.area; % area of nucleus
da=obj.data.areadiff; % area change
exc=obj.data.ecc; % excentricity of nucleus
de= obj.data.eccdiff; % variation of excentircity
n=obj.data.nucl; % number of nuclei on frame
dn=obj.data.nucldiff; % change in number of nuclei

cc=1;

for i=peaks
   
    mine=max(1,i-ns);
    maxe=min(numel(fluodiff),i+ns);
    dd=0;
    
    %1-(i-ns-mine):2*ns+1-(i+ns-maxe)
    M(cc,dd+1-(i-ns-mine):dd+2*ns+1-(i+ns-maxe))=fluo(mine:maxe); dd=dd+(2*ns+1);
    M(cc,dd+1-(i-ns-mine):dd+2*ns+1-(i+ns-maxe))=fluodiff(mine:maxe); dd=dd+(2*ns+1);
    M(cc,dd+1-(i-ns-mine):dd+2*ns+1-(i+ns-maxe))=phc(mine:maxe,1); dd=dd+(2*ns+1);
    M(cc,dd+1-(i-ns-mine):dd+2*ns+1-(i+ns-maxe))=phc(mine:maxe,2); dd=dd+(2*ns+1);
    M(cc,dd+1-(i-ns-mine):dd+2*ns+1-(i+ns-maxe))=phc(mine:maxe,3); dd=dd+(2*ns+1);
    M(cc,dd+1-(i-ns-mine):dd+2*ns+1-(i+ns-maxe))=phc(mine:maxe,4); dd=dd+(2*ns+1);
    
    M(cc,dd+1-(i-ns-mine):dd+2*ns+1-(i+ns-maxe))=dist(mine:maxe); dd=dd+(2*ns+1);
    M(cc,dd+1-(i-ns-mine):dd+2*ns+1-(i+ns-maxe))=cv(mine:maxe); dd=dd+(2*ns+1);
    M(cc,dd+1-(i-ns-mine):dd+2*ns+1-(i+ns-maxe))=isfirst(mine:maxe); dd=dd+(2*ns+1);
    M(cc,dd+1-(i-ns-mine):dd+2*ns+1-(i+ns-maxe))=motion(mine:maxe); dd=dd+(2*ns+1);
    M(cc,dd+1-(i-ns-mine):dd+2*ns+1-(i+ns-maxe))=area(mine:maxe); dd=dd+(2*ns+1);
    M(cc,dd+1-(i-ns-mine):dd+2*ns+1-(i+ns-maxe))=da(mine:maxe); dd=dd+(2*ns+1);
    M(cc,dd+1-(i-ns-mine):dd+2*ns+1-(i+ns-maxe))=exc(mine:maxe); dd=dd+(2*ns+1);
    M(cc,dd+1-(i-ns-mine):dd+2*ns+1-(i+ns-maxe))=de(mine:maxe); dd=dd+(2*ns+1);
    M(cc,dd+1-(i-ns-mine):dd+2*ns+1-(i+ns-maxe))=n(mine:maxe); dd=dd+(2*ns+1);
    M(cc,dd+1-(i-ns-mine):dd+2*ns+1-(i+ns-maxe))=dn(mine:maxe); dd=dd+(2*ns+1);
    % add other predictors
    
    Y(cc)=0; 
    %i
     if obj.div.reject(i)==1
    Y(cc)=1;
     end
     
    if obj.div.reject(i)==2
    Y(cc)=2;
     end
    
    cc=cc+1;
end

% fluodiff=-diff(obj.fluo);
% 
% 
% for i=peaks
%    
%     mine=max(1,i-ns);
%     maxe=min(numel(fluodiff),i+ns);
%     
%     %1-(i-ns-mine):2*ns+1-(i+ns-maxe)
%     M(cc,1-(i-ns-mine):2*ns+1-(i+ns-maxe))=fluodiff(mine:maxe);
%     
%     if obj.div.reject(i)==1
%     Y(cc)=0;
%     else
%     Y(cc)=1;    
%     end
%     
%     
%     cc=cc+1;
% end



Y=Y';

if sum(M(:))==0 % in case there was training in this trap
    M=[]; 
end
%tree = fitctree(M,Y'); % build classification tree;