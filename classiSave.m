function classiSave(classiObj)


[path,file]=classiObj.getPath;

reverseStr='';
cc=1;

fprintf('\n');
reverseStr='';
%cc=1;

               for j=1:numel(classiObj.roi)
                   if numel(classiObj.roi(j).id)
                  classiObj.roi(j).save;
                  classiObj.roi(j).clear;
                  disp(['Processed ROI  ' classiObj.roi(j).id])
                   end
               end
               
          %      msg = sprintf('Writing ROIs for classification %d / %d for FOV %s', cc,numel(shallowObj.processing.classification)); %Don't forget this semicolon
            %        fprintf([reverseStr, msg]);
              %      reverseStr = repmat(sprintf('\b'), 1, length(msg));
                    
          %          cc=cc+1;

 classiObj.log('Classi is saved','Creation')

 if isfolder(path)
save(fullfile(path,[file '_classification.mat']),'classiObj');
            
disp(['Classification ' fullfile(path,[file '_classification.mat']) ' is saved !']);
 else
 disp('Could not find/access the requested folder  ; Check your connection! Quitting!');
 end