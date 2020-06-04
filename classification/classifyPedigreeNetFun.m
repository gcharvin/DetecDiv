function roiout=classifyPedigreeNetFun(roiobj,classif,classifier)

%load([path '/netCNN.mat']); % load the googlenet to get the input size of image

% now load and read video
fprintf('Load videos...\n');

%inputSize = netCNN.Layers(1).InputSize(1:2);

%inputSize=[size(roiobj.image,1) size(roiobj.image,2)];
inputSize = classifier.Layers(140).InputSize(1:2);

%return;
% x y size of the input movie (140th layer)
%for i=id
%fprintf(['Processing video:' num2str(i) '...\n']);
%load([mov.path '/labeled_video_' mov.trap(i).id '.mat']); % loads deep, vid, lab (categories of labels)

if numel(roiobj.image)==0
    roiobj.load;
end




pix=find(roiobj.channelid==classif.channel(1)); % find channels corresponding to trained data
im=roiobj.image(:,:,pix,:);

pix2=find(roiobj.channelid==classif.channel(2)); % find channels corresponding to trained data
im2=roiobj.image(:,:,pix2,:);

pixresults=findChannelID(roiobj,['results_' classif.strid]); 
if numel(pixresults)>0 
%pixresults=find(roiobj.channelid==cc); % find channels corresponding to trained data
roiobj.image(:,:,pixresults,:)=im2;%uint16(zeros(size(im,1),size(im,2),1,size(im,4)));
else
   % add channel is necessary 
   matrix=im2;
   rgb=[1 1 1];
   intensity=[0 0 0];
   pixresults=size(roiobj.image,3)+1;
   roiobj.addChannel(matrix,['results_' classif.strid],rgb,intensity);
end

%return;

disp('Formatting video before classification....');
%size(im)

%if numel(pix)==1
    % 'ok'
    
%end


disp('loop on all newly appearing buds in roi and classify...');

totpix=im2(:);

results=roiobj.results;
    results.(classif.strid)=[];
    results.(classif.strid).mother=[];
    
    
