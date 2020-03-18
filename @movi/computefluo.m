function computefluo(obj,trapsid)

if nargin==1
    trapsid=1:numel(obj.trap);
end

cc=1;
for i=trapsid
   %obj.trap(i).cleartraining;
   obj.trap(i).computefluo;
   fprintf('.')
   
   if mod(cc,50)==0
      fprintf('\n'); 
   end
   
   cc=cc+1;
end