function formatfordeepclassification(mov,trapsid,option)

gfp=[];

phasechannel=1;


if nargin==2
    option=0 ; % make videos for LSTM training or direct classification
end

if option==1 % build images for training
foldername='deeptrainingset';
if ~isfolder([mov.path '/' foldername])
%rmdir([mov.path '/' foldername],'s');
mkdir(mov.path,foldername)

str=[mov.path '/' foldername];

mkdir(str,'smallbudded')
mkdir(str,'largebudded')
mkdir(str,'unbudded')
end
str=[mov.path '/' foldername];
end

for i=trapsid
    fprintf(['Processing trap' num2str(i) ':\n']);
    % generate an rgb image with previous and next frames as colors
    
    if numel(mov.trap(i).gfp)==0
        mov.trap(i).load;
    end
    
    totphc=mov.trap(i).gfp(:,:,:,phasechannel);
    meanphc=0.5*double(mean(totphc(:)));
    maxphc=double(meanphc+0.7*(max(totphc(:))-meanphc));
    
    vid=uint8(zeros(size(mov.trap(i).gfp,1),size(mov.trap(i).gfp,2),3,size(mov.trap(i).gfp,4)));
    
    if ~isfield(mov.trap(i).div,'deep') % this is not a training set !
        mov.trap(i).div.deep=[];
        mov.trap(i).div.deepLSTM=[];
         mov.trap(i).div.deepCNN=[]; 
         lab=[];
    else
    
    lab= categorical(mov.trap(i).div.deep,[0 1 2],{'unbudded','smallbudded','largebudded'});
    end
    
    for j=1:size(mov.trap(i).gfp,3)
    fprintf('.');   
    
    a=mov.trap(i).gfp(:,:,j,phasechannel);
    b=mov.trap(i).gfp(:,:,j,phasechannel);
    c=mov.trap(i).gfp(:,:,j,phasechannel);
    
    a = double(imadjust(a,[meanphc/65535 maxphc/65535],[0 1]))/65535;
    b = a; %double(imadjust(b,[meanphc/65535 maxphc/65535],[0 1]))/65535;
    c = a; %double(imadjust(c,[meanphc/65535 maxphc/65535],[0 1]))/65535;
    
    im=double(zeros(size(a,1),size(a,2),3));
    
    im(:,:,1)=a;im(:,:,2)=b;im(:,:,3)=c;
    vid(:,:,:,j)=uint8(256*im);
   % figure, imshow(im,[])
    
   % return;
   
   if option==1
    tr=num2str(j);
    while numel(tr)<4
       tr=['0' tr];
    end
    
    if mov.trap(i).div.deep(j)==0 % young budding cells
        if ~isfile([str '/unbudded/im_' mov.trap(i).id '_frame_' tr '.tif'])
        imwrite(im,[str '/unbudded/im_' mov.trap(i).id '_frame_' tr '.tif']);
        end
    end
    if mov.trap(i).div.deep(j)==1 % young budding cells
        if ~isfile([str '/smallbudded/im_' mov.trap(i).id '_frame_' tr '.tif'])
        imwrite(im,[str '/smallbudded/im_' mov.trap(i).id '_frame_' tr '.tif']);
        end
     end
    if mov.trap(i).div.deep(j)==2 % large budding cells
        if ~isfile([str '/largebudded/im_' mov.trap(i).id '_frame_' tr '.tif'])
        imwrite(im,[str '/largebudded/im_' mov.trap(i).id '_frame_' tr '.tif']);
        end
    end
   end
    
    end
    fprintf('\n');  
    deep=mov.trap(i).div.deep;
    save([mov.path '/labeled_video_' mov.trap(i).id '.mat'],'deep','vid','lab');
    
end