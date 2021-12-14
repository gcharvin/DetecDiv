function pixclassify(obj,traps)

if nargin==1
   traps =  1:numel(obj.trap);
end

for i=traps
   %obj.trap(i).cleartraining;
   obj.trap(i).pixclassify;
  % fprintf('.')
   
   %if mod(i,50)==0
   %   fprintf('\n'); 
   %end
end

