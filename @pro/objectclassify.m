function objclassify(obj,trapsid)

if nargin==1
    trapsid=1:numel(obj.trap);
end

fprintf('Classify objects for all traps\n');
for i=trapsid
   %obj.trap(i).cleartraining;
   obj.trap(i).div.divisionTime=obj.divisionTime;
   obj.trap(i).objectclassify;
  
   %fprintf('.')
   
   if mod(i,50)==0
  %    fprintf('\n'); 
   end
end

