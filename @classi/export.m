function export(obj,varargin)

mosaic(obj,varargin{:})

% % export specific  movies
% % mosaic montage of specific ROIs in classif
% 
% if numel(obj.roi)==0
%     disp('this classification has no ROIs !');
%     return;
% end
% 
% obj.roi(1).load;
% if numel( obj.roi(1).image)==0
%     disp('could load ROI image !');
%     return;
% end
% 
% frames=1:size(obj.roi(1).image,4); % take the number of frames from the image list
% name=[];
% ips=10;
% framerate=10;
% channels=1;
% fontsize=20;
% levels=[4000 15000; 500 1000; 500 1000; 500 1000];
% training=[];
% results=[];
% cmap=jet(numel(obj.classes));
% 
% mosaic=[1 2 3];
% 
% for i=1:numel(varargin)
%     
%     if strcmp(varargin{i},'Frames')
%         frames=varargin{i+1};
%     end
%     
%     if strcmp(varargin{i},'Name')
%         name=varargin{i+1};
%     end
%     
%     if strcmp(varargin{i},'IPS') % number of frames displayed per second
%         ips=varargin{i+1};
%     end
%     
%     if strcmp(varargin{i},'Framerate')
%         framerate=varargin{i+1};
%     end
%     
%     if strcmp(varargin{i},'Channel') % an array that indicates the channels being displayed
%         channels=varargin{i+1};
%     end
%     
%     if strcmp(varargin{i},'Levels') % defines output levels for display
%         levels=varargin{i+1};
%     end
%     
%     if strcmp(varargin{i},'FontSize')
%         fontsize=varargin{i+1};
%     end
%     
%     if strcmp(varargin{i},'Mosaic') % draws the contour of ROIs on the movie
%         mosaic=varargin{i+1};
%     end
%     
%     if strcmp(varargin{i},'Training') % enters the strid of the classif to be included
%         training=1; %varargin{i+1};
%     end
%     
%     if strcmp(varargin{i},'Results') % enters the strid of the classif to be included
%         results=1;%varargin{i+1};
%     end
%     
%         if strcmp(varargin{i},'Results') % enters the strid of the classif to be included
%         results=1;%varargin{i+1};
%         end
%     
% end
% 
% % if exportfovs==1 % export a list of fovs with paramters
% %     if numel(name)==0
% %         name=[obj.io.path obj.io.file '/FOV_' obj.fov(i).id];
% %     end
% %
% %     for i=listfovs
% %         disp(['Exporting movie for FOV ' num2str(i) ' - '  obj.fov(i).id])
% %         obj.fov(i).export('IPS',ips,'Frames',frames,'Framerate',framerate,'FontSize',fontsize,'Levels',levels,'Channel',channels,'DrawROIs',[],'Name',name)
% %     end
% %     return;
% % end
% 
% 
% % mosaic mode: displays specific ROIs from different FOVs
% % find number of lines and columns
% 
% nmov=size(mosaic,2);
% 
% nsize=[1 1; 1 2; 1 3; 2 2; 2 3; 2 3; 3 3; 3 3; 3 3];
% if nmov>9
%     nsize=floor(sqrt(nmov-1))+1;
%     nsize=[nsize nsize];
% else
%     nsize=nsize(nmov,:);
% end
% 
% img=obj.roi(mosaic(1)).image;
% 
% if numel(img)==0
%     obj.roi(mosaic(1)).load;
% end
% 
% shi=0;
% if numel(training)
%     shi=10;
% end
% if numel(results)
%     shi=shi+10;
% end
%     
% h=size(img,1);
% w=size(img,2)+shi;
% imgout=zeros(nsize(1)*h,nsize(2)*w,3,size(img,4));
% cc=1;
% 
% for k=1:nsize(1) % include all requested rois
%     for j=1:nsize(2)
%         
%         obj.roi(mosaic(cc)).load;
%         disp(['ROI ' obj.roi(mosaic(cc)).id ' loaded']);
%         
%         imtmp= obj.roi(mosaic(cc)).image;
%         imblack=uint16(zeros(size(imtmp,1),shi,size(imtmp,3),size(imtmp,4)));
%         
%         imout=cat(2,imblack,imtmp);
%         for i=1:size(imtmp,4)
%             imout(:,:,1,i)=imadjust(imout(:,:,1,i),[levels(1,1)/65535 levels(1,2)/65535],[0 1]);
%         end
%         
%         % add black columns on the left
%         
%         % add black frame around ROIs
%         imout(1:2,:,1,:)=0;
%         imout(end-1:end,:,1,:)=0;
%         imout(:,1:2,1,:)=0;
%         imout(:,end-1:end,1,:)=0;
%         
%         imout(:,:,2,:)=imout(:,:,1,:);
%         imout(:,:,3,:)=imout(:,:,1,:);
%         
%         % insert features here
%         
%         startx=0;
%         if numel(training)
%             ncla=numel(obj.roi(mosaic(cc)).classes);
%             inte=uint16(double(size(imout,1))/double(ncla+1));
%             wid=5;
%             startx=5;
%             idtrain= obj.roi(mosaic(cc)).train.(obj.strid).id;
%         end
%           if numel(results)
%             ncla=numel(obj.roi(mosaic(cc)).classes);
%             inte=uint16(double(size(imout,1))/double(ncla+1));
%             wid=5;
%             startx2=startx+wid+2;
%             idresults= obj.roi(mosaic(cc)).results.(obj.strid).id;
%         end
%         
%         for ii=1:size(imout,4)
%             if numel(training)
%                 for jj=1:ncla
%                     imout(:,:,:,ii) = insertShape( imout(:,:,:,ii),'Rectangle',[startx inte*jj-inte/2 wid wid],...
%                         'Color', {'white'});
%                     if idtrain(ii)==jj
%                         col=round(65535*cmap(jj,:));
%                         imout(:,:,:,ii) = insertShape( imout(:,:,:,ii),'FilledRectangle',[startx+1 inte*jj-inte/2+1 wid-2 wid-2],'Color',col );
%                     end
%                 end
%             end
%              if numel(results)
%                 for jj=1:ncla
%                     imout(:,:,:,ii) = insertShape( imout(:,:,:,ii),'Rectangle',[startx2 inte*jj-inte/2 wid wid],...
%                         'Color', {'white'});
%                     if idresults(ii)==jj
%                         col=round(65535*cmap(jj,:));
%                         imout(:,:,:,ii) = insertShape( imout(:,:,:,ii),'FilledRectangle',[startx2+1 inte*jj-inte/2+1 wid-2 wid-2],'Color',col );
%                     end
%                 end
%             end
%             
%         end
%         
%         
%         imgout(1+(k-1)*h:k*h,1+(j-1)*w:j*w,:,:)=imout;
%         
%         cc=cc+1;
%     end
% end
% 
% imgout=imgout(:,:,:,frames);
% imgout=uint8(double( imgout)/256);
% 
% for j=1:numel(frames)
%     if framerate >0
%         timestamp=[num2str((j-1)*framerate) 'min'];
%         
%         imgout(:,:,:,j)=insertText( imgout(:,:,:,j),[1 10],timestamp,'Font','Arial','FontSize',fontsize,'BoxColor',...
%             [1 1 1],'BoxOpacity',0.0,'TextColor','red','AnchorPoint','leftcenter');
%         %fprintf('.')
%     end
%     
%     % here add training / results
% end
% 
% if numel(name)==0
%     name=[obj.path  '/ClassifMosaic'];
%     
%     for i=1:nmov
%         name=[name '_' num2str(mosaic(i)) '_' num2str(mosaic(i)) '-'];
%     end
% else
%     name=[obj.path '/' name];
% end
% 
% v=VideoWriter(name,'MPEG-4');
% v.FrameRate=ips;
% open(v);
% 
% %return
% writeVideo(v,imgout);
% close(v);
% disp('Movie is done !')
% 
% 