for k=1:max(totpix) % . loop on all cells in ROI
    
    for ll=1:size(im2,4) % find first frame at which it appears;
        tmp=im2(:,:,1,ll)==k;
        % k,sum(tmp(:))
        if sum(tmp(:))~=0
            fr=ll;
            break
        end
    end
    
   % k,fr
    if fr==1 % cell appears not on first frame----> skip to next cell
        continue
    end
    
    [video,cellindex]=formatVideo(im,im2,k,fr,inputSize);
   
    disp(['Cell ' num2str(k) ' appears on frame ' num2str(fr) ' and has ' num2str(numel(cellindex)) 'neighbors to check']);
    
    res=zeros(1,numel(video));
    
    for l=1:numel(video) % loop on all neighbors
      
     %   cel=cellindex(k);
    
    
    test=predict(classifier,video{l});
    
    [~, idx] = max(test,[],2);
    %idx
    labels = classifier.Layers(end).Classes;
    label = labels(idx);
    
    %if strcmp(label,
    if idx==2
       res(l)=cellindex(l); 
    end
    end
    
    %res
    pix=find(res>0,1,'first'); % in case there are multiple possibilities, then we need to compute probabilities
    res=res(pix);
    if numel(res)>0
    results.(classif.strid).mother(k)=res;
    end
   % pause
end

roiobj.results=results; 

roiout=roiobj;

%label = classify(classifier,video);

%label=[];

% lab=[];
% %if size(im,4)>nframes
% for i=1:narr
%    lab = [lab label{i}];
% end
%else
%label=label{1};
%end

%label=lab(1:size(im,4));

% results=roiobj.results;
%     results.(classif.strid)=[];
%     results.(classif.strid).id=zeros(1,size(im,4));
%     results.(classif.strid).labels=label';
%     results.(classif.strid).classes=classif.classes;
%
%   %  roiobj.results=results;
%
%     for i=1:numel(classif.classes)
%
%    pix=label==classif.classes{i};
%    results.(classif.strid).id(pix)=i;
%
%     end
%
% roiobj.results=results;
%
% roiout=roiobj;
%roiobj.clear;

% results.id=roiobj.id;
% results.path=roiobj.path;
% results.parent=roiobj.parent;
%
% % stores results locally during classification
%
% if exist([classif.path '/' classif.strid '_results.mat']) % this filles needs to be removed when classification starts ?
%     load([classif.path '/' classif.strid '_results.mat']) % load res variable
%     n=length(res);
%     res(n+1)={results};
% else
%
%    res={results};
% end
% save([classif.path '/' classif.strid '_results.mat'],'res');



%
% pix=label=='largebudded';
% mov.trap(i).div.deepLSTM(pix)=2;
%
% pix=label=='smallbudded';
% mov.trap(i).div.deepLSTM(pix)=1;
%
% pix=label=='unbudded';
% mov.trap(i).div.deepLSTM(pix)=0;


%mov.trap(i).div.deepLSTM=YPred;

function [vidout, cellindex]=formatVideo(im,im2,k,fr,inputSize)

msize=[120 120]; % size of window surrounding the bud
timespan=[-1:2]; % time span before and after bud emergence
% reverseStr='';

vidout={};
cellindex=[];

totphc=im;
meanphc=0.5*double(mean(totphc(:)));
maxphc=double(meanphc+0.7*(max(totphc(:))-meanphc));



frtot=fr+timespan;
minet=frtot>=1;
frtot=frtot(minet);
maxet=frtot<=size(im,4);
frtot=frtot(maxet); %  the collection of frame to extract 4D volume



% idetify neighbors on the frame of appearance
budBW=im2(:,:,1,fr)==k;
dil=imdilate(budBW,strel('Disk',10));
totObjects=im2(:,:,1,fr);
neighbors=totObjects(dil);
neighborsList=setxor(unique(neighbors(:)),[0 k]); % remove background and own cell

if numel(neighborsList)==0 % no neighboors !
    return;
end

for mm=1:numel(neighborsList)
    
    ccc=1;
    
    vid=uint8(zeros(msize(1),msize(2),3,numel(frtot)));
    
    %k,aa=cltmp(i).train.(classif.strid).mother(k),frtot
    pasok=0;
    
    for ll=frtot % for each bud , extract images with all possible neighbors %extract 4D volume around bud
        
        if ll<fr %image is fixed
            tmp=im2(:,:,1,fr)==k;
        else % image moves following the bud
            tmp=im2(:,:,1,ll)==k;
        end
        
        stat=regionprops(tmp,'Centroid');
        
        if numel(stat)==0 % the cell is not present on that frame; quitting collecting 4D data
            pasok=1;
            break
        end
        
        ox=round(stat(1).Centroid(1));
        oy=round(stat(1).Centroid(2));
        %ll
        
        arrx=ox-msize(1)/2:ox+msize(1)/2-1;
        arry=oy-msize(2)/2:oy+msize(2)/2-1;
        
        if ll>=fr
            
            l1=im2(:,:,1,ll)==k;
            l2=im2(:,:,1,ll)==neighborsList(mm);
            
            bw= l1 | l2; % bw image with pairs
            
            
            thr=5; % threshold to find regions of image close to neighbor
            bw1=bwdist(l1).*l2;
            bw1=bw1<thr & bw1>0;
            bw2=bwdist(l2).*l1;
            bw2=bw2<thr & bw2>0;
            bwtot= bw1 | bw2; % objects in close proximity
            bwtot=imdilate(bwtot,strel('Disk',3));
            bw= bw | bwtot; % mask with interestings pairs
            %bw=imdilate(bw,strel('Disk',10)); % dilate the whole mask a bit
            
        else % before bud emerges, takes only the mother into account
            
            bw=  im2(:,:,1,ll)==neighborsList(mm);
            % bw=imdilate(bw,strel('Disk',10)); % dilate the whole mask a bit
        end
        
        imtmp=uint16(zeros(size(im,1),size(im,2)));
        imtmp2=im(:,:,1,ll);
        imtmp(bw)=imtmp2(bw); % image in which only pixells associated with the pair are non zeros
        
        %arrx=arrx(arrx>=1); arrx=arrx(arrx<=size(imtmp,2));
        %arry=arry(arry>=1); arry=arry(arry<=size(imtmp,1));
        
        if sum(arrx<1)~=0
            pasok=1; break;
        end
         if sum(arry<1)~=0
            pasok=1; break;
         end
        if sum(arrx>size(imtmp,2))~=0
            pasok=1; break;
        end
         if sum(arry>size(imtmp,1))~=0
            pasok=1; break;
        end
        
        imcrop=imtmp(arry,arrx);
        imcrop=double(imadjust(imcrop,[meanphc/65535 maxphc/65535],[0 1]))/65535;
        imcrop=repmat(imcrop,[1 1 3]);

        %imcrop=im(arry,arrx,1,ll);
  
        % figure, imshow(uint8(256*imcrop),[]);
        %  return;
        vid(:,:,:,ccc)=uint8(256*imcrop);
        ccc=ccc+1;
    end
    
    vid = centerCrop(vid,inputSize);
    
    
    if pasok==1 % cell is lost during tracking , go to next cell
        %return;
        vidout={};
        cellindex=[];
        return;
    end
    cellindex(mm)=neighborsList(mm);
    vidout{mm}=vid;
end
    
    
    
    
    function videoResized = centerCrop(video,inputSize)
    
    sz = size(video);
    
    if sz(1) < sz(2)
        % Video is landscape
        idx = floor((sz(2) - sz(1))/2);
        video(:,1:(idx-1),:,:) = [];
        video(:,(sz(1)+1):end,:,:) = [];
        
    elseif sz(2) < sz(1)
        % Video is portrait
        idx = floor((sz(1) - sz(2))/2);
        video(1:(idx-1),:,:,:) = [];
        video((sz(2)+1):end,:,:,:) = [];
    end
    
    videoResized = imresize(video,inputSize(1:2));
    
    
    %analyzeNetwork(lgraph)
    
    
    
    
    %etc ...