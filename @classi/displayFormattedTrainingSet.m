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

        classes=classif.classes;
        nfolder=fullfile(pth, 'trainingdataset/images');
        l=dir(nfolder);

        if numel(l)<=2
            disp('there is no exported dataset in folder; quitting...')
     
            return;
        end

        cd=0;

       ccc=1;
 cc=1;
 

        for i=3:numel(l)
            nsfolder=fullfile(nfolder, l(i).name);
            p=dir(nsfolder);

            disp(['Folder ' l(i).name ' has ' num2str(numel(p)-2) ' images' ])
            cd=cd+ numel(p)-2;

             output{ccc,1}=l(i).name;
             output{ccc,2}=numel(p)-2;
            
            if display
                
                
            %    n=10;
                maxe=min(n,numel(p)-2);
                if numel(p)>2

                    idx=randi([3 numel(p)],[1 maxe]);
                else
                    idx=[];
                end

               
                for j=idx
                 %   aa=p(j).name

                    tmp=imread(fullfile(p(j).folder,p(j).name));
               %    aa=l(i).name
                    fntsize=round(10*size(tmp,1)/50);
                    tmp=insertText(tmp,[1 1],l(i).name,'TextColor',[255 255 255],'BoxOpacity',0,'FontSize',fntsize);
                    disp(['Display image: ' p(j).name ])
                  %  if cc==1
                   %     img=tmp;
                     
                  %  else
                        img{cc}=tmp;
                  %  end

                    cc=cc+1;
                end

                
               % title(l(i).name)
                
           
      
            end
            ccc=ccc+1;
        end

             if display
             himg=montage(img);
             h=gcf;
             set(h,'Position',[100 100 800 600])
             end


        disp(['Total number of images in trainingset: ' num2str(cd)]);



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
                        img{cc}=tmp;
                %    end

                    % catch 
                    %  disp('could not display sample image');
                    % end
                    cc=cc+1;
                end

                figure;
                himg=montage(img);
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

fle=fullfile(pth,'sampleImage.png');
if display==0 
if exist(fle)
himg=imread(fle);
end
else
 if numel(himg)==0
     return
 end
 
 if numel(himg.CData)~=0
imwrite(himg.CData,fle);
 end
himg=himg.CData;
end



