function pixclassify(obj,frame)

% to apply on traps :
%a.trap=arrayfun( @(x) x.pixclassify, a.trap );
%end

if numel(obj.gfp)==0
              obj.load;
end
    
if nargin==2
    % single frame to be classifed using exisiting training set
    frames=obj.frame;
    
else
    
    % all frames to be classifed
    
    frames=1:size(obj.train,4);
end

if numel(obj.pixtree)~=0
    tree=obj.pixtree;
else
    % build matrix with predictors from all frames
    % TO DO take all traps , or even a larger class of predictors ?
    
    % adding more predictors : Gaussian smoothing, Laplacian of gaussian,
    % Gaussian gradient magnitude
    
    
    
    Nucleus=obj.train(:,:,2,:);
    
    Nucleus=permute(Nucleus,[1 2 4 3]);
    pixNucleus=find(Nucleus~=0);
    
    tmp=sum(Nucleus,1);
    tmp=sum(tmp,2);
    framNucleus=find(tmp~=0); %frames with nucleus training
    
    %listNucleus=obj.gfp(pixNucleus);
    
    Bck=obj.train(:,:,1,:);
    Bck=permute(Bck,[1 2 4 3]);
    pixBck=find(Bck~=0);
    
    tmp=sum(Bck,1);
    tmp=sum(tmp,2);
    framBck=find(tmp~=0); %frames with background training
    
    %listBck=obj.gfp(pixBck);
    
    fram=unique([framNucleus ; framBck]); % all frames in which training occured
    
    subgfp=obj.gfp(:,:,fram,obj.gfpchannel);
    %figure, imshow(subgfp,[]);
    
   
    
   % figure, imshow(subgfp,[]);
    
    pred=obj.pixpredictors;
    
    npred=length(pred); % number of predictors used
    %pred=zeros(size(subgfp,1),size(subgfp,2),1,npred);
    
    %npred=1;
    
    X=zeros(1,npred);
    Y=zeros(1,1);
    
    cc=1;
    for i=1:length(fram) % loop on all frames
        %     tmp1 = subgfp(:,:,i); %raw image
        %     tmp2 = imgaussfilt(subgfp(:,:,i),0.01); % gaussian filter, sigma=2
        %     tmp3 = zeros(size(tmp1));%imgaussfilt(subgfp(:,:,i),1); % gaussian filter, sigma=4
        %     H = fspecial('log',20,0.5);
        %     tmp4 = imfilter(subgfp(:,:,i),H,'replicate'); %laplacian of gaussian
        
        Nuclpix=find(obj.train(:,:,2,fram(i))~=0);
        Bckpix=find(obj.train(:,:,1,fram(i))~=0);
        
        
         %%%% in case image must be normalized
         tmpim=subgfp(:,:,i);
