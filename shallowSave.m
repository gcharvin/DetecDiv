function shallowSave(shallowObj)


[path,file]=shallowObj.getPath;

save(fullfile(path,[file '.mat']),'shallowObj');

disp(['Shallow project ' fullfile(path,[file '.mat']) ' is saved !']);