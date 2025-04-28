function save(obj,option)
% saves data associated with a given trap and clear memory
% option==results : saves the roi.result only

im=obj.image;
roiobj=obj;
results=obj.results;
data=obj.data;
% save images

resonly=0;
if nargin==2
    if strcmp(option,'data') % load only the results
        resonly=1;
     %   disp(['Saving data only for ROI ' obj.id]);
    end
end

% if resonly==1
%     obj.log(['Saving data only to ' obj.path '/data_' obj.id '.mat'],'Saving')
%     disp(['Saving ROI data ' obj.id ' to ' obj.path '/data_' obj.id '.mat']);
%     eval(['save  ' '''' obj.path '/data_' obj.id '.mat' ''''  ' data']);
%     return;
% end

%if numel(im)~=0
    %   ['save  ' '''' obj.path '/im_' num2str(obj.id) '.mat' ''''  ' im']
    %  disp('');

    
%else

 % if numel(im)==0
 %   disp('Image is not loaded ; Load image first ...');
 %   return;
 % end

    % disp(['Saving ROI image and data to ' obj.id ' to ' obj.path '/im_' obj.id '.mat']);   
    % obj.log(['Saving ROI to ' obj.path '/im_' obj.id '.mat'],'Saving')
 %   obj.log(['Saving data to ' obj.path '/data_' obj.id '.mat'],'Saving')


if numel(obj.path)
   if isfolder(obj.path)
  %  eval(['save  ' '''' obj.path '/im_' obj.id '.mat' ''''  ' roiobj']);   
   % disp(['Saving ROI data to ' obj.id ' to ' obj.path '/data_' obj.id '.mat']);
  %  eval(['save  ' '''' obj.path '/data_' obj.id '.mat' ''''  ' data']);

  

    success = false;
attempts = 0;
max_attempts = 5;

%filename = fullfile(obj.path, ['im_' obj.id '.mat']);


while ~success && attempts < max_attempts
    try
        if ~isempty(im) && resonly==0
         save(fullfile(obj.path, ['im_' obj.id '.mat']), 'roiobj');
          obj.log(['Saving ROI to ' obj.path '/im_' obj.id '.mat'],'Saving')
          disp(['Saving content of ROI# ' obj.id ' to ' obj.path 'im_' obj.id '.mat']);   
        else
         if resonly==0
         disp('Image is not loaded ; Load image first ...');
         end
         %success=true;
        end

       % if resonly==1
       
       if resonly==1 || ( numel(data)>=1  && numel(data.groupid))
         save(fullfile(obj.path, ['data_' obj.id '.mat']), 'data');
         obj.log(['Saving data  to ' obj.path '/data_' obj.id '.mat'],'Saving')
         disp(['Saving data of ROI# ' obj.id ' to ' obj.path 'data_' obj.id '.mat']);
       end
       
       if  (numel(data)>=1  && numel(data.groupid)) 
       else
             disp('No data to save....');
       end

        success = true;
       % end

    catch ME
        disp(['Erreur lors de la sauvegarde de ' filename ' : ' ME.message]);
        pause(0.5);  % attendre avant de réessayer
        attempts = attempts + 1;
    end
end

if ~success
    error(['Échec de la sauvegarde après ' num2str(max_attempts) ' tentatives.']);
end

    else
       disp('ERROR: Could not find / access the requested folder !!! ');
   end
end

% '''' allows one to use quotes !!!


 
