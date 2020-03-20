function cleartraining(obj,str)

fprintf('Clear training for all traps\n');
for i=1:numel(obj.trap)
   %obj.trap(i).cleartraining;
   obj.trap(i).cleartraining(str);
   
   if strcmp(str,'pix')
   obj.trap(i).pixtree=[];
   obj.trap(i).objtree=[];
   end
   
   if strcmp(str,'div')
   obj.trap(i).div.tree=[];
   end
   %fprintf('.')
   
   if mod(i,50)==0
  %    fprintf('\n'); 
   end
end

if strcmp(str,'pix')
    obj.pixclassifier=[];
    obj.pixclassifierpath=[];
    obj.objclassifier= [];
    obj.objclassifierpath=[];
end


if strcmp(str,'div')
obj.divclassifier=[];
obj.divclassifierpath=[];
end