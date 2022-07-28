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

  [classiObj msg]=classiLoad(ff);

 %  copyfile(ff,fullfile(pth,[classif.strid '_classification.mat']));
  %load(ff); % classiObj;
  
m=fieldnames(classif);

for i=1:numel(m)
    if ~strcmp(m{i},'roi') % preserve ROI info which cannot be preserved and bakckup
    classif.(m{i})=classiObj.(m{i});
    end
end

  save([classif.strid '_classification.mat'],'classiObj');

 
  ff=fullfile(pth,t{index,4});
 % exist(ff)
  targ=fullfile(pth,[classif.strid '.mat']);

 load(ff); % loads classifier
 save(targ,'classifier');
% copyfile(ff,fullfile(pth,[classif.strid '.mat']));
 
    src=fullfile(pth,['netCNN_' t{index,4}]);
    target=fullfile(pth,['netCNN_' classif.strid '.mat']);
    
     if exist(src)
             load(src); % loads classifier
             save(target,'classifier')
              %   copyfile(src,target);  
     end
     
     src=fullfile(pth,['netLSTM_' t{index,4}]);
    target=fullfile(pth,['netLSTM_' classif.strid '.mat']);
    
     if exist(src)
          load(src); % loads classifier
          save(target,'netLSTM','info')
             %    copyfile(src,target);  
     end
         
            