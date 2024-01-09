function saveCroppedImages(obj,varargin)

% writes ROIs and applies XY drift correction
% cut all frames into small pieces to prevent out of memory :

% loop on groups of frames --> loading raw images for designated frames
% into memory
% loop on fov
% parfor on rois

disp('Processing raw images. Wait....');

tic;

frames=[];
fovid=1:numel(obj.fov); % All FOVs will be processed
cut=20;
correctdrift=true;
crashrecovery=0;
cropDrift=1;
channels=[];

for i=1:numel(varargin)
    if strcmp(varargin{i},'frames') % frames to be processed
        frames=varargin{i+1};
    end

    if strcmp(varargin{i},'fov') % list of fov to be prepared
        fovid=varargin{i+1};
    end

    if strcmp(varargin{i},'cut') % number of frames loaded at once to prepare ROI matrices
        cut=varargin{i+1};
    end

    if strcmp(varargin{i},'correctdrift') % number of frames loaded at once to prepare ROI matrices
        correctdrift=logical(varargin{i+1});
    end

    if strcmp(varargin{i},'cropdrift') % cropping factor for computedrift
        cropDrift=varargin{i+1};
    end

    if strcmp(varargin{i},'crashrecovery')
        crashrecovery=varargin{i+1};
    end

    if strcmp(varargin{i},'channel')
        channels=varargin{i+1};
    end


    %       if strcmp(varargin{i},'channelint') % frames interval
    %     channelint=varargin{i+1};
    %   end
end
% first creat independent fov indentical to obj.fov



tmpfov=fov;

if crashrecovery==1
    if exist(fullfile(userpath, 'tmpcrash.mat'))
        disp(['A crash log file exist at location : ' userpath]);
        load(fullfile(userpath, 'tmpcrash.mat'));
        fovid= tmpcrash.fovid;

        framecell= tmpcrash.framecell;

        i=tmpcrash.currentfovid;

        pix=find(fovid==i);
        fovid=fovid(pix:end);

        currentframe=tmpcrash.currentframe;
    else
        disp('I could not find any crash recovery file !');
        return;
    end
else
    currentframe=[];
end

strpath=[obj.io.path obj.io.file];

for i=fovid

    tmpfov(i)=obj.fov(i);
    %tmpfov(i)=propValues(tmpfov(i),obj.fov(i));

    for j=1:numel(obj.fov(i).roi)
        obj.fov(i).roi(j).path=fullfile(strpath,obj.fov(i).id);
    end
end

shallowSave(obj);

