function [output himg]=displayFormattedTrainingSet(classif,varargin)

% display chosen images from the folder that contains formatted images for
% training

% future parameters will allow to choose whether randomly picked or
% specific images should be displayed.

% check the type of classifier : currently this function only for Image,
% LSTM and Pixel types

display=0;
n=10;
himg=[];
output={};
img={};

for i=1:numel(varargin)
    if strcmp(varargin{i},'Display')
        display=1;
    end
     if strcmp(varargin{i},'Nimages')
        n=varargin{i+1};
     end

end

cate=classif.category{1};
pth=classif.getPath;

disp(['This classfication is of this type: ' cate]);
switch cate
 case {'Image','LSTM'}

    backend = "tiff";
    if isprop(classif,'trainingParam') && isfield(classif.trainingParam,'CNN_storage_backend')
        backend = lower(string(classif.trainingParam.CNN_storage_backend{end}));
    end
    isHDF5 = strcmp(backend,'hdf5');

    pth = classif.getPath;

    if ~isHDF5
        % --------------------------
        % ======= MODE TIFF ========
        % --------------------------
        nfolder = fullfile(pth, 'trainingdataset/images');
        l = dir(nfolder);

        if numel(l) <= 2
            disp('No exported TIFF dataset found.');
            return;
        end

        output={};
        img={};
        ccc=1; cc=1;
        totalImages = 0;

        for i=3:numel(l)
            className = l(i).name;
            nsfolder = fullfile(nfolder, className);
            p = dir(fullfile(nsfolder,'*.tif'));

            nb = numel(p);
            totalImages = totalImages + nb;

            output{ccc,1} = className;
            output{ccc,2} = nb;

            if display && nb>0
                maxe = min(n, nb);
                idx = randperm(nb, maxe);
                for j=idx
                    tmp = imread(fullfile(p(j).folder, p(j).name));
                    tmp = insertText(tmp, [1 1], className, ...
                        'TextColor',[255 255 255],'BoxOpacity',0,'FontSize',12);
                    img{cc} = tmp;
                    cc = cc + 1;
                end
            end
            ccc=ccc+1;
        end

        if display && ~isempty(img)
            himg = montage(img);
            h=gcf; set(h,'Position',[100 100 800 600]);
        end

        disp(['Total number of TIFF images in trainingset: ' num2str(totalImages)]);

    else
        % --------------------------
        % ======= MODE HDF5 ========
        % --------------------------
        h5File = fullfile(pth,'trainingdataset','framebank.h5');

        if ~isfile(h5File)
            disp('No HDF5 framebank found.');
            return;
        end

        classNames = h5read(h5File, '/classNames');   % 1×C strings
        labels     = double(h5read(h5File, '/labels')); % 1×N int
        totalFrames = numel(labels);

        output={};
        img={};
        cc=1;

        % Compter nb frames par classe
        for ci=1:numel(classNames)
            cname = classNames(ci);
            idx = find(labels == ci);   % frames correspondant à la classe

            output{ci,1} = cname;
            output{ci,2} = numel(idx);

            disp(['Class ' char(cname) ' has ' num2str(numel(idx)) ' frames']);

            if display && ~isempty(idx)
                pick = idx(randperm(numel(idx), min(n, numel(idx))));
                for f = pick
                    tmp = h5read(h5File, '/frames', [1 1 1 f], [Inf Inf 3 1]);
                    tmp = uint8(tmp);  % sécurité
                    tmp = insertText(tmp,[1 1],cname,'TextColor',[255 255 255], ...
                        'BoxOpacity',0,'FontSize',12);
                    img{cc}=tmp; cc=cc+1;
                end
            end
        end

        % Affichage montage
        if display && ~isempty(img)
            figure;
            himg = montage(img);
            h=gcf; set(h,'Position',[100 100 800 600]);
        end

        disp(['Total number of frames in HDF5 framebank: ' num2str(totalFrames)]);
    end


    case 'Pixel'

        classes=classif.classes;
        nfolder=fullfile(pth, 'trainingdataset/images');
        l=dir(nfolder);

        nfolder2=fullfile(pth, 'trainingdataset/labels');
        l2=dir(nfolder2);

        if numel(l)<=2
            disp('there is no exported dataset in folder; quitting...')

            return;
        end

        cd=numel(l)-2;
        disp(['Total number of images in trainingset: ' num2str(cd)]);

          output{1,1}='images';
          output{1,2}=cd;

           if display

                img=[];
                maxe=min(n,numel(l)-2);
                if numel(l)>2

                    idx=randi([3 numel(l)],[1 maxe]);
                else
                    idx=[];
                end

                cc=1;
                for j=idx

          
               %     try

               try
                    tmp=imread(fullfile(l(j).folder,l(j).name));

                    if strcmp(classif.description{3},'Solov2')
                       
                        tmp2=load(fullfile(l2(j).folder,l2(j).name));
                         mas=tmp2.masks;
                         lab=tmp2.labels;
                         dis= uint8(zeros(size(tmp,1:2)));
                        nm=size(mas,3);
                        cm=lines(numel(classif.classes));

                         for ii=1:nm
                               
                             bwtmp=tmp2.masks(:,:,ii);
                            
                        %   ttt=  tmp2.labels(ii)
                        pixc=find(matches(classif.classes,string(tmp2.labels(ii)))); % HERE
                        col=cm(pixc,:);
                        tmp=  insertObjectMask(tmp,bwtmp,'MaskColor',col,'Opacity',0.5,'LineOpacity',1,'LineWidth',2);

                         %       dis(mas(:,:,ii))=255*ii./size(mas,3);
                         end
                       %  tmp2=dis;
                       %tmp2=repmat(tmp2,[1 1 3]);
                       %  tmp2(:,:,2:3)=0;

                     
                    else
                         tmp2=imread(fullfile(l2(j).folder,l2(j).name));
                         tmp=imlincomb(0.75,tmp,0.25,tmp2);
                    end

              

               catch 
               end
               
                    disp(['Display image: ' l(j).name ])
               %     if cc==1
                %        img=tmp;
               %     else
                 %       size(tmp)
                %       class(tmp)
                try
                        img{cc}=tmp;
                catch

                end
                %    end

                    % catch 
                    %  disp('could not display sample image');
                    % end
                    cc=cc+1;
                end

                try
                figure;
                himg=montage(img);
                catch
                end
             %   title(l(i).name)
            end

    case 'Delta' % displays training set for Delta tracking 

        classes=classif.classes;
        nfolder=fullfile(pth, 'trainingdataset/images');
        l=dir(nfolder);

        nfolder2=fullfile(pth, 'trainingdataset/labels');
        l2=dir(nfolder2);

        if numel(l)<=2
            disp('there is no exported dataset in folder; quitting...')

            return;
        end

        cd=numel(l)-2;
        disp(['Total number of images in trainingset: ' num2str(cd)]);

          output{1,1}='images';
          output{1,2}=cd;

           if display

                img=[];
                maxe=min(n,numel(l)-2);
                if numel(l)>2

                    idx=randi([3 numel(l)],[1 maxe]);
                else
                    idx=[];
                end

                cc=1;
                for j=idx
                    load(fullfile(l(j).folder,l(j).name));
                    tmp=tmpcrop; % tmpcrop is troed in the file. 
                    tmp2=imread(fullfile(l2(j).folder,l2(j).name));
                   
    % aa=fullfile(l(j).folder,l(j).name)
            

                tmpa=repmat(tmp(:,:,1),[1 1 3]);
                tmpb=repmat(tmp(:,:,2),[1 1 3]);
                tmpc=repmat(tmp(:,:,3),[1 1 3]);
                tmpd=repmat(tmp(:,:,4),[1 1 3]);

                 tmp3=[tmpa tmpb tmpc tmpd  tmp2 ];
                   % tmp=imlincomb(0.75,tmp,0.25,tmp2);

                    disp(['Display image: ' l(j).name ])
               %     if cc==1
                %        img=tmp;
               %     else
                 %       size(tmp)
                %       class(tmp)
                        img{cc}=tmp3;
                %    end
                    cc=cc+1;
                end

                figure;
                himg=montage(img,'Size',[NaN 1]);
             %   title(l(i).name)
           end

      
  
end


% --- Write sampleImage.png in every case ---
fle = fullfile(pth, 'sampleImage.png');

if display
    % Mode affichage : on a himg = montage
    if ~isempty(himg)
        % himg = handle => récupérer l'image réelle
        if isgraphics(himg)
            sample = himg.CData;
        else
            sample = himg; % pourrait être déjà une image
        end
        imwrite(sample, fle);
        himg = sample; % on renvoie juste l'image
    end

else
    % Mode silencieux : lire sampleImage.png ou en créer un
    if isfile(fle)
        himg = imread(fle);
    else
        % fabriquer une image simple si aucune image n'a été générée
        if exist('img','var') && ~isempty(img)
            sample = img{1};   % première image trouvée
        else
            sample = uint8(255 * ones(100,100,3)); % placeholder blanc
        end
        imwrite(sample, fle);
        himg = sample;
    end
end



% fle=fullfile(pth,'sampleImage.png');
% if display==0 
% if exist(fle)
% himg=imread(fle);
% end
% else
%  if numel(himg)==0
%      return
%  end
% 
%  if numel(himg.CData)~=0
% imwrite(himg.CData,fle);
%  end
% himg=himg.CData;
% end



