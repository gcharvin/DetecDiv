function createPhylocellProject(data,progressbar)
% exports shallow obj projet to phylocell

%data is a struct with fields:
% shallowObj : shallow object class
% frames : frames to be imported in the project
% positions : positions in the project
% file : filename for the phylocell project
% path : path where to store the phyloell project
% exportparam : parameters to specify channels to import etc.
% newproject : true : create new structure; false : loads existing
% timeLapse project

global timeLapse

if data.newproject
    timeLapse=[];
    timeLapse.currentFrame=1;
    timeLapse.filename=data.file;
    timeLapse.path=data.path;
    timeLapse.realPath=timeLapse.path;
    timeLapse.position=[];
    timeLapse.position=[];
    timeLapse.position.list=[];
    timeLapse.position.list.name=[];
    timeLapse.numberOfFrames=1;
    timeLapse.list=[];
else
    % load existing timeLapse project
    if exist(fullfile(data.path,data.file))
        load(fullfile(data.path,data.file))
    else
        disp('project does not exist; quitting....');
    end
end

positions=str2num(data.positions);
rois=str2num(data.ROI);
frames=str2num(data.frames);

totalpositions=numel(positions)*numel(rois);

%%%%%%%%%%%%%%%%%%%
% selected channels
%%%%%%%%%%%%%%%%%%%%