for i=fovid

    if numel(tmpfov(i).roi)==0
        disp('this FOV has no ROI ! Quitting ....');
        %break
        %return
        continue
    end

    if numel(tmpfov(i).roi(1).id)==0
        disp('this FOV has no ROI ! Quitting ....');
        %break
        continue
        %return;
    end


    if numel(channels)==0
        cha=1:numel(tmpfov(i).channel) ;
    else
        cha=channels;
    end

    

    if numel(frames)==0
        nframes=1:numel(tmpfov(i).srclist{1}); % take the number of frames from the image list
    else
        nframes=frames;   % specify a number of images to be applied to all FOVs
    end

    % find the number of arrays
    framecell={}; % a cell array that specfifes how to porcess the frames

    narr= floor(numel(nframes)/cut);
    id=1:narr*cut;
    id=reshape(id,cut,[]);


    for iii=1:narr
        framecell{iii}= nframes(id(:,iii));
    end

    nrest=mod(numel(nframes),cut);
    if nrest>0
        framecell{end+1}=nframes(narr*cut+1:end);
    end

    nframestot=nframes;


    % % create fov specific directory

    if ~exist(fullfile(strpath,tmpfov(i).id),'dir')
        try
            mkdir(strpath,tmpfov(i).id);
        catch
            disp(['Could not create folder : ' tmpfov(i).id  ' in ' strpath '; Quitting !'])
            disp(' This is an I/O CRASH: start ROI extraction again with crashrecovery mode set to 1');
            return;
        end
    end

    disp('loading reference image to perform XY alignment');

    refframe=framecell{1}(1);
    refframeid=refframe;

    % reading data
    try
        refimage=tmpfov(i).readImage(refframe,1);
        if numel(refimage)==0
            disp(['Unable to read frame ' num2str(refframe) ' in channel ' num2str(1)]);
            disp(' This is an I/O CRASH: start ROI extraction again with crashrecovery mode set to 1');
            dumprecovery(fovid,framecell,i,1);
            return;
        end
    catch
        disp(['Unable to read frame ' num2str(refframe) ' in channel ' num2str(1)]);
        disp(' This is an I/O CRASH: start ROI extraction again with crashrecovery mode set to 1');
        dumprecovery(fovid,framecell,i,1);
        return;
    end

    disp('Loading raw images in memory ....');

    frstart=1;
    if numel(currentframe)>0 % crash recovery on going, restart from previous error
        frstart=currentframe;
        currentframe=[];
    end

    ccha=0;
    arrcha=[];

    cccha=1;
     for k=cha % loop on channels to determine the type of image
              im=tmpfov(i).readImage(1,k);
              ccha=ccha+size(im,3);
              arrcha(cccha)=size(im,3);
              cccha=cccha+1;
     end

    for ii=frstart:numel(framecell) % loop on all blocks of frames on a given FOV
        nframes= framecell{ii};


        % list=cell(numel(nframes),numel(cha));
        im=tmpfov(i).readImage(1,1);
    %    list=uint16(zeros(size(im,1),size(im,2),numel(cha),numel(nframes)));
           list=uint16(zeros(size(im,1),size(im,2),ccha,numel(nframes)));

        % refframe=framecell{1}(1);

        disp(['Reading group of frames:  ' num2str(ii) ' / ' num2str(numel(framecell)) ]);

        for j=1:numel(nframes) % read all images for all channels in this group

            disp(['Reading frame: ' num2str(j) ' / '  num2str(numel(nframes)) ' in group of frame : ' num2str(ii) ' / ' num2str(numel(framecell)) ' for FOV:  ' num2str(tmpfov(i).id)]);

            % ck=1;
             cccha=1;

            for k=cha % loop on channels
                frame=(nframes(j)); %/channelint(k))+1; %  spacing frames when channels are not used with equal time interval


                %     im=tmpfov(i).readImage(frame,k);

                try
                    im=tmpfov(i).readImage(frame,k);
                    if numel(im)==0
                        disp(['Unable to read frame ' num2str(frame) ' in channel ' num2str(k)]);
                        disp(' This is an I/O CRASH: start ROI extraction again with crashrecovery mode set to 1');
                        dumprecovery(fovid,framecell,i,ii);
                        return;
                    end
                catch
                    disp(['Unable to read frame ' num2str(frame) ' in channel ' num2str(k)]);
                    disp(' This is an I/O CRASH: start ROI extraction again with crashrecovery mode set to 1');
                    dumprecovery(fovid,framecell,i,ii);
                    return;
                end


                numbcha=size(im,3);

                if tmpfov(i).display.binning(k) ~= tmpfov(i).display.binning(1)
                    im=imresize(im,tmpfov(i).display.binning(k)/tmpfov(i).display.binning(1));
                end

                list(:,:,cccha:cccha+numbcha-1,j)=im;
                 cccha=cccha+numbcha;
                % ck=ck+1;
            end

            % msg = sprintf('Reading frame: %d / %d for FOV %s', j, numel(nframes),tmpfov(i).id); %Don't forget this semicolon
            %  fprintf([reverseStr, msg]);
            %  reverseStr = repmat(sprintf('\b'), 1, length(msg));

            % cc=cc+1;
        end

        fprintf('\n');

        if correctdrift

            disp('Correcting XY drift in images...');

            method='circshift';
            % method='subpixel';

            list=tmpfov(i).computeDrift('framesid',nframes,'refframeid',refframeid,'method',method,'refimage',refimage,'images',list,'fov',i,'crop',cropDrift); % compute drift and store in fov.drift

            %a= tmpfov(i).drift.x

            %             for j=1:numel(nframes)
            %                 row=tmpfov(i).drift.x(nframes(j));
            %                 col=tmpfov(i).drift.y(nframes(j));
            %
            %                 for k=cha
            %
            %                     if strcmp(method,'circshift')
            %                         list{j,k}=circshift( list{j,k},row,1);
            %                         list{j,k}=circshift( list{j,k},col,2);
            %                     end
            %                     if strcmp(method,'subpixel')
            %                         list{j,k}=imtranslate(list{j,k},[-col -row]);
            %                         %  list{j,k}=imtranslate(list{j,k},[row col]);
            %                     end
            %                 end
            %             end

        end

        disp('Cropping ROIs....');

        reverseStr = '';

        tmproi=roi;
        for l=1:numel(tmpfov(i).roi)
            tmproi(l)=tmpfov(i).roi(l);
            %tmpfov(i)=propValues(tmpfov(i),obj.fov(i));
        end

        % parfor here
        %         if numel(ver('parallel'))
        %
        %             parfor l=1:numel(tmpfov(i).roi) % loop on all rois
        %
        %                 tmproi(l).path=fullfile(strpath,tmpfov(i).id);
        %                 rroi=tmproi(l).value; % cropping data
        %
        %                 init=0;
        %
        %                 if ii~=1 % if not the first group of frame, re-load the 4D im to append data
        %                     % if numel(tmproi(l).image)==[]
        %
        %                     try
        %                         tmproi(l).load;
        %                         if numel(tmproi(l).image)==0
        %                             disp(['Unable to load ROI ' num2str(l)]);
        %                             disp('Try to recover the extraction by reloading with crash recovery set');
        %                             dumprecovery(fovid,framecell,i,ii);
        %                             %return;
        %                         end
        %                     catch
        %                         disp(['Unable to load ROI ' num2str(l)]);
        %                         disp('Try to recover the extraction by reloading with crash recovery set');
        %                         dumprecovery(fovid,framecell,i,ii);
        %                         %return;
        %                     end
        %
        %
        %
        %                     %  end
        %                 else   % first group of frames, need to create structure
        %                     init=1;
        %                 end
        %
        %                 %             % create new image if first item in group of frames
        %                 %             if numel(tmproi(l).image)==[]
        %                 %             %    init=1;
        %                 %             end
        %
        %                 if init==1
        %                     tmproi(l).image=uint16(zeros(rroi(4),rroi(3),numel(tmpfov(i).channel),numel(nframestot)));
        %                     tmproi(l).display.channel={};
        %                     tmproi(l).display.frame=1;
        %                     %tmpfov(i).roi(l).display.settings={};
        %                     temp=[1 1 1];
        %                     %temp=temp';
        %
        %                     ck=1;
        %
        %                     for k=cha
        %                         tmproi(l).display.channel{ck}=tmpfov(i).channel{k}; %['Channel ' num2str(k)];
        %                         tmproi(l).display.intensity(ck,:)=temp;
        %                         tmproi(l).channelid(ck)=ck;
        %                         tmproi(l).display.selectedchannel(ck)=1;
        %                         tmproi(l).display.rgb(ck,:)=temp;
        %                         ck=ck+1;
        %                     end
        %
        %
        %                     tmproi(l).channelid=tmproi(l).channelid(1:numel(cha));
        %                     tmproi(l).display.selectedchannel= tmproi(l).display.selectedchannel(1:numel(cha));
        %                     tmproi(l).display.intensity= tmproi(l).display.intensity(1:numel(cha),:);
        %                     tmproi(l).display.rgb= tmproi(l).display.rgb(1:numel(cha),:);
        %                     tmproi(l).results=[];
        %                     tmproi(l).train=[];
        %                     %       return;
        %                     % add additional channels for cell contours if any
        %                     % (phylocell projects)
        %
        %
        % %                     if numel(tmpfov(i).contours)
        % %
        % %                         if isfield(tmpfov(i).contours,'cells1')
        % %
        % %                             if numel(tmpfov(i).contours.cells1)>1
        % %
        % %                                 ccc=numel(cha)+1;
        % %
        % %                                 tmproi(l).display.channel{ccc}='cells1'; %['Channel ' num2str(k)];
        % %                                 tmproi(l).display.intensity(ccc,:)=temp;
        % %                                 tmproi(l).channelid(ccc)=ccc;
        % %                                 tmproi(l).display.selectedchannel(ccc)=1;
        % %                                 tmproi(l).display.rgb(ccc,:)=temp;
        % %
        % %                             end
        % %                         end
        % %
        % %
        % %                         if isfield(tmpfov(i).contours,'nucleus')
        % %
        % %                             if numel(tmpfov(i).contours.nucleus)>1
        % %                                 ccc=ccc+1;
        % %
        % %                                 tmproi(l).display.channel{ccc}='nucleus'; %['Channel ' num2str(k)];
        % %                                 tmproi(l).display.intensity(ccc,:)=temp;
        % %                                 tmproi(l).channelid(ccc)=ccc;
        % %                                 tmproi(l).display.selectedchannel(ccc)=1;
        % %                                 tmproi(l).display.rgb(ccc,:)=temp;
        % %
        % %                             end
        % %                         end
        % %
        % %                     end
        %
        %                     % write here
        %                     tmproi(l).save;
        %                     %       tmproi(l).clear;
        %                 end
        %
        %                 %cc=1;
        %
        %
        %                 % make a test on ROI value
        %                 rroitmp=[];
        %                 rroitmp(1)=max(rroi(1),1);
        %                 rroitmp(2)=max(rroi(2),1);
        %                 rroitmp(3)=min(rroi(1)+rroi(3)-1,size(list,2));
        %                 rroitmp(4)=min(rroi(2)+rroi(4)-1,size(list,1));
        %
        %
        %                 tmproi(l).image(:,:,:,nframes)=list(rroitmp(2):rroitmp(4),rroitmp(1):rroitmp(3),:,:);
        %
        %                 %             for j=1:numel(nframes)
        %                 %
        %                 %                 ck=1;
        %                 %                 for k=cha
        %                 %
        %                 %                     tmp=list(:,:,k,j);
        %                 %
        %                 %                     tmproi(l).image(:,:,ck,nframes(j))=tmp(rroitmp(2):rroitmp(4),rroitmp(1):rroitmp(3));
        %                 %                     %   tt= tmproi(l).image(:,:,k,nframes(j));
        %                 %                     ck=ck+1;
        %                 %                 end
        %
        %
        %                 %                 for k=numel(cha)+1: numel(tmproi(l).display.channel)
        %                 %
        %                 %                     if  tmproi(l).display.channel{k}=="cells1"
        %                 %
        %                 %                         tmproi(l).image(:,:,k,nframes(j))= uint16(zeros(size(tmp,1),size(tmp,2)));
        %                 %                         labtmp= tmproi(l).image(:,:,k,nframes(j));
        %                 %
        %                 %                         if  nframes(j)<=size(tmpfov(i).contours.cells1,1)
        %                 %                             cells1= tmpfov(i).contours.cells1(nframes(j),:);
        %                 %
        %                 %                             for cd=1:size(cells1,2)
        %                 %                                 x=cells1(cd).x-(rroitmp(2)-1);
        %                 %                                 y=cells1(cd).y-(rroitmp(1)-1);
        %                 %
        %                 %                                 mask = poly2mask(x,y,size(tmp,1),size(tmp,2)); %%HEREE
        %                 %                                 labtmp(mask)=cells1(cd).n;
        %                 %                             end
        %                 %
        %                 %                             tmproi(l).image(:,:,k,nframes(j)) = labtmp;
        %                 %                         end
        %                 %                     end
        %                 %
        %                 %                     if  tmproi(l).display.channel{k}=="nucleus"
        %                 %
        %                 %                         tmproi(l).image(:,:,k,nframes(j))= uint16(zeros(size(tmp,1),size(tmp,2)));
        %                 %                         labtmp= tmproi(l).image(:,:,k,nframes(j));
        %                 %
        %                 %                         if  nframes(j)<=size(tmpfov(i).contours.nucleus,1)
        %                 %                             nucleus= tmpfov(i).contours.nucleus(nframes(j),:);
        %                 %
        %                 %                             for cd=1:size(nucleus,2)
        %                 %                                 x=nucleus(cd).x-(rroitmp(2)-1);
        %                 %                                 y=nucleus(cd).y-(rroitmp(1)-1);
        %                 %
        %                 %                                 mask = poly2mask(x,y,size(tmp,1),size(tmp,2)); %%HEREE
        %                 %                                 labtmp(mask)=nucleus(cd).n;
        %                 %                             end
        %                 %
        %                 %                             tmproi(l).image(:,:,k,nframes(j)) = labtmp;
        %                 %                         end
        %                 %                     end
        %                 %                 end
        %
        %                 %cc=cc+1;
        %                 %       end
        %
        %                 try
        %                     tmproi(l).save;
        %                     tmproi(l).clear;
        %                     disp(['Saved images for ROI ' tmproi(l).id ' in FOV : ' tmpfov(i).id]); %d / %d ROIs saved for FOV %s', l , numel(tmpfov(i).roi), tmpfov(i).id); %Don't forget this semicolon
        %
        %                     %                     if numel(tmproi(l).im)==0
        %                     %                         disp(['Unable to load ROI ' num2str(l)]);
        %                     %                         dumprecovery(fovid,framecell,i,ii);
        %                     %                         return;
        %                     %                     end
        %                 catch
        %                     disp(['Unable to save ROI ' num2str(l)]);
        %                     disp(' This is an I/O CRASH: start ROI extraction again with crashrecovery mode set to 1');
        %                     dumprecovery(fovid,framecell,i,ii);
        %                     %return;
        %                 end
        %
        %
        %                 %tmpfov(i).roi(l).clear;
        %
        %                 % msg = sprintf('Images in %d / %d ROIs saved for FOV %s', l , numel(tmpfov(i).roi), tmpfov(i).id); %Don't forget this semicolon
        %                 % fprintf([reverseStr, msg]);
        %                 %  reverseStr = repmat(sprintf('\b'), 1, length(msg));
        %             end
        %
        %         else % not parallel mode

        for l=1:numel(tmpfov(i).roi) % loop on all rois

            tmproi(l).path=fullfile(strpath,tmpfov(i).id);
            rroi=tmproi(l).value; % cropping data

            init=0;

            if ii~=1 % if not the first group of frame, re-load the 4D im to append data
                % if numel(tmproi(l).image)==[]

                try
                    tmproi(l).load;
                    if numel(tmproi(l).image)==0
                        disp(['Unable to load ROI ' num2str(l)]);
                        disp('Try to recover the extraction by reloading with crash recovery set');
                        dumprecovery(fovid,framecell,i,ii);
                        %return;
                    end
                catch
                    disp(['Unable to load ROI ' num2str(l)]);
                    disp('Try to recover the extraction by reloading with crash recovery set');
                    dumprecovery(fovid,framecell,i,ii);
                    %return;
                end



                %  end
            else   % first group of frames, need to create structure
                init=1;
            end

            %             % create new image if first item in group of frames
            %             if numel(tmproi(l).image)==[]
            %             %    init=1;
            %             end

            if init==1
             %   tmproi(l).image=uint16(zeros(rroi(4),rroi(3),numel(tmpfov(i).channel),numel(nframestot)));
                 tmproi(l).image=uint16(zeros(rroi(4),rroi(3),ccha,numel(nframestot)));
             %   ccha
                tmproi(l).display.channel={};
                tmproi(l).display.frame=1;
               tmproi(l).channelid=[];
                tmproi(l).display.displaylim=[];
                %tmpfov(i).roi(l).display.settings={};
                temp=[1 1 1];
                %temp=temp';

                ck=1;
                cumck=1;

                for k=cha
                    tmproi(l).display.channel{ck}=tmpfov(i).channel{k}; %['Channel ' num2str(k)];
                    if arrcha(ck)==1
                    tmproi(l).display.intensity(ck,:)=temp;
                    tmproi(l).channelid(ck)=ck;
                    else
                    tmproi(l).display.intensity(ck,:)=[1 1 1];
                    tmproi(l).channelid(cumck:cumck+arrcha(ck)-1)=ck*ones(1,arrcha(k));
                    end

                    tmproi(l).display.selectedchannel(ck)=1;
                    tmproi(l).display.rgb(ck,:)=temp;
                    cumck=cumck+arrcha(ck);
                    ck=ck+1;
      
                end


             %   tmproi(l).channelid=tmproi(l).channelid(1:numel(cha));
                tmproi(l).display.selectedchannel= tmproi(l).display.selectedchannel(1:numel(cha));
                tmproi(l).display.intensity= tmproi(l).display.intensity(1:numel(cha),:);
                tmproi(l).display.rgb= tmproi(l).display.rgb(1:numel(cha),:);
                tmproi(l).results=[];
                tmproi(l).train=[];
                %       return;
                % add additional channels for cell contours if any
                % (phylocell projects)


                %                     if numel(tmpfov(i).contours)
                %
                %                         if isfield(tmpfov(i).contours,'cells1')
                %
                %                             if numel(tmpfov(i).contours.cells1)>1
                %
                %                                 ccc=numel(cha)+1;
                %
                %                                 tmproi(l).display.channel{ccc}='cells1'; %['Channel ' num2str(k)];
                %                                 tmproi(l).display.intensity(ccc,:)=temp;
                %                                 tmproi(l).channelid(ccc)=ccc;
                %                                 tmproi(l).display.selectedchannel(ccc)=1;
                %                                 tmproi(l).display.rgb(ccc,:)=temp;
                %
                %                             end
                %                         end
                %
                %
                %                         if isfield(tmpfov(i).contours,'nucleus')
                %
                %                             if numel(tmpfov(i).contours.nucleus)>1
                %                                 ccc=ccc+1;
                %
                %                                 tmproi(l).display.channel{ccc}='nucleus'; %['Channel ' num2str(k)];
                %                                 tmproi(l).display.intensity(ccc,:)=temp;
                %                                 tmproi(l).channelid(ccc)=ccc;
                %                                 tmproi(l).display.selectedchannel(ccc)=1;
                %                                 tmproi(l).display.rgb(ccc,:)=temp;
                %
                %                             end
                %                         end
                %
                %                     end

                % write here
                tmproi(l).save;
                %       tmproi(l).clear;
            end

            %cc=1;


            % make a test on ROI value
            rroitmp=[];
            rroitmp(1)=max(rroi(1),1);
            rroitmp(2)=max(rroi(2),1);
            rroitmp(3)=min(rroi(1)+rroi(3)-1,size(list,2));
            rroitmp(4)=min(rroi(2)+rroi(4)-1,size(list,1));

            tmproi(l).image(:,:,:,nframes)=list(rroitmp(2):rroitmp(4),rroitmp(1):rroitmp(3),:,:);

            try
                tmproi(l).save;
                tmproi(l).clear;
                disp(['Saved images for ROI ' tmproi(l).id ' in FOV : ' tmpfov(i).id]); %d / %d ROIs saved for FOV %s', l , numel(tmpfov(i).roi), tmpfov(i).id); %Don't forget this semicolon

                %                     if numel(tmproi(l).im)==0
                %                         disp(['Unable to load ROI ' num2str(l)]);
                %                         dumprecovery(fovid,framecell,i,ii);
                %                         return;
                %                     end
            catch
                disp(['Unable to save ROI ' num2str(l)]);
                disp(' This is an I/O CRASH: start ROI extraction again with crashrecovery mode set to 1');
                dumprecovery(fovid,framecell,i,ii);
                %return;
            end


            %tmpfov(i).roi(l).clear;

            % msg = sprintf('Images in %d / %d ROIs saved for FOV %s', l , numel(tmpfov(i).roi), tmpfov(i).id); %Don't forget this semicolon
            % fprintf([reverseStr, msg]);
            %  reverseStr = repmat(sprintf('\b'), 1, length(msg));
        end
    end
    % fprintf('\n');

