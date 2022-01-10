function processSave(processObj)


[path,file]=processObj.getPath;


       

processObj.log('Classi is saved','Creation')

 if isfolder(path)
save(fullfile(path,[file '_processor.mat']),'processObj');
            
disp(['Processor ' fullfile(path,[file '_processor.mat']) ' is saved !']);
 else
 disp('Could not find/access the requested folder  ; Check your connection! Quitting!');
 end