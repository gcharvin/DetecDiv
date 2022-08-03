function [output himg]=displayFormattedTrainingSet(classif,varargin)

% display chosen images from the folder that contains formatted images for
% training

% future parameters will allow to choose whether randomly picked or
% specific images should be displayed.

% check the type of classifier : currently this function only for Image,
% LSTM and Pixel types

display=0;
n=6;
himg=[];
output={};


for i=1:numel(varargin)
    if strcmp(varargin{i},'Display')
        display=1;
    end
     if strcmp(varargin{i},'Nimages')
        n=varargin{i+1};;
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
            disp('there is no exprted dataset in folder; quitting...')
     
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
                
                
                n=3;
                maxe=min(n,numel(p)-2);
                if numel(p)>2

                    idx=randi(numel(p)-2,[1 maxe]);
                else
                    idx=[];
                end

               
                for j=idx
                    tmp=imread(fullfile(p(j).folder,p(j).name));
               %    aa=l(i).name
                    tmp=insertText(tmp,[1 1],l(i).name,'TextColor',[255 0 0],'BoxOpacity',0,'FontSize',9);
                    disp(['Display image: ' p(j).name ])
                    if cc==1
                        img=tmp;
                     
                    else
                        img(:,:,:,cc)=tmp;
                    end

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

                    idx=randi(numel(l)-2,[1 maxe]);
                else
                    idx=[];
                end

                cc=1;
                for j=idx
                    tmp=imread(fullfile(l(j).folder,l(j).name));
                    tmp2=imread(fullfile(l2(j).folder,l2(j).name));
                    tmp=imlincomb(0.75,tmp,0.25,tmp2);

                    disp(['Display image: ' l(j).name ])
                    if cc==1
                        img=tmp;
                    else
                        img(:,:,:,cc)=tmp;
                    end
                    cc=cc+1;
                end

                figure;
                himg=montage(img);
             %   title(l(i).name)
            end

end

fle=fullfile(pth,'sampleImage.png');
if display==0 
if exist(fle)
himg=imread(fle);
end
else
imwrite(himg.CData,fle);
himg=himg.CData;
end



