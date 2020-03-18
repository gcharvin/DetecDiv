function saveProject(obj)

% save project file in case there are multiple instances of movie in
% project 



fprintf('Saving project....\n');

for j=1:numel(obj)
    fprintf(['Entering movi ' num2str(j) ' / ' num2str( numel(obj)) ': ']);
   reverseStr = ''; 
   
for i=1:numel(obj(j).trap)
 
  %  j,i
   if numel(findobj('Tag',['Trap' obj(j).trap(i).id]))
       delete(findobj('Tag',['Trap' obj(j).trap(i).id]))
   end
   
   obj(j).trap(i).save;
    
   msg = sprintf('%d / %d Traps saved', i , numel(obj(j).trap) ); %Don't forget this semicolon
    fprintf([reverseStr, msg]);
    reverseStr = repmat(sprintf('\b'), 1, length(msg));
    
     obj(j).trap(i).clear; % remove image frome memory
end
fprintf('\n');
end

fprintf('\n');

mov=obj;

fprintf('Saving movie project....\n');

eval(['save  ' obj(1).projectpath  ' mov']);

fprintf('\n');