param= data.exportparam; % table with column name : selectection, channelname, type of export (raw image,
selchannels=find(cellfun(@(x) x==1,param(:,1)));

selrawchannels=find(cellfun(@(x) x=="Raw image",param(:,3)));
selrawchannels=intersect(selchannels,selrawchannels);

selrawchannelsorder=str2num(cell2mat(param(selrawchannels,5)));
[~,  selrawchannelsorder]= sort(selrawchannelsorder);

selcontourchannels=find(cellfun(@(x) x~="Raw image",param(:,3)));
selcontourchannels=intersect(selcontourchannels,selchannels);

%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%

if data.newproject
    
    % create directory tree
    
    progressbar.Message= 'Creating directory tree... ';
    progressbar.Value=0.2;
    pause(0.1);
    
    for i=1:numel(selrawchannels)
        ch=selrawchannels(selrawchannelsorder(i));
        timeLapse.list(i).ID=param{ch,4};
    end
    
    timeLapse.numberOfFrames=numel(frames);
    
    p=[];
    p.name=[];
    p.pos=[];
    
    cc=1;
    
    for i=1:numel(positions)
        for j=1:numel(rois)
            p(cc).name=data.shallowObj.fov(i).roi(j).id;
            p(cc).pos=[i,j];
            timeLapse.position.list(cc).name=p(cc).name;
            cc=cc+1;
        end
    end
    
    
    for i=1:totalpositions
        
        progressbar.Value=0.2+(i-1)*0.2./totalpositions;
        
        % posname=positions(i);
        
        dirpos=strcat(timeLapse.filename,'-pos',int2str(i));
        
        if isfolder(strcat(timeLapse.path,dirpos))
            rmdir(strcat(timeLapse.path,dirpos),'s');
        end
        
        mkdir(timeLapse.path,dirpos);
        timeLapse.pathList.position(i)=cellstr(strcat(dirpos,'/'));
        
        for j=1:numel(selrawchannels)
            
            ch=selrawchannels(selrawchannelsorder(j));
            
            chname=[ p(i).name '-' param{ch,4} ];
            
            chpos=strcat(timeLapse.filename,'-pos',int2str(i),'-ch',int2str(j),'-',chname);
            path2=strcat(timeLapse.path,dirpos);
            
            %    fullpath=strcat(path2,chpos);
            mkdir(path2,chpos);
            
            timeLapse.pathList.channels(i,j)=cellstr(strcat(dirpos,'/',chpos,'/'));
            timeLapse.pathList.names(i,j)=cellstr(chpos);
            
        end
    end
    
    
    % saving images to files
    
    progressbar.Message= 'Saving Images... ';
    progressbar.Value=0.4;
    pause(0.1);
    
    for i=1:totalpositions
        
        progressbar.Message=['Saving position : ' num2str(i) ' / ' num2str(totalpositions)];
         
        progressbar.Value=0.4+(i-1)*0.4./totalpositions;
        
        dirpos=strcat(timeLapse.filename,'-pos',int2str(i));
        
        im=data.shallowObj.fov(p(i).pos(1)).roi(p(i).pos(2)).image;
        
        if numel(im)==0
            data.shallowObj.fov(p(i).pos(1)).roi(p(i).pos(2)).load;
        end
        
        im=data.shallowObj.fov(p(i).pos(1)).roi(p(i).pos(2)).image;
        
        for j=1:numel(selrawchannels)
            
            ch=selrawchannels(selrawchannelsorder(j));
            chname=[ p(i).name '-' param{ch,4} ];
            
            chpos=strcat(timeLapse.filename,'-pos',int2str(i),'-ch',int2str(j),'-',chname);
            path2=strcat(timeLapse.path,dirpos,'/');
            fullpath=strcat(path2,chpos,'/');
            
            list=strcat(fullpath,timeLapse.filename,'-pos',int2str(i),'-ch',int2str(j),'-',chname,'-list.txt');
            
            shallowcha=param{ch,2};
            pix=data.shallowObj.fov(p(i).pos(1)).roi(p(i).pos(2)).findChannelID(shallowcha);
            imch=im(:,:,pix,:);
            
            for k=1:numel(frames)
                
                strfra=num2str(k);
                
                while(numel(strfra)<3)
                    strfra=['0' strfra];
                end
                
                str=strcat(fullpath,timeLapse.filename,'-pos',int2str(i),'-ch',int2str(j),'-',chname,'-',strfra,'.jpg');
                str2=strcat(timeLapse.filename,'-pos',int2str(i),'-ch',int2str(j),'-',chname,'-',strfra,'.jpg');
                
                outputim=imch(:,:,:,frames(k));
                
                imwrite(outputim,str,'BitDepth',16,'Mode','lossless');
                dlmwrite(list, str2,'-append','delimiter','');
                
            end
            
        end
        
        
    end
    
end

%%%%%%%%%%
% saving cell contours
%%%%%%%%%

progressbar.Message= 'Saving object contours... ';
pause(0.1);


npoints=32;
shallowObj=data.shallowObj;

for i=1:totalpositions
    segmentationarr(i)=phy_createSegmentation(timeLapse,i);
    %ccs=ccs+1;
end

%for i=1: numel(selcontourchannels)
%   type=param{ch,3};
%end


  progressbar.Message= 'Saving object contours... ';
    progressbar.Value=0.8;
    pause(0.1);
    
for mn=1:totalpositions
    
     progressbar.Message=['Saving contours for position : ' num2str(mn) ' / ' num2str(totalpositions)];
     progressbar.Value=0.8+(mn-1)*0.2./totalpositions;
     
    %   i=positions(mn);
    
    disp(['Processing position: ' num2str(mn)]);
    %fprintf('\n');
    %segmentationarr(cc)=phy_createSegmentation(timeLapse,i);
    segmentationarr(mn).filename='segmentation-shallow.mat';
    maxe=0;
    
     fovid=p(mn).pos(1);
     roiid=p(mn).pos(2);
     
    
    for j=selcontourchannels
        
        % loop on ROIs
        % c=contours{j};
        %ch=c{2};
        % chname=c{1};
        
        chname=param{j,3};
        shallowch=param{j,2};
        
      segmentationarr(mn).([chname 'Segmented'])(frames)=0;
      segmentationarr(mn).([chname 'Mapped'])(frames)=0;

        if numel(shallowObj.fov( fovid).roi(roiid).image)==0
            shallowObj.fov(fovid).roi(roiid).load;
        end
        
        im=shallowObj.fov(fovid).roi(roiid).image;
        
        pix=data.shallowObj.fov(fovid).roi(roiid).findChannelID(shallowch);
        imch=im(:,:,pix,:);
        
        strim=shallowch;
        
        
        
        mothers=[];
        if numel(shallowObj.fov(fovid).roi(roiid).results)>0
            res=fieldnames(shallowObj.fov(fovid).roi(roidi).results);
            for n=1:numel(res)
                % res{n},strim
                if numel(strfind(strim,res{n}))>0
                    % pedigree data exist for this channel , so display them !
                    mothers=shallowObj.fov(fovid).roi(roiid).results.(res{n}).mother;
                end
            end
        end
        
        maxe=max(imch(:));
        
        for l=frames % now determine cell contours
            %l
            fprintf('.');
            cc=1;
            phy_Objects=phy_Object(1, [],[],0,0,0,0,0);
            segmentationarr(mn).(chname)(l,1)=phy_Objects;
            
            imtmp=imch(:,:,1,l);
            
            alreadylabeled=0;
            if maxe>1 % objects are already labeled, must keep the labeling
                lab=imtmp;
                alreadylabeled=1;
          %      'labeled'
            else
         %       'not labeled'
                [lab maxe]=bwlabel(imtmp);
            end
            
            
               
             cont= bwboundaries(lab);
                
         %    tic
             cc=1; 
             for m=1:numel(cont)
                 
                 x=cont{m}(:,2);
                 y=cont{m}(:,1);
                 [xnew, ynew]=phy_changePointNumber(x,y,npoints);
                 
                  idx= uint16( lab( uint16(round(mean(ynew))) , uint16(round(mean(xnew))) ) );
                  
                  phy_Objects(cc) = phy_Object(idx, xnew, ynew,0,0,mean(xnew),mean(ynew),0);
                  phy_Objects(cc).image=l;
                 
                  cc=cc+1;
             end
            
            
            segmentationarr(mn).(chname)(l,1:cc-1)=phy_Objects;
            
        end
    end
    fprintf('\n');
    
    
    if maxe>0
        im=shallowObj.fov(fovid).roi(roiid).image;
        segmentationarr(mn).([chname 'Segmented'])(frames)=1;
        
        % plot pedigree --> assign mother cell and division times
        %         mothers={};
        %         for k=1:numel(shallowObj.fov(i).roi)
        %
        %                 for n=1:numel(res)
        %                    if numel(strfind(res{n},strim))>0
        %                        % pedigree data exist for this channel , so display them !
        %                        mothers{k}=shallowObj.fov(j).roi(k).results.(res{n});
        %                    end
        %                 end
        %         end
        % maxe
        if maxe>1 % objects are tracked , so create tObjects
            %'ok'
            segmentationarr(mn).(['t' chname])=phy_makeTObject(segmentationarr(mn).(chname));
            segmentationarr(mn).([chname 'Mapped'])(frames)=1;
            
            for kk=1:numel(segmentationarr(mn).(['t' chname]))
                mcells=segmentationarr(mn).(['t' chname])(kk).Obj(1).mother;
                if mcells>0
                    segmentationarr(mn).(['t' chname])(kk).setMother(mcells);
                    segmentationarr(mn).(['t' chname])(mcells).addDaughter(kk,segmentationarr(mn).(['t' chname])(kk).Obj(1).image,segmentationarr(mn).(['t' chname])(kk).Obj(1).image); %add a new daughter to the mother
                end
            end
        end
    end
    
     segmentation=segmentationarr(mn);
    save(fullfile(timeLapse.realPath,timeLapse.pathList.position{segmentationarr(mn).position},segmentationarr(mn).filename),'segmentation');
end
   

%%%%%%%%%%%%%%%%
% saving timelapse variable
%%%%%%%%%%%%%%%%

save(fullfile(timeLapse.path,[timeLapse.filename,'-project.mat']),'timeLapse');








