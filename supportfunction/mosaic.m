function mosaic(obj,varargin)
% generates a rois movie with multiple cavities and rich features

% obj is the reference object: it can be either a @shallow, a @classi, or a
% @ROI.
% other arguments are expained below
tabtitle=0;
stopWhenDead=[]; %dont show seg if cell is dead
shiftY=[];
hideStamp=false;
crop=[];
arraySize=[];
displayLegend=0;
snapRate=[];
scalingFactor=1;
legendX=0;
name=[];
ips=10;
framerate=5;
channel={};
fontsize=12;
levels=[];
training=[];
results=[];
title=[];
strid='';
classif=[];
nocolor=1;
rotate=[];
imageSize=[];
DisplayTest=0;
timeoffset=false;
weights=[];

%colr=[36/255,61/255,255/255];
colr=[0.35,0.35,0.35];


roititle=false;
rls=0;
Flip=0;
rgb={};
contour=0;
sequence='Movie';
background=[0 0 0];
text=[1 1 1];

% if isa(obj,'classi')
%     %frames=1:size(obj.roi(1).image,4); % take the number of frames from the image list
%     frames=[]; %auto determination later, if not indicated
%     strid=obj.strid;
%     rois=[1 2 3];
%     classif=obj;
% end
% if isa(obj,'shallow')
%     %frames=1:numel(obj.fov(1).srclist{1}); % take the number of frames from the image list
%     frames=[]; %auto determination later, if not indicatedchannel
%     rois=[1 1 1; 1 2 3];
% end
if isa(obj,'roi')
    frames=1:size(obj(1).image,4); % take the number of frames from the image list
end


%%

for i=1:numel(varargin)

    if strcmp(varargin{i},'Frames')  frames=varargin{i+1};  end
    if strcmp(varargin{i},'Name')    name=varargin{i+1}; end

    if strcmp(varargin{i},'IPS') % number of frames displayed per second
        ips=varargin{i+1};
    end

    if strcmp(varargin{i},'Framerate') % used to diplay the time on the movie
        framerate=varargin{i+1};
    end

    if strcmp(varargin{i},'SnapRate') % used to diplay the time on the movie
        snapRate=varargin{i+1};
    end

    if strcmp(varargin{i},'stopDead') % stop showing channel once cell is dead. Must give 'Classification'
        stopWhenDead=varargin{i+1};
    end

      if strcmp(varargin{i},'Rotate') % rotate image in degrees
        rotate=varargin{i+1};
    end

       if strcmp(varargin{i},'ImageSize') %specify image size in pixels
        imageSize=varargin{i+1};
       end

    if strcmp(varargin{i},'Flip') % used to diplay the time on the movie
        Flip=1;
    end
    if strcmp(varargin{i},'HideStamp') %
        hideStamp=varargin{i+1};
        if hideStamp
        shiftY=1;
        end
    end

      if strcmp(varargin{i},'TimeOffset') %
        timeoffset=varargin{i+1};
    end

    if strcmp(varargin{i},'NoColor') %
        nocolor=1;
    end

    if strcmp(varargin{i},'Channel') % an array that indicates the channels being displayed, can be scalar array or strid; Multiple channels will be overlaid on the same image
        channel=varargin{i+1};

        if numel(channel)==0
            disp('Channel is not found; quitting!');
            return;
        else
            if numel(stopWhenDead)==0
                stopWhenDead=zeros(1,numel(channel));
            end
        end
    end

    if strcmp(varargin{i},'Levels') % defines output levels for display; must be a 2D vector [low high] for 1D channels (glike a grayscale image) , and a colormap for indexed channels:  jet(16):
        % if several channels are to be overlaid, then a cell array of
        % string must be used : { [low high] , jet(16)}
        %-1 -1 = auto adjust
        levels=varargin{i+1};
    end

    if strcmp(varargin{i},'RGB') % defines the RGB levels for each channel / cell array of 3D vectors
        rgb=varargin{i+1};
    end

    if strcmp(varargin{i},'FontSize')
        fontsize=varargin{i+1};
    end

    % if strcmp(varargin{i},'Mosaic') %
    %     rois=varargin{i+1};
    % end

    if strcmp(varargin{i},'Training') % displays the training data (ground truth)
        training=1; %varargin{i+1};
    end

    if strcmp(varargin{i},'Results') %displays the classi results
        results=1;%varargin{i+1};
    end

    if strcmp(varargin{i},'Classification') % enters the strid of the classif to be included
        classif=varargin{i+1};
    end

    if strcmp(varargin{i},'Title') % display title information on top of the movie
        title=varargin{i+1};
    end

    if strcmp(varargin{i},'ROITitle') % display title for each roi
        roititle=varargin{i+1};
    end

    if strcmp(varargin{i},'RLS') %
        rls=1;
    end

    if strcmp(varargin{i},'contour') %plots contours of indexed objects in case an indexed image is requested
        contour=1;
    end

    if strcmp(varargin{i},'Output') % outputs data as : 'Sequence' : sequence of images ; 'Movie' : mp4 movie; 'Mat': mat file of the output matrix
        sequence=varargin{i+1};
    end

    if strcmp(varargin{i},'Background') % specifies the background color
        background=varargin{i+1};
    end

    if strcmp(varargin{i},'Text') % specifies the text color
        text=varargin{i+1};
        colr=text;
    end

     if strcmp(varargin{i},'Weights') % specifies the weight of the channel in the composition of images. Must have the same number of elements as the channel array. 
        weights=varargin{i+1};
    end


    if strcmp(varargin{i},'Legend') % display legend for classes
        legendX=varargin{i+1};
        displayLegend=1;
    end

    if strcmp(varargin{i},'Scale') % scale images up
        scalingFactor=varargin{i+1};
    end

    if strcmp(varargin{i},'Crop') % scale images up
        crop=varargin{i+1};
    end

    if strcmp(varargin{i},'ArraySize') % a 2 element vector that specifiies the number of row/col for the output matrix
        arraySize=varargin{i+1};
   %     nmov=size(rois,2);

    end

     if strcmp(varargin{i},'DisplayTest') 
        
        DisplayTest=1;  
        frames=obj(1).display.frame;
    
      end

