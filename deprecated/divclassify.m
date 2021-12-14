function divclassify(obj,trapsid)

if nargin==1
    trapsid=1:numel(obj.trap);
end

for i=trapsid
   %obj.trap(i).cleartraining;
   obj.trap(i).divclassify;
   fprintf('.')
   
   if mod(i,50)==0
      fprintf('\n'); 
   end
end

