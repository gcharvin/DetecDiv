function shallowSave(shallowObj)


[path,file]=shallowObj.getPath;

for i=1:numel(shallowObj.fov)
               for j=1:numel(shallowObj.fov(i).roi)
                  shallowObj.fov(i).roi(j).save;
                  shallowObj.fov(i).roi(j).clear;
               end
end

for i=1:numel(shallowObj.processing.classification)
               for j=1:numel(shallowObj.processing.classification(i).roi)
                  shallowObj.processing.classification(i).roi(j).save;
                  shallowObj.processing.classification(i).roi(j).clear;
               end
end
           

save(fullfile(path,[file '.mat']),'shallowObj');

disp(['Shallow project ' fullfile(path,[file '.mat']) ' is saved !']);