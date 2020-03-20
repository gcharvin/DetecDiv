function setpixclassifier(obj,str,opt)

% set the classifier for pixel according to specific rules

% if 'str'==path, then load/save a classifier in a given path
% in this case opt=='save' : saves all existing training data in the given
% file; opt=='load' : load classifer from eisiting file;
% file; opt=='append' : load classifer from eisiting file, then add
% movi training data to the existing classifer

if nargin<3
    opt='load';
end

obj.pixclassifier=[];

obj.pixclassifierpath=str;



Xtmp=[];
Ytmp=[];


if strcmp(opt,'load') || strcmp(opt,'append')
    
    
    if exist(str)
        load(str);
        obj.pixclassifier=tree;
    else
        
        fprintf('Classifier file not found \n')
        
        if strcmp(opt,'load')
        return;
        end
    end
    
    
end




if strcmp(opt,'save') || strcmp(opt,'append')
    
    for k=1:numel(obj.trap)
        
        tra=obj.trap(k);
        
        if numel(tra.gfp)==0
            tra.load;
        end
        
        Nucleus=tra.train(:,:,2,:);
        
        Nucleus=permute(Nucleus,[1 2 4 3]);
        pixNucleus=find(Nucleus~=0);
        
        tmp=sum(Nucleus,1);
        tmp=sum(tmp,2);
        framNucleus=find(tmp~=0); %frames with nucleus training
        
        %listNucleus=obj.gfp(pixNucleus);
        
        Bck=tra.train(:,:,1,:);
        Bck=permute(Bck,[1 2 4 3]);
        pixBck=find(Bck~=0);
        
        tmp=sum(Bck,1);
        tmp=sum(tmp,2);
        framBck=find(tmp~=0); %frames with background training
        
        %listBck=obj.gfp(pixBck);
        
        fram=unique([framNucleus ; framBck]); % all frames in which training occured
        
        subgfp=tra.gfp(:,:,fram,tra.gfpchannel);
        %subgfp=tra.gfp(:,:,fram);

        pred=tra.pixpredictors;
        
        npred=length(pred); % number of predictors used
        %pred=zeros(size(subgfp,1),size(subgfp,2),1,npred);
        
        %npred=1;
        
        X=zeros(1,npred);
        Y=zeros(1,1);
        
        cc=1;
        
        if numel(fram)>0
           obj.intensity=obj.trap(k).intensity; 
        end
        
        for i=1:length(fram) % loop on all frames
            %     tmp1 = subgfp(:,:,i); %raw image
            %     tmp2 = imgaussfilt(subgfp(:,:,i),0.01); % gaussian filter, sigma=2
            %     tmp3 = zeros(size(tmp1));%imgaussfilt(subgfp(:,:,i),1); % gaussian filter, sigma=4
            %     H = fspecial('log',20,0.5);
            %     tmp4 = imfilter(subgfp(:,:,i),H,'replicate'); %laplacian of gaussian
            
            Nuclpix=find(tra.train(:,:,2,fram(i))~=0);
            Bckpix=find(tra.train(:,:,1,fram(i))~=0);
            
              %%%%
         tmpim=subgfp(:,:,i);
   % limi=stretchlim(tmpim,[0.1 obj.trap(k).intensity]);
   % limi(2)=max(limi(2),1.2*limi(1));
    
   % tmpim = imadjust(tmpim,[limi(1) limi(2)],[0 1]);
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
        
        % Nucleus=tmp.train(:,:,2,:);
        % Nucleus=permute(Nucleus,[1 2 4 3]);
        % pixNucleus=find(Nucleus~=0);
        % listNucleus=tmp.gfp(pixNucleus);
        %
        %
        % Bck=tmp.train(:,:,1,:);
        % Bck=permute(Bck,[1 2 4 3]);
        % pixBck=find(Bck~=0);
        % listBck=tmp.gfp(pixBck);
        %
        % if numel(listNucleus)==0 && numel(listBck)==0
        %     continue
        % end
        %
        % Xtmp=zeros(length(pixNucleus)+length(pixBck),1);
        %
        % Xtmp=double([listNucleus ; listBck]); % predictors
        % Ytmp=[ones(length(pixNucleus),1); zeros(length(pixBck),1)]; % ground truth
        
        % fprintf('.')
        %
        %  if mod(k,50)==0
        %       fprintf('\n');
        %  end
        
        
        if numel(Y)==1
            continue
        end
        
        Xtmp=[Xtmp ; X];
        Ytmp=[Ytmp ; Y'];
        
        
        
    end
    
    X=Xtmp;
    Y=Ytmp;
    
    if numel(Y)==0
        fprintf('there is no training event in this movie ! quiting...\n');
        return;
    end
    
   % numel(Y)
    
    if strcmp(opt,'save')
        tree = fitctree(X,Y);
    end
    

    if strcmp(opt,'append')
        
      
        if numel(obj.pixclassifier)~=0
        X= [obj.pixclassifier.X ; X];
        Y= [obj.pixclassifier.Y ; Y];
        end
        
        [X ix]=unique(X,'rows'); % remove doublons. 
        Y=Y(ix);
        
        
        tree = fitctree(X,Y);
        %size(obj.pixclassifier.Y)
        %size(Y)
    end
    
    imp = 1000*predictorImportance(tree);
    save(str,'tree');
end



obj.pixclassifier=tree;

for i=1:numel(obj.trap)
    obj.trap(i).pixtree=tree;
    
    obj.trap(i).intensity=obj.intensity;
end






