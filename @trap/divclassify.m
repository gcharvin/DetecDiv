function divclassify(obj)

if numel(obj.gfp)==0
              obj.load;
end

% identifies correct division times based on training set 

%if nargin==2
% single frame to be classifed using exisiting training set
%    frames=obj.frame;
%else
% all frames to be classifed
frames=1:size(obj.traintrack,4);
%end

if numel(obj.div.tree)~=0
 tree=obj.div.tree;  
else
 [M,Y]=collectDivTrapData(obj);
 tree = fitctree(M,Y);
  imp = 1000*predictorImportance(tree)
  %size(imp)
end

% two cases : 1) trap has been used for training, therefore classification
% is not operated on this trap. This assumes that data are correct 
% 2) classification has not been done on this trap

if sum(obj.div.reject)>0 % this trap is a training set
    
    fprintf('This trap is a training set for the division classifier\n');
    
    fprintf('Therefore, it cannot be classified !!!\n');
    
    obj.div.classi=obj.div.raw & ~obj.div.reject;
    obj.div.dead=obj.div.reject==2;
    return; 
end
    
    % collect peaks

%M=[]; % observations
nucleus=0;

ns=1;
M=zeros(1,4*(2*ns+1));

peaks=find(obj.div.raw==1);

%goodframes=zeros(1,size(obj.gfp,3));
%goodframes(min(size(obj.gfp,3),obj.div.stop+1):end)=0;

%nevents=sum(obj.div.raw & goodframes);
%peaks=find(obj.div.raw==1 & goodframes);

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

%dd=0;
for i=peaks
   
    mine=max(1,i-ns);
    maxe=min(numel(fluodiff),i+ns);
    dd=0;
    %1-(i-ns-mine):2*ns+1-(i+ns-maxe)
    
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
    
    
    cc=cc+1;
end

Y=predict(tree,M);

pix=Y==0; % accepted divisions
obj.div.classi(peaks(pix))=1;

pix=Y==2; % dead weird divisions
obj.div.dead(peaks(pix))=1;




               