%     limi=stretchlim(tmpim,[0.1 obj.intensity]);
%     limi(2)=max(limi(2),1.2*limi(1));
%     
%     tmpim = imadjust(tmpim,[limi(1) limi(2)],[0 1]);
    %%%%
        
        for j=1:npred
            pred(j).img= pred(j).fcn(tmpim); % compute image transform for specific preditor
            
            %tmp
            X(cc:length(Nuclpix)+cc-1,j)=pred(j).img(Nuclpix);
            Y(cc:length(Nuclpix)+cc-1)= ones(length(Nuclpix),1);
            
            ce=cc+length(Nuclpix);
            
            X(ce:length(Bckpix)+ce-1,j)=pred(j).img(Bckpix);
            Y(ce:length(Bckpix)+ce-1)= zeros(length(Bckpix),1);
            
        end
        
        cc=cc+length(Bckpix);
        
        
        %  figure, imshow(pred(:,:,i,1),[]);
        %  figure, imshow(pred(:,:,i,2),[]);
        %  figure, imshow(pred(:,:,i,3),[]);
        %  figure, imshow(pred(:,:,i,4),[]);
        
        
        %      X(cc:length(Nuclpix)+cc-1,1:npred)=[tmp1(Nuclpix) tmp2(Nuclpix) tmp3(Nuclpix) tmp4(Nuclpix)];
        %      Y=[Y ; ones(length(Nuclpix),1)];
        %      cc=cc+length(Nuclpix);
        %
        %
        %      X(cc:length(Bckpix)+cc-1,1:npred)=[tmp1(Bckpix) tmp2(Bckpix) tmp3(Bckpix) tmp4(Bckpix)];
        %      Y=[Y ; zeros(length(Bckpix),1)];
        %      cc=cc+length(Bckpix);
    end
    
    %X=X(2:end,:); Y=Y(2:end);
    
    %%X=double([listNucleus ; listBck]); % predictors
    %Y=[ones(length(pixNucleus),1); zeros(length(pixBck),1)]; % ground truth
    
    %size(X)
    
    tree = fitctree(X,Y); % decision tree
    
    %tree = fitcensemble(X,Y,'NumLearningCycles',100); %,'CrossVal','on') ;
    
    %Mdl = TreeBagger(50,X,Y,'OOBPrediction','On',...
    %    'Method','classification')
    %
    % figure;
    % oobErrorBaggedEnsemble = oobError(Mdl);
    % plot(oobErrorBaggedEnsemble)
    % xlabel 'Number of grown trees';
    % ylabel 'Out-of-bag classification error';
    
    %tree
    imp = 1000*predictorImportance(tree)
    
    
    % kflc = kfoldLoss(tree,'Mode','cumulative');
    % figure;
    % plot(kflc);
    % ylabel('10-fold Misclassification rate');
    % xlabel('Learning cycle');
    
    
end

