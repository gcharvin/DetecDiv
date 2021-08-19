function classiSave(classiObj)


[path,file]=classiObj.getPath;

reverseStr='';
cc=1;

fprintf('\n');
reverseStr='';
%cc=1;


               for j=1:numel(classiObj.roi)
                  classiObj.roi(j).save;
                  classiObj.clear;
               end
               
          %      msg = sprintf('Writing ROIs for classification %d / %d for FOV %s', cc,numel(shallowObj.processing.classification)); %Don't forget this semicolon
            %        fprintf([reverseStr, msg]);
              %      reverseStr = repmat(sprintf('\b'), 1, length(msg));
                    
          %          cc=cc+1;
           

fprintf('\n');

save(fullfile(path,[file '_classification.mat']),'classiObj');

disp(['Classification ' fullfile(path,[file '_classification.mat']) ' is saved !']);