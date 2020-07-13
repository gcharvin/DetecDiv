function shallow2phyloCell(shallowObj,timeLapseFilePath,varargin)
% outputs shallow data (cell contours, pedigree tracking, etc.) to phyloCell segmentation

% pre-requisite: the shallow project must be based on a phyloCell project,
% so that FOVs corresponds to positions in the timeLapse project



% first load timeLapse variable to include the segmentation variable at the
% right place

load(timeLapseFilePath); % load the timeLapse variable
[path, file, ext] = fileparts(timeLapseFilePath);
timeLapse.realPath=strcat(path);
timeLapse.realName=file;

contours={};
cc=1;

positions=1:numel(timeLapse.position);

% if pedigree is present, the program will look into the results to
% identify the link between cells

for i=1:numel(varargin)
    if strcmp(varargin{i},'cells1')
        contours(cc)={{varargin{i}, varargin{i+1}}}; % indicate the channel in the shallowObj to be used for contour generation
        cc=cc+1;
    end
    if strcmp(varargin{i},'nucleus')
        contours(cc)={{varargin{i}, varargin{i+1}}}; % indicate the channel in the shallowObj to be used for contour generation
        cc=cc+1;
    end
    if strcmp(varargin{i},'budnecks')
        contours(cc)={{varargin{i}, varargin{i+1}}}; % indicate the channel in the shallowObj to be used for contour generation
        cc=cc+1;
    end
    if strcmp(varargin{i},'foci')
        contours(cc)={{varargin{i}, varargin{i+1}}}; % indicate the channel in the shallowObj to be used for contour generation
        cc=cc+1;
    end
    if strcmp(varargin{i},'mito')
        contours(cc)={{varargin{i}, varargin{i+1}}}; % indicate the channel in the shallowObj to be used for contour generation
        cc=cc+1;
    end
    
    if strcmp(varargin{i},'positions')
        positions= varargin{i+1};
    end
end


npoints=32;

for i=positions
    fprintf(['Processing position: ' num2str(i)]);
    fprintf('\n');
    segmentation=phy_createSegmentation(timeLapse,i);
    segmentation.filename='segmentation-shallow.mat';
    maxe=0;
    for j=1:numel(contours)
        
        % loop on ROIs
        c=contours{j};
        ch=c{2};
        chname=c{1};
        
        if numel(shallowObj.fov(j).roi(1).image)==0
            shallowObj.fov(j).roi(1).load;
        end
        
        im=shallowObj.fov(j).roi(1).image;
        
        %size(im)
        % first determine the total number of cells in each ROI
        maxecell=zeros(1,numel(shallowObj.fov(i).roi));
        
        for l=1:size(im,4)
            
            for k=1:numel(shallowObj.fov(i).roi)
                if numel(shallowObj.fov(i).roi(k).id)==0
                    continue
                end
                
                if numel(shallowObj.fov(i).roi(k).image)==0
                    shallowObj.fov(i).roi(k).load;
                end
                
                im=shallowObj.fov(i).roi(k).image(:,:,ch,l);
                maxe=max(im(:));
                
                if maxe>1 % objects are already labeled, must keep the labeling
                    lab=im;
                else
                    [lab maxe]=bwlabel(im);
                end
                
                maxecell(k)=max(maxecell(k),maxe);
            end
        end
        
        maxecell=[0 maxecell];
        maxecell=maxecell(1:end-1);
        im=shallowObj.fov(j).roi(1).image;
        
        for l=1:size(im,4) % now determine cell contours
            %l
            fprintf('.');
            cc=1;
            phy_Objects=phy_Object(1, [],[],0,0,0,0,0);
            segmentation.(chname)(l,1)=phy_Objects;
            
            for k=1:numel(shallowObj.fov(i).roi)
                
                %numel(shallowObj.fov(i).roi(k).id)
                
                if numel(shallowObj.fov(i).roi(k).id)==0
                    continue
                end
                % here fix issue with empty roi
                
                if numel(shallowObj.fov(i).roi(k).image)==0
                    shallowObj.fov(i).roi(k).load;
                end
                
                im=shallowObj.fov(i).roi(k).image(:,:,ch,l); % image with contours
                
                strim=shallowObj.fov(i).roi(k).display.channel{ch};
                
                
                
                mothers=[];
                if numel(shallowObj.fov(i).roi(k).results)>0
                res=fieldnames(shallowObj.fov(i).roi(k).results);
                for n=1:numel(res)
                    % res{n},strim
                    if numel(strfind(strim,res{n}))>0
                        % pedigree data exist for this channel , so display them !
                        mothers=shallowObj.fov(i).roi(k).results.(res{n}).mother;
                    end
                end
                end
                
                maxe=max(im(:));
                
                if maxe>1 % objects are already labeled, must keep the labeling
                    lab=im;
                else
                    [lab maxe]=bwlabel(im);
                end
                
                
                
                for m=1:maxe
                    tmp=lab==m;
                    
                    idx=round(mean(im(tmp))); % cell index
                    
                    cont= bwboundaries(tmp);
                    
                    if numel(cont)==0
                        continue
                    end
                    
                    cont = cont{1};
                    [xnew, ynew]=phy_changePointNumber(cont(:, 2),cont(:, 1),npoints);
                    
                    
                    xnew= xnew+ shallowObj.fov(i).roi(k).value(1);
                    ynew= ynew+ shallowObj.fov(i).roi(k).value(2);
                    
                    % k,idx,maxecell
                    idx2=idx+maxecell(k);
                    
                    phy_Objects(cc) = phy_Object(idx2, xnew, ynew,0,0,mean(xnew),mean(ynew),0);
                    %idx
                    %mothers
                    %size(mothers)
                    if numel(mothers)>=idx
                        phy_Objects(cc).mother=mothers(idx)+maxecell(k);
                    end
                    
                    phy_Objects(cc).image=l;
                    %idx2
                    cc=cc+1;
                end
            end
            
            segmentation.(chname)(l,1:cc-1)=phy_Objects;
            
        end
        fprintf('\n');
        
        if maxe>0
            im=shallowObj.fov(j).roi(1).image;
            segmentation.([chname 'Segmented'])(1:size(im,4))=1;
            
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
                segmentation.(['t' chname])=phy_makeTObject(segmentation.(chname));
                segmentation.([chname 'Mapped'])(1:size(im,4))=1;
                
                for kk=1:numel(segmentation.(['t' chname]))
                    mcells=segmentation.(['t' chname])(kk).Obj(1).mother;
                    if mcells>0
                        segmentation.(['t' chname])(kk).setMother(mcells);
                        segmentation.(['t' chname])(mcells).addDaughter(kk,segmentation.(['t' chname])(kk).Obj(1).image,segmentation.(['t' chname])(kk).Obj(1).image); %add a new daughter to the mother
                    end
                end
            end
        end
    end
    
    save(fullfile(timeLapse.realPath,timeLapse.pathList.position{segmentation.position},segmentation.filename),'segmentation');
end
