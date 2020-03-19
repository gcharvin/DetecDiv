function shallowLoad(filename)

if nargin==1
   load(filename) 
else
   [file,path] = uigetfile(userpath,'*.mat','Select a shallow project');
   if isequal(file,0)
   disp('User selected Cancel')
   else
   disp(['User selected ', fullfile(path, file)]); 
   end
end