end
    %%
    if numel(levels)==0
        disp('Display levels were not provided ! Will assume that all the channels are grayscale images and will normalize levels');
    end

     if numel(snapRate)==0
                snapRate=ones(1,numel(channel));%freq=1 for all channel
     end


    % rois mode: displays specific ROIs from different FOVs
    % find number of lines and columns

    % if isa(obj,'roi')
    %     rois=[];
    % end

    % if isa(obj,'roi') |  isa(obj,'shallow')
    %     if numel(training) | numel(results)
    %         if numel(classif.strid)==0
    %             disp('You need to provide the strid of the classification training/results to be displayed; Quitting ! ');
    %             return;
    %         end
    %     end
    % end

    %%
%    if numel(rois)
        nmov=size(obj,2);

        if numel(arraySize)
            nsize=arraySize;

               if nmov> arraySize(1) * arraySize(2)
            disp('Error : the number of ROIs exceeds the allocated space !');
            return
               end

        else
            nsize=[1 1; 1 2; 1 3; 2 2; 2 3; 2 3; 3 3; 3 3; 3 3];
            if nmov>9
                nsize=floor(sqrt(nmov-1))+1;
                nsize=[nsize nsize];
            else
                nsize=nsize(nmov,:);
            end
        end
%    else
%        nsize=[1 1];
%        nmov=1;
%    end

    % load template image to check image size
    % if isa(obj,'classi')
    %     img=obj.roi(rois(1)).image;
    %     if numel(img)==0
    %         obj.roi(rois(1)).load;
    %         img=obj.roi(rois(1)).image;
    %     end
    % 
    %     roitmp=obj.roi(rois(1));
    % 
    %     %get max number of frames
    %     if numel(frames)==0
    %         maxframe=NaN;
    %         for r=rois
    %             obj.roi(r).load;
    %             maxframe=min(maxframe, min(size(obj.roi(r).image,4)));
    %         end
    %         frames=1:maxframe;
    %     end
    % end
    % 
    % if isa(obj,'shallow')
    %     img=obj.fov(rois(1,1)).roi(rois(2,1)).image;
    %     if numel(img)==0
    %         obj.fov(rois(1,1)).roi(rois(2,1)).load;
    %         img=obj.fov(rois(1,1)).roi(rois(2,1)).image;
    %     end
    %     roitmp=obj.fov(rois(1,1)).roi(rois(2,1));
    % 
    %     %get max number of frames
    %     if numel(frames)==0
    %         maxframe=NaN;
    %         ccf=1;
    %         for r=rois(2,:)
    %             obj.fov(rois(1,ccf)).roi(r).load;
    %             maxframe=min(maxframe, min(size(obj.fov(rois(1,ccf)).roi(r).image,4)));
    %             ccf=ccf+1;
    %         end
    %         frames=1:maxframe;
    %     end
    % 
    % end

    if isa(obj,'roi')
        img=obj(1).image;
        if numel(img)==0
            obj(1).load;
            img=obj(1).image;
        end
        roitmp=obj(1);
    end

    nframesref=size(roitmp.image,4);%useless?

    % find the right channel
    cha={};

    if numel( rgb)==0
        rgb=cell(numel(channel),1);
    end

    if numel(levels)==0
        levels=cell(numel(channel),1);
    end

    for i=1:numel(channel)
        if iscell(channel)
            cha{i}=roitmp.findChannelID(channel{i});
        else
            pix=find(roitmp.channelid==channel(i));
            cha{i}=pix;
        end

        if numel(rgb{i})==0
            rgb{i}=[1 1 1];
        end

        if numel(levels{i})==0
            levels{i}=[-1 -1];
        end
    end

    % set up extra display pixels
    % columns on the left of the movie
    shiftx=0;
    if numel(training)
        wid=ceil(7*sqrt(scalingFactor))+5; %width of squares
        shiftx=wid;
        shiftx=floor(shiftx*sqrt(scalingFactor));
    end
    if numel(results)
        wid=ceil(7*sqrt(scalingFactor))+5; %width of squares
        shiftx=shiftx+wid;
        shiftx=floor(shiftx*sqrt(scalingFactor));
    end

    if numel(results) | numel(training)
        legendX=ceil(legendX*sqrt(scalingFactor));
        shiftx=shiftx+legendX;
    end


    % add row for roi title
    shifty=0;

    if roititle | rls>0 | shiftY
 
        shifty=16;
        shifty=floor(shifty*sqrt(scalingFactor));
    end

    %=creates the table
    if numel(crop)>0
        for c=1:size(img,3)
            for f=1:size(img,4)
                imgtp(:,:,c,f)=imcrop(img(:,:,c,f),crop);
            end
        end
        img=imgtp;
    end


    %scalingFactor
    img=imresize(img,scalingFactor);

      if numel(imageSize)
                img=imresize(img,imageSize);
      end


    h=size(img,1)+shifty;
    w=size(img,2)+shiftx;
    imgout=uint16(65535*ones(nsize(1)*h,nsize(2)*w,3,numel(frames)));

    imgout(:,:,1,:)=uint16(double(imgout(:,:,1,:))*background(1));
    imgout(:,:,2,:)=uint16(double(imgout(:,:,2,:))*background(2));
    imgout(:,:,3,:)=uint16(double(imgout(:,:,3,:))*background(3));
    %=
 
    cc=1;

    %   if numel(channel)==1
    %                pix=find(roitmp.channelid==channel);
    %                if numel(pix)>1 % multichannel
    %                    channel=pix;
    %                end
    %   end



    for k=1:nsize(1) % include all requested rois
        for j=1:nsize(2)
            % 
            % if isa(obj,'classi')
            %     roitmp=obj.roi(rois(cc));
            % end
            % if isa(obj,'shallow')
            %     roitmp=obj.fov(rois(1,cc)).roi(rois(2,cc));
            % end
            % if isa(obj,'roi')
            %     roitmp=obj;
            % end

            if cc>numel(obj)
                continue
            end

            roitmp=obj(cc);

            if numel(roitmp.image)==0
                roitmp.load;
            end
            disp(['ROI ' roitmp.id ' is loaded']);

            if numel(intersect(1:size(roitmp.image,4) , frames)) < numel(frames)
                disp('this ROI does not have enough frames, you must provide a compatible frames argument');
            end

            imtmp=roitmp.image(:,:,:,frames);

            if numel(crop)>0
                for c=1:size(imtmp,3)
                    for f=1:size(imtmp,4)
                        imtmptp(:,:,c,f)=imcrop(imtmp(:,:,c,f),crop);
                    end
                end
                imtmp=imtmptp;
            end
            imtmp=imresize(imtmp,scalingFactor,'nearest');

              if numel(imageSize)
                imtmp=imresize(imtmp,imageSize);
            end

            frameEnd(1:numel(cha))=9999;
            if numel(find(stopWhenDead==1))>0 %if channel to skip when cell is dead
                if numel(classif)>0
                    rlsresults=roitmp.results.(classif.strid).RLS;
                    frameEnd(find(stopWhenDead==1))=rlsresults.frameEnd;
                else
                    error('You want to hide a channel when cell is dead. You need to indicate a classi with Classification argument');
                end
            end

            %   imblack=uint16(zeros(size(imtmp,1),shiftx,size(imtmp,3),size(imtmp,4)));
            %   imout=cat(2,imblack,imtmp);

            %   imblack2=uint16(zeros(shifty,size(imout,2),size(imout,3),size(imout,4)));
            %   imout=cat(1,imblack2,imout);

            %         imout= uint16(zeros(size(imtmp,1),size(imtmp,2),3,size(imtmp,4)));
            %
            %         imblack=uint16(zeros(size(imtmp,1),shiftx,3,size(imtmp,4)));
            %         imout=cat(2,imblack,imtmp);
            %
            %         imblack2=uint16(zeros(shifty,size(imout,2),3,size(imout,4)));
            %         imout=cat(1,imblack2,imout);

            imout=uint16(zeros(size(imtmp,1),size(imtmp,2),3,size(imtmp,4)));
            %   imout(:,:,1,:)=imout(:,:,1,:)*background(1);
            %   imout(:,:,2,:)=imout(:,:,2,:)*background(2);
            %   imout(:,:,3,:)=imgout(:,:,3,:)*background(3);


            for i=1:size(imtmp,4) % loop on frames
                %IMAGES
                imgRGBsum=uint16(zeros(size(imtmp,1),size(imtmp,2),3));
                for ii=1:numel(cha) %loop on channels

                    if mod(i-1, snapRate(ii))==0 %skip frames
                        if frames(i)<frameEnd(ii)  %stop when dead
                            imtmp2=imtmp(:,:,cha{ii},i);
                        else
                            imtmp2=uint16(zeros(size(imtmp(:,:,cha{ii},i))));
                        end


                    else

                        imtmp2=uint16(zeros(size(imtmp(:,:,cha{ii},i))));
                    end

                             if Flip==1 % flip image upside down
                        imtmp2=flip(imtmp2,1);
                              end


                    if numel(cha{ii})==1 % single dimension channel => levels can be readjusted



                        if numel(levels{ii})==2 % A 2D vector is provided, therefore image is not an indexed one
                            if levels{ii}==[-1 -1] %auto adjust
                                if i==1
                                    tmptimelapse=imtmp(:,:,cha{ii},1:end);
                                    med=median(tmptimelapse(:));
                                    stddev=std(double(tmptimelapse(:)));
                                    stretchlim(:,ii)=[max(0,double(med)-4*stddev) ; min(65535,double(med)+4*stddev)]/65535;
                                end
                                imtmp2 = imadjust(imtmp2,stretchlim(:,ii));
                            else
                                imtmp2 = imadjust(imtmp2,[levels{ii}(1)/65535 levels{ii}(2)/65535]);
                            end
                            imtmp2= cat(3, imtmp2*rgb{ii}(1), imtmp2*rgb{ii}(2), imtmp2*rgb{ii}(3));


                                       if numel(weights)==0
                    imgRGBsum=imlincomb(1,imgRGBsum,1,imtmp2);
                    else
                     imgRGBsum=imlincomb(1,imgRGBsum,weights(ii),imtmp2);
                                       end


                        else % channel represents an indexed image , will use provided colormap
                           indices=str2num(levels{ii}{1});

                          %  maxe= max( imtmp2(:)); %get classes
                            imrgbbw=uint16(zeros(size(imgRGBsum)));

                            contour= levels{ii}{4};
                            wid= levels{ii}{5};
                             levmap=eval(levels{ii}{2});
                             wei= levels{ii}{3};

         

                            for iii=1:numel(indices) %1:maxe %for classes
                                bw=imtmp2==indices(iii);

                                if contour %plots the contour rather than a surface
                                       lineopac=min(1,wei);
                                       opac=0;
                                else
                                       lineopac=1;
                                       opac=min(1,wei);
                                end
                                       wid=max(1,wid);
            
                                       imgRGBsum= insertObjectMask(   imgRGBsum,bw,'MaskColor',uint8(255*levmap(iii,:)),'Opacity',opac,'LineOpacity',lineopac,'LineWidth',wid);
                                end
                                    %bw=bwperim(bw); % ugly but proablably not
                                    %worse than what is done below in the end :

                                %     [B,L] = bwboundaries(bw,'noholes');
                                %     bw(:)=0;
                                %     bw=65535*uint16(bw);
                                %     vecpol=[];
                                % 
                                %     for m =1:length(B)
                                %         boundary = B{m};
                                %         if size(boundary,1)>2 % a polygon must have at least 3 vertices
                                %             vecpoltmp=[boundary(:,2)' ; boundary(:,1)'];
                                %             vecpoltmp=reshape(vecpoltmp,1,[]);
                                %             imgRGBsum= insertShape(  imgRGBsum,'Polygon',vecpoltmp,    'ShapeColor', round(65535*levmap(iii,:)),'LineWidth',wid,'SmoothEdges',true,'Opacity',min(1,wei));
                                %             % if contour, the contour
                                %             % should be blended but
                                %             % strictly delineated
                                %         end
                                %     end
                                % 
                                %     if length(B)==0
                                % %    bw=cat(3,bw,bw,bw);
                                %     end
                                % 
                                %   %  imrgb=bw;
                                % else % plots surface
                                   % bw=65535*uint16(bw);

                            %        imrgbbw = insertObjectMask(imrgbbw,bw,'MaskColor',uint8(255*levmap(iii,:)),'Opacity',1);

                               %       imgRGBsum= insertObjectMask(   imgRGBsum,bw,'MaskColor',uint8(255*levmap(iii,:)),'Opacity',min(1,wei));

                                %    imrgb=cat(3,bw*levmap(iii,1)*rgb{ii}(1),bw*levmap(iii,2)*rgb{ii}(2),bw*levmap(iii,3)*rgb{ii}(3));
                               %     imrgbbw=imadd(imrgbbw,imrgb); % in case of a surface, blend the pixels 
                          %      end

                           
                             %   imrgbbw=imlincomb(1,imrgbbw,1,imrgb);

                          %  imtmp2=imrgbbw;
                        
                        end
                    end

                    if numel(cha{ii})==3 % already a combined image ; no RGB adjustmeent is possible
                            if numel(weights)==0
                    imgRGBsum=imlincomb(1,imgRGBsum,1,imtmp2);
                    else
                     imgRGBsum=imlincomb(1,imgRGBsum,weights(ii),imtmp2);
                            end
                    end


                end

                if numel(rotate)
                    imgRGBsum=imrotate(imgRGBsum,rotate);
                end
             %   size(imgRGBsum)

                imout(:,:,:,i)=imgRGBsum;
            end


            %the REST
            %add background rectangles top and left of each roi
            imblack=uint16(65535*ones(size(imtmp,1),shiftx,3,size(imtmp,4)));
            imblack(:,:,1,:)=imblack(:,:,1,:)*background(1);
            imblack(:,:,2,:)=imblack(:,:,2,:)*background(2);
            imblack(:,:,3,:)=imblack(:,:,3,:)*background(3);

            imout=cat(2,imblack,imout);
            imblack2=uint16(65535*ones(shifty,size(imout,2),3,size(imout,4)));
                for ci=1:3
            imblack2(:,:,1,:)= imblack2(:,:,1,:)*background(ci);
            imblack2(:,:,2,:)= imblack2(:,:,2,:)*background(ci); 
             imblack2(:,:,3,:)= imblack2(:,:,3,:)*background(ci); 
                end
            imout=cat(1,imblack2,imout);
            %=

            % add black frame around ROIs
            framesize=2;
            for ci=1:3
                imout(1:framesize,:,ci,:)=65535*background(ci);
                imout(end-framesize+1:end,:,ci,:)=65535*background(ci);
                imout(:,1:framesize,ci,:)=65535*background(ci);
                imout(:,end-framesize+1:end,ci,:)=65535*background(ci);
            end

            % insert features here
            % =calculate RLS  based on measureRLS2
            if rls==1
                %   [rlsout,rlsresults,rlstraining]=measureRLS3(classif,roitmp);
                rlsresults=roitmp.results.RLS.(['from_' classif.strid]);
                pir=0;
                if training==1
                    rlst=roitmp.train.RLS.(['from_' classif.strid]);
                    pit=0;
                end
            end
            %=

            % insert ROI title
            if roititle | rls>0
                str='';
                if roititle
                    if numel(roitmp.id)>10
                    str=[roitmp.id(end-10:end)];
                    else
                    str=[roitmp.id];
                    end
                end

                %NUMBER OF DIVS
                for i=1:numel(frames)
         
                    if rls==1
                         str='';
                        pir=sum(frames(i)>=rlsresults.framediv);
                        if pir<10
                            str=[str  num2str(pir) '  - '];
                        else
                            str=[str num2str(pir) ' - '];
                        end
                        if numel(training)==0 %if only results
                            str=[];
                            str=[str  num2str(pir) ' divisions'];
                        end

                        if training==1
                            pit=sum(frames(i)>=rlst.framediv);
                            if pit<10
                                strt=[blanks(numel(str)) ' ' num2str(pit) ' div'];
                            else
                                strt=[blanks(numel(str)) num2str(pit) ' div'];
                            end
                        end
                    end

                    %ndiv text
                    if numel(training)==1
                        imout(:,:,:,i)=insertText( imout(:,:,:,i),[legendX-0 shifty/2+2],str,'Font','Consolas Bold','FontSize',floor(12*sqrt(scalingFactor)),'BoxColor',...
                           background,'BoxOpacity',0.0,'TextColor',colr*65535,'AnchorPoint','LeftCenter');
                        imout(:,:,:,i)=insertText( imout(:,:,:,i),[legendX-0 shifty/2+2],strt,'Font','Consolas Bold','FontSize',floor(12*sqrt(scalingFactor)),'BoxColor',...
                            background,'BoxOpacity',0.0,'TextColor',65535*text,'AnchorPoint','LeftCenter');
                    elseif numel(training)==0 %if only results
                      %  str
                     
                        imout(:,:,:,i)=insertText( imout(:,:,:,i),[-2 shifty/2+3],str,'Font','Consolas Bold','FontSize',floor(12*sqrt(scalingFactor)),'BoxColor',...
                          255* background,'BoxOpacity',0.0,'TextColor',65535*text,'AnchorPoint','LeftCenter');
                    end
                end
            end

            startx=0;
            offsettrain=0;

            %=====CLASSES
            if numel(results) || numel(training)
                classname=classif.classes;
            end

            if numel(results) % display results classes
                if isfield(roitmp.results,classif.strid)
                    ncla=numel(roitmp.results.(classif.strid).classes);
                    cmapr=prism(ncla);
                    cmap(1,:)=[0.75,0.75,0.75];
                    if nocolor==1
                        cmapr(:,1)=colr(1); cmapr(:,2)=colr(2); cmapr(:,3)=colr(3);
                    end
                else
                    ncla=0;
                end
                if ncla==0
                    disp('No class available in this ROI; There is no results for this classification... ');
                    idresults=[];
                else
                    inte=uint16(double(size(imout,1)-shifty)/double(ncla));
                    startx=shiftx-ceil(2*sqrt(scalingFactor)) -(numel(results)+numel(training))*wid;

                    if isfield(roitmp.results,classif.strid)
                        idresults=roitmp.results.(classif.strid).id;
                    else
                        idresults=[];
                    end
                end
            end

            if numel(training) % display training classes
                ncla=numel(roitmp.classes);
                cmap=prism(ncla);
                cmap(1,:)=[0.75,0.75,0.75];
                if nocolor==1
                   cmap(:,1)=0.25; cmap(:,2)=0.25; cmap(:,3)=0.25;
                end
                if ncla==0
                    disp('No class available in this ROI; There is likely no training for this classification... ');
                    idtrain=[];
                else
                    inte=uint16(double(size(imout,1)-shifty)/double(ncla));
                    if isfield(roitmp.train,classif.strid)
                        idtrain=roitmp.train.(classif.strid).id;
                        offsettrain=wid+4;
                        startx2=startx+offsettrain;
                    else
                        idtrain=[];
                    end
                end
            end

            for ii=1:numel(frames)
                %===CLASS SQUARES===
                if numel(results) && numel(idresults)
                    for jj=1:ncla
                        col=round(65535*cmapr(jj,:));
                        if idresults(frames(ii))==jj
                            imout(:,:,:,ii) = insertShape( imout(:,:,:,ii),'FilledRectangle',[startx inte*jj-inte/2+shifty-wid/2 wid wid],'Color',col,'Opacity',1 );
                        end
                        imout(:,:,:,ii) = insertShape( imout(:,:,:,ii),'Rectangle',[startx inte*jj-inte/2+shifty-wid/2 wid wid],...
                            'Color', 65535*text,'Opacity',1,'LineWidth',2);
                        if displayLegend==1
                            imout(:,:,:,ii) = insertText(imout(:,:,:,ii),[shiftx-(numel(results)+numel(training))*wid-5, inte*jj-inte/2+shifty],classname{jj},'Font','Consolas Bold','FontSize',20, 'TextColor',col,'BoxColor',[1 1 1],'BoxOpacity',0.0,'AnchorPoint','RightCenter');
                        end
                    end
                end

                if numel(training) && numel(idtrain)
                    for jj=1:ncla
                        col=round(65535*cmap(jj,:));
                        if idtrain(frames(ii))==jj
                            imout(:,:,:,ii) = insertShape( imout(:,:,:,ii),'FilledRectangle',[startx2 inte*jj-inte/2+shifty-wid/2 wid wid],'Color',col,'Opacity',1 );
                        end
                        imout(:,:,:,ii) = insertShape( imout(:,:,:,ii),'Rectangle',[startx2 inte*jj-inte/2+shifty-wid/2 wid wid],...
                            'Color', 65535*text,'Opacity',1,'LineWidth',2);
                        if displayLegend==1
                            imout(:,:,:,ii) = insertText(imout(:,:,:,ii),[shiftx-(numel(results)+numel(training))*wid-5, inte*jj-inte/2+shifty],classname{jj},'Font','Consolas Bold','FontSize',20, 'TextColor',col,'BoxColor',[1 1 1],'BoxOpacity',0.0,'AnchorPoint','RightCenter');
                        end
                    end
                end


            end

            imgout(1+(k-1)*h:k*h,1+(j-1)*w:j*w,:,:)=imout; % assemble rois
            cc=cc+1;
        end
    end

    %figure, imshow(imgout(:,:,:,1))
    %imgout=imgout(:,:,:,frames);
    imgout=uint8(double( imgout)/256);


    %============TITLE rows on the top of the movie : framerate or title
    if framerate>0 || numel(title)
        shifttitley=floor(sqrt(scalingFactor)*fontsize)+10;
        topimage=uint8(255*ones(shifttitley,size(imgout,2),size(imgout,3),size(imgout,4)));
        for ci=1:3
            topimage(:,:,ci,:)=topimage(:,:,ci,:)*background(ci);
        end

        imgout2=cat(1,topimage,imgout);

        for j=1:numel(frames)
            if timeoffset
            timestamp=[num2str((frames(j)-frames(1))*framerate) 'min'];
            else
              timestamp=[num2str((frames(j))*framerate) 'min'];
            end

            if hideStamp==1
                timestamp='';
            end
            if numel(title)>0
          %      timestamp=[blanks(numel(title)+tabtitle) '- GT : ' timestamp];
                   timestamp=[blanks(numel(title)+tabtitle) ' - ' timestamp];
            end

            %the image passed in 8 bits depth--> use 255
            if ispc
            imgout2(:,:,:,j)=insertText(imgout2(:,:,:,j),[1,shifttitley/2],[blanks(tabtitle) title],'Font','Consolas Bold','FontSize',floor(sqrt(scalingFactor)*fontsize),...
                'BoxColor',[1 1 1],'BoxOpacity',0.0,'TextColor',colr*255,'AnchorPoint','LeftCenter');

            imgout2(:,:,:,j)=insertText(imgout2(:,:,:,j),[1,shifttitley/2],timestamp,'Font','Consolas Bold','FontSize',floor(sqrt(scalingFactor)*fontsize),...
                'BoxColor',[1 1 1],'BoxOpacity',0.0,'TextColor',255*text,'AnchorPoint','LeftCenter');
            else
            
              imgout2(:,:,:,j)=insertText(imgout2(:,:,:,j),[1,shifttitley/2],[blanks(tabtitle) title],'Font','Ubuntu-C','FontSize',floor(sqrt(scalingFactor)*fontsize),...
                'BoxColor',[1 1 1],'BoxOpacity',0.0,'TextColor',colr*255,'AnchorPoint','LeftCenter');

            imgout2(:,:,:,j)=insertText(imgout2(:,:,:,j),[1,shifttitley/2],timestamp,'Font','Ubuntu-C','FontSize',floor(sqrt(scalingFactor)*fontsize),...
                'BoxColor',[1 1 1],'BoxOpacity',0.0,'TextColor',255*text,'AnchorPoint','LeftCenter');
             
             
            end
        end

        imgout=imgout2;
    end

    %%
    % export parameters

    if numel(name)==0
        %   name=[obj.path  '/ClassifMosaic'];

        %  for i=1:nmov
        %       name=[name '_' num2str(rois(i)) '_' num2str(rois(i)) '-'];
        %    end

        % if isa(obj,'classi')
        %     name=fullfile(obj.path, 'rois');
        % end
        % 
        % if isa(obj,'shallow')
        %     name=fullfile(obj.io.path,obj.io.file,'rois');
        % end

        if isa(obj,'roi')
            name=fullfile(obj.path,obj.id);
        end

    else