%[X Y(1,:)']


% new observations to predict

% get trained data
    
imoutrgb=uint8(zeros(size(obj.gfp,1),size(obj.gfp,2),length(frames),3));


%     %
%
%     Nucleus=obj.train(:,:,2,:);
%
% Nucleus=permute(Nucleus,[1 2 4 3]);
% pixNucleus=find(Nucleus~=0);
%
% tmp=sum(Nucleus,1);
% tmp=sum(tmp,2);
% framNucleus=find(tmp~=0); %frames with nucleus training
%
% %listNucleus=obj.gfp(pixNucleus);
%
% Bck=obj.train(:,:,1,:);
% Bck=permute(Bck,[1 2 4 3]);
% pixBck=find(Bck~=0);
%
% tmp=sum(Bck,1);
% tmp=sum(tmp,2);
% framBck=find(tmp~=0); %frames with background training
%
% %listBck=obj.gfp(pixBck);
%
% fram=unique([framNucleus ; framBck]); % all frames in which training occured
%
% subgfp=obj.gfp(:,:,fram);

pred=obj.pixpredictors;

npred=length(pred); % number of predictors used
%pred=zeros(size(subgfp,1),size(subgfp,2),1,npred);

%npred=1;

cc=1;
ce=1;


%tic;
reverseStr='';
for i=frames % loop on all frames
    
    
     %   i 
    Nucleus=obj.train(:,:,2,i); %get training data
    Bck=obj.train(:,:,1,i);
    Nucleus=permute(Nucleus,[1 2 4 3]);
    Bck=permute(Bck,[1 2 4 3]);
    
    newPix= find(Nucleus==0 & Bck==0); % virgin pixels to evaluate
    
    Xnew=zeros(1,npred);
    
    
       %%%%
         tmpim=obj.gfp(:,:,i,obj.gfpchannel);
%     limi=stretchlim(tmpim,[0.1 obj.intensity]);
%     limi(2)=max(limi(2),1.2*limi(1));
%     
%     tmpim = imadjust(tmpim,[limi(1) limi(2)],[0 1]);
    %%%%
    
    
    for j=1:npred
        pred(j).img= pred(j).fcn(tmpim); % compute image transform for specific preditor
        
        %tmp
        Xnew(1:length(newPix),j)=pred(j).img(newPix);
        
    end
    
    %cc=cc+length(newPix);
    
    
    %  figure, imshow(pred(:,:,i,1),[]);
    %  figure, imshow(pred(:,:,i,2),[]);
    %  figure, imshow(pred(:,:,i,3),[]);
    %  figure, imshow(pred(:,:,i,4),[]);
    
    
    %      X(cc:length(Nuclpix)+cc-1,1:npred)=[tmp1(Nuclpix) tmp2(Nuclpix) tmp3(Nuclpix) tmp4(Nuclpix)];
    %      Y=[Y ; ones(length(Nuclpix),1)];
    %      cc=cc+length(Nuclpix);
    %
    %
    %      X(cc:length(Bckpix)+cc-1,1:npred)=[tmp1(Bckpix) tmp2(Bckpix) tmp3(Bckpix) tmp4(Bckpix)];
    %      Y=[Y ; zeros(length(Bckpix),1)];
    %      cc=cc+length(Bckpix);
    
    %Xnew=Xnew(2:end,:); Y=Y(2:end);
    
    Ynew=predict(tree,Xnew);
    
    %Ynew=str2double(cell2mat(Ynew));
    
    % build output image (single frame)
    
    imout=uint8(zeros(size(obj.gfp,1),size(obj.gfp,2)));
    
    %i,size(newPix), size(Ynew)
    
    imout(newPix)=Ynew;
    imout(Nucleus~=0)=1;
    imout(Bck~=0)=0;
    
    imout=imclose(imout,strel('Disk',1));
    
    % watershed is disabled --> try to use cutting using segmentation
    
    % % refine by using a watershed algorithm
    %
    % BW=bwdist(~imout);
    %
    % %figure, imshow(BW,[])
    %
    % BW=-BW;
    % %BW(~imout(:,:,i))=Inf;
    %
    % BW = imhmax(BW,2);
    % labels = double(watershed(BW,8)).*double(imout);
    % %figure, imshow(labels,[])
    %
    %
    % imout=labels>0;
    
    imout=bwareaopen(imout,4,4);
    
    %obj.track(:,:,i)=imout(:,:,i);
    
    % build 3 channel composite image
    
    %size(imoutrgb)
    
    %size(imout)
    %size(imoutrgb)
    
    imoutrgb(:,:,ce,2)=255*imout; %+0.5*Nucleus;
    imoutrgb(:,:,ce,1)=255*uint8(imout==0); %+0.5*Bck;
    

    
    if mod(ce-1,50)==0
     msg = sprintf('%d / %d Frames classified', ce , numel(frames) ); %Don't forget this semicolon
     msg=[msg ' for trap ' obj.id];
     
    fprintf([reverseStr, msg]);
    reverseStr = repmat(sprintf('\b'), 1, length(msg));
    end
        ce=ce+1;
    
end
%%size(imoutrgb)
fprintf('\n');


imoutrgb=permute(imoutrgb,[1 2 4 3]);

%size(imoutrgb)
%size(obj.classi)

%size(imoutrgb)
%size(obj.classi(:,:,:,frames))
obj.classi(:,:,:,frames)=imoutrgb;
obj.traintrack=uint8(zeros(size(obj.classi))); % clear object training

%obj.traintrack=permute(obj.traintrack,[1 2 4 3]);

obj.traintrack(:,:,2,frames)=0.5*obj.classi(:,:,2,frames); % displays training data for tracking

%obj.view(obj.frame);

% frames2=frames+1; % shift by one frame to ease motion display
% frames2=frames2(frames2<=size(obj.classi,4));
% obj.traintrack(:,:,1,frames2)=0.5*obj.classi(:,:,2,frames(1:numel(frames2)));

%obj.traintrack=permute(obj.traintrack,[1 2 4 3]);

% watershed segmentation
% BWstore=BW;
% BW=bwdist(~BW);
% BW = imhmax(BW,2);
% labels = double(watershed(-BW,8)).*BWstore;
% %figure, imshow(labels,[]);
%
% warning off all
% tmp = imopen(labels > 0, strel('disk', 3));
% warning on all
% %tmp = bwareaopen(tmp, 50);
%
% newlabels = labels .* tmp; % remove small features
%
% labels = bwlabel(newlabels>0);
%
% % filter out excentric contours
%
%
% stats = regionprops(labels,I,'Area','Eccentricity','MeanIntensity','Centroid','PixelValues');
%
%
% idx = find([stats.Area] > 50 & [stats.Eccentricity] < 0.95);
% labels = bwlabel(ismember(labels, idx));