% restore roi object structure
for l=1:numel(tmpfov(i).roi)
    tmpfov(i).roi(l)=tmproi(l);
    %tmpfov(i)=propValues(tmpfov(i),obj.fov(i));
end

end


for i=fovid % restore obj structure
    obj.fov(i)=tmpfov(i);
    %  for l=1:numel(obj.fov(i).roi)
    %       obj.fov(i).roi(l).clear;
    %  end
end

disp('Saving project...');

shallowSave(obj);

if exist(fullfile(userpath, 'tmpcrash.mat')) % removing tmp crash file
    disp('Removing crash log file...');
    load(fullfile(userpath, 'tmpcrash.mat'));
    delete(fullfile(userpath, 'tmpcrash.mat'));
end

toc;

function newObj=propValues(newObj,orgObj)
pl = properties(orgObj);
for k = 1:length(pl)
    if isprop(newObj,pl{k})
        newObj.(pl{k}) = orgObj.(pl{k});
    end
end


function dumprecovery(fovid,framecell,currentfovid,currentframe)

tmpcrash =[];
tmpcrash.fovid=fovid;
tmpcrash.framecell=framecell;
tmpcrash.currentfovid=currentfovid;
tmpcrash.currentframe=currentframe;
save(fullfile(userpath, 'tmpcrash.mat'),'tmpcrash');