%         if isa(obj,'classi')
%             name=fullfile(obj.path,name);
%         end
%
%         if isa(obj,'shallow')
%             name=fullfile(obj.io.path,obj.io.file,name);
%         end
%
%         if isa(obj,'roi')
%             name=fullfile(obj.path,name);
%         end
    end

    % routine output : movie or sequence of image

if DisplayTest==1
    disp('test movie output');

    h=findobj('Tag','MovieTest');
    if numel(h)==0
        h=figure('Tag','MovieTest','Name','Preview figure for movie export');
    end
    p=h.Position;
    figure(h);
        imshow(imgout,[]);
        set(h,'Position',p);
    return;
end


    switch sequence
        case 'Movie' % movie / default

         if ispc
        v=VideoWriter(name,'MPEG-4');
         else
        v=VideoWriter(name,'Motion JPEG AVI');
         end

        v.FrameRate=ips;
        v.Quality=100;
        open(v);

        %return

        writeVideo(v,imgout);
        close(v);
        disp(['Movie successfully exported to : ' name])

        case 'Sequence'

            if numel(arraySize)
                lin=arraySize(1);
            else
                lin=1;
            end

             h= figure, montage(imgout,'Size',[1 NaN]);
             [pth fle]=fileparts(name);
   
              fil=fullfile(pth, [fle '.png'])
              exportgraphics(h, fil);
              disp(['Montage figure successfully exported to : ' fil])

        case 'Mat'
              [pth fle]=fileparts(name);
   
              fil=fullfile(pth, [fle '.mat']);
       
            save(fil, 'imgout');
             disp(['Mat file with matrix successfully exported to : ' fil])
    end
