function repository(obj)
% export classification to a repository folder

% the whole @classi object is copied if a new repository is created
% otherwise, only the ROIs and training datasets are created

list=listRepositoryClassi; % first displays available classi object on the repository
disp(list)

prompt='Please enter the number associated with the classification you wish to transfer to ? (Default:1): ';
classitype= input(prompt);
if numel(classitype)==0
    classitype=1;
end

path=listRepositoryClassi(classitype);

classitoexportto=classiLoad(path);

classitoexportto.importFromClassi(obj) % warning: obj and classito inverted on purpose

classiSave(classitoexportto);

%save([str '/' classiname2 '_classification'],'classification');



















