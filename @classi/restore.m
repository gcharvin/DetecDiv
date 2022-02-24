function restore(classif,index)
% restores the current version of a classifier 

   [pth,file]=classif.getPath;
   [t,lastIndex]=classif.version;
   
   tot=size(t,1);
   
   if index>tot
       disp('this index does not exist');
       return;
   end
   
  ff=fullfile(pth,t{index,1});
   copyfile(ff,fullfile(pth,[classif.strid '_classification.mat']));
  load(ff); % classiObj;
  
m=fieldnames(classif);

for i=1:numel(m)
    classif.(m{i})=classiObj.(m{i});
end
 
  ff=fullfile(pth,t{index,4});
 copyfile(ff,fullfile(pth,[classif.strid '.mat']));