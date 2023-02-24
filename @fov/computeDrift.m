function list=computeDrift(obj,varargin)

% compute xy drift for FOV images in framesid

% channel is the channel to perform drift correction
% framesid provides the frames id to perform correction
% display argument displays the resulting corrected image on top of ref
% frame
% im1 and im2 are additional arguments to provide input aimges for
% comparison

method='circshift';  % expect >1 pixel resolution ; no resampling
channel=1;
images={};
framesid=1:numel(obj.srclist{1});
display=0;
refimage=[];
refframeid=1;
crop=0.25;

%method='subpixel';  % expect >1 pixel resolution ; no resampling

%method='register' ; % image registration , precise but unstable !

for i=1:numel(varargin)
    if strcmp(varargin{i},'method')
        method=varargin{i+1};
    end
    
    if strcmp(varargin{i},'channel') % channel number, only used if images are not provided
        channel=varargin{i+1};
    end
    
    if strcmp(varargin{i},'images') % cell array of images or single image
        images=varargin{i+1};
        %size(images)
    end
    
    if strcmp(varargin{i},'framesid') %id of frames
        framesid=varargin{i+1};
    end
    
    if strcmp(varargin{i},'refimage') % reference image , not a cell array
        refimage=varargin{i+1};
    end
    
    if strcmp(varargin{i},'refframeid') % id of reference frame
        refframeid=varargin{i+1};
    end
    
    
    if strcmp(varargin{i},'display') % id of reference frame
        display=1;
    end
    
    if strcmp(varargin{i},'fov') % id of reference frame
        fov=varargin{i+1};
    end
    
    if strcmp(varargin{i},'crop') % cropping factor
        crop=varargin{i+1};
    end
    
end

if numel(obj.drift)==0
    drift=[];
    drift.x=zeros(1,numel(obj.srclist{1}));
    drift.y=zeros(1,numel(obj.srclist{1}));
    obj.drift=drift;
else
    drift=obj.drift;
end

if strcmp(method, 'register')
    [optimizer, metric] = imregconfig('monomodal');
end

cc=1;

if numel(refimage)==0
    refimage=obj.readImage(refframeid,channel);
    
end

ims=size(refimage,1);
if crop<1
    rect=[ims*crop-ims*(crop/2), ims*crop-ims*(crop/2),ims*crop,ims*crop];
    refimage=imcrop(refimage,rect);
elseif crop==1
else
    error('cropping factor must be ]0,1]')
end

list=images; 

for j=framesid
    
    disp(['Computing drift for frame: ' num2str(j) ' of fov' num2str(fov) '.....']);
    
%     if iscell(images)
%         if numel(images)<cc % need to load images
%             %  tic;
%             images{cc}=obj.readImage(j,channel);
%             %   disp('Reading image...');
%             %   toc;
%         end
%     else
%         images={images};
%     end
    
    im=images(:,:,channel,cc);

    ims=size(im,1);
    if crop<1
        rect=[ims*crop-ims*(crop/2), ims*crop-ims*(crop/2),ims*crop,ims*crop];
        im=imcrop(im,rect);
        %figure; imshow(im)
    elseif crop==1
        %nothing
    else
        error('cropping factor must be ]0,1]')
    end
    %  size(im)
    %    size(refimage)
    
    if strcmp(method, 'circshift')
        % tic;
        c = normxcorr2(refimage,im);
        %  toc;
        [mx ix]=max(c(:));
        [row col]=ind2sub(size(c),ix);
        row=row-size(refimage,1);
        col=col-size(refimage,2);
        
        list(:,:,:,cc)=circshift( list(:,:,:,cc),-row,1);
        list(:,:,:,cc)=circshift( list(:,:,:,cc),-col,2);

        if display==1
            imout=circshift( im,-row,1);
            imout=circshift( imout,-col,2);
            %  imout=im;
            figure, imshowpair(refimage,imout);
            title(['Drift : row: ' num2str(row) ' - col: ' num2str(col)]);
        end
    end
    
    if strcmp(method, 'subpixel') % this method does not work so well , requires further troubleshooting
        c = normxcorr2(refimage,im);
        thr=2;
        
        [mx ix]=max(c(:));
        [row col]=ind2sub(size(c),ix);
        %row=row-size(refimage,1);
        %col=col-size(refimage,2);
        sm=c(row-thr:row+thr,col-thr:col+thr);
        
        %  sm=c(size(im,1)-thr:size(im,1)+thr,size(im,2)-thr:size(im,2)+thr);
        
        %     figure, pcolor(sm)
        x =  1:size(sm,1);
        y =  1:size(sm,2);
        
        [X,Y] = meshgrid(x,y);
        
        tmpx=mean(sum(sm.*X,2)./sum(sm,2));
        tmpy=mean(sum(sm.*Y,1)./sum(sm,1));
        
        %  test=moment(sm(11,:),1)
        
        row=tmpx-thr-1+row-size(im,1);
        col=tmpy-thr-1+col-  size(im,2);
        %    row=row-size(refimage,1);
        %    col=col-size(refimage,2);
        
        if display==1
            imout=imtranslate(im,[-col -row]);
            figure, imshowpair(refimage,imout);
            title(['Drift : row: ' num2str(row) ' - col: ' num2str(col)]);
        end
        
    end
    
    
    if strcmp(method, 'register')
        
        %  imref=imtranslate(refimage,[2 0]);
        tform = imregtform(im,refimage,'translation',optimizer,metric);
        
        row=tform.T(3,2);
        col= tform.T(3,1);
        
        if display==1
            imout=imtranslate(im,[col row]);
            figure, imshowpair(refimage,imout);
            title(['Drift : row: ' num2str(row) ' - col: ' num2str(col)]);
        end
    end
    
    %tmp=list{j,k};
    
    
    drift.x(j)=-row;
    drift.y(j)=-col;
    
    
    % figure, imshowpair(refframe, list{j,1});
    %   figure, imshowpair(refframe, tmp);
    
    cc=cc+1;
    
end







obj.drift=drift;


