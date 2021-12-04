function shallowSave(shallowObj,option,progress)


[path,file]=shallowObj.getPath;

reverseStr='';
cc=1;
shallowObjOnly=0;

if nargin>=2
    if strcmp(option,'shallowObj') % load only the results
        shallowObjOnly=1;
        disp(['Saving only shallowObj ' obj.id]);
    end
end

fprintf('\n');

if shallowObjOnly==0
    for i=1:numel(shallowObj.fov)
        
        if nargin==3
            progress.Message=['Saving position' num2str(i) ' /' num2str(numel(shallowObj.fov)) '...'];
            progress.Value= i./numel(shallowObj.fov);
            pause(0.01);
        end
        
        for j=1:numel(shallowObj.fov(i).roi)
            % tic
            shallowObj.fov(i).roi(j).save;
            %toc
            % tic
            shallowObj.fov(i).roi(j).clear;
            %  toc
     
            
        end
        
        msg = sprintf('Writing ROIs for FOV %d / %d for FOV %s', cc,numel(shallowObj.fov)); %Don't forget this semicolon
        fprintf([reverseStr, msg]);
        reverseStr = repmat(sprintf('\b'), 1, length(msg));
        
        cc=cc+1;
    end
    
    % fprintf('\n');
    % reverseStr='';
    % cc=1;
    for i=1:numel(shallowObj.processing.classification)
        
         if nargin==3
            progress.Message=['Saving classifier' num2str(i) ' /' num2str(numel(shallowObj.processing.classification)) '...'];
            progress.Value= i./numel(shallowObj.processing.classification);
            pause(0.01);
         end
        
        classiSave( shallowObj.processing.classification(i) );
        %                for j=1:numel(shallowObj.processing.classification(i).roi)
        %                   shallowObj.processing.classification(i).roi(j).save;
        %                   shallowObj.processing.classification(i).roi(j).clear;
        %                end
        %
        %                 msg = sprintf('Writing ROIs for classification %d / %d for FOV %s', cc,numel(shallowObj.processing.classification)); %Don't forget this semicolon
        %                     fprintf([reverseStr, msg]);
        %                     reverseStr = repmat(sprintf('\b'), 1, length(msg));
        %
        %                     cc=cc+1;
    end
end

fprintf('\n');

save(fullfile(path,[file '.mat']),'shallowObj');

disp(['Shallow project ' fullfile(path,[file '.mat']) ' is saved !']);