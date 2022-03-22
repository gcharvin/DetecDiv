function restore(classif,index)
% restores the current version of a classifier 

   [pth,file]=classif.getPath;
   [t,lastIndex]=classif.version;
   
   tot=size(t,1);
   
   if index>tot
       disp('this index does not exist');
       return;
   end
   
  evalin('base', ['clear ' classif.strid]); % clear classifier variable if loaded.
  
  ff=fullfile(pth,t{index,1});
   copyfile(ff,fullfile(pth,[classif.strid '_classification.mat']));
  load(ff); % classiObj;
  
m=fieldnames(classif);

for i=1:numel(m)
    classif.(m{i})=classiObj.(m{i});
end
 
  ff=fullfile(pth,t{index,4});
 copyfile(ff,fullfile(pth,[classif.strid '.mat']));
 
 
    src=fullfile(pth,['netCNN_' t{index,4} '.mat']);
    target=fullfile(pth,['netCNN_' classif.strid '.mat']);
    
     if exist(src)
                 copyfile(src,target);  
     end
     
     src=fullfile(pth,['netLSTM_' t{index,4} '.mat']);
    target=fullfile(pth,['netLSTM_' classif.strid '.mat']);
    
     if exist(src)
                 copyfile(src,target);  
     end
         
            