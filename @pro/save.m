function save(obj)

% DO NOT USE THIS FUNCTION : USE SAVEPROJECT(OBJ) INSTEAD
% THIS FUNCTION WOULD ERASE THE MOVI ARRAY IN CASE THERE ARE SEVERAL ITEMS
% IN THEM 

% saves movie project and clears memory 


reverseStr = '';
fprintf('Saving traps....\n');

for i=1:numel(obj.trap)
 
   if numel(findobj('Tag',['Trap' obj.trap(i).id]))
       delete(findobj('Tag',['Trap' obj.trap(i).id]))
   end
   
   obj.trap(i).save;
    
   msg = sprintf('%d / %d Traps saved', i , numel(obj.trap) ); %Don't forget this semicolon
    fprintf([reverseStr, msg]);
    reverseStr = repmat(sprintf('\b'), 1, length(msg));
    
     obj.trap(i).clear; % remove image frome memory
end

fprintf('\n');

mov=obj;

fprintf('Saving movie project....\n');

eval(['save  ' obj.projectpath  ' mov']);

fprintf('\n');