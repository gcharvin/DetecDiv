function shallowObj=shallowNew(varargin)
% define new analysis project
% varargin: 'Path' 'Filename' to input the location and path of the
% project. 

path=pwd; 
filename='myproject';

if nargin~=0
for i=1:numel(varargin)
    
if strcmp(varargin{i},'path')
path=varargin{i+1};
end

if strcmp(varargin{i},'filename')
filename=varargin{i+1};
end
end
else
  [filename,path,rep] = uiputfile('*.mat','File Selection',fullfile(path,[filename '.mat']));
  if isequal(filename,0)
   disp('User selected Cancel');
   shallowObj=[];
   return;
   else
   disp(['User selected ', fullfile(path, filename)]);
  end
end

if numel(strfind(filename,'.mat'))
    filename=replace(filename,'.mat','');
end

shallowObj=shallow;
shallowObj.setPath(path,filename);

mkdir(path,filename);

save(fullfile(path,[filename '.mat']),'shallowObj');

disp(['Shallow project ' fullfile(path,[filename '.mat']) ' is created and saved !']);
disp([ 'To add image / phyloCell project to the data, use the addData function']);


% hf=figure('Position',[100 100 650 400]); 
% 
% userparam= uitable('Parent',hf,'Position', [25 250 600 150], 'CellEditCallback',@celledit,'CellSelectionCallback',@cellselect);
% 
% set(userparam, 'ColumnName', {'Property', 'user Input'},'ColumnWidth',{150 400});
% 
% folder=pwd;
% Data={'Output Path',folder;'Number of channel', 2; 'PhyloCell-> 0; list of files->1', 1; 'Project file (phyloCell only)','' }
% 
% 
% userparam.Data=Data;
% set(userparam, 'ColumnEditable', [false true])
% 
% function celledit(handles, event, obj)
% 
% 
% function cellselect(handles, event, obj)



% GFPChannel=2;
% PhaseChannel=1;
% positions=[];
% outputPath='.';
% outputFilename='moviProject.mat';
% 
% for i=1:numel(varargin)
%     
%     if strcmp(varargin{i},'ImageFolder') % phase channel filename in case 
%             imagepath=varargin{i+1}; % cell array that contains path of all the folders to be loaded
%     end
%     if strcmp(varargin{i},'OutputPath')
%         outputPath=varargin{i+1};
%     end
%     if strcmp(varargin{i},'OutputFilename')
%         outputFilename=varargin{i+1};
%     end
%      if strcmp(varargin{i},'Positions')
%         positions=varargin{i+1};
%      end
%     
%      if strcmp(varargin{i},'GFPChannel')
%         GFPChannel=varargin{i+1};
%      end
%      
%       if strcmp(varargin{i},'PhaseChannel')
%         PhaseChannel=varargin{i+1};
%       end
%      
%      
%     
% end
% 
% [pth fle ext]=fileparts(inputfile);
% 
% [opth ofle oext]=fileparts(outputFilename);
% 
% 
% 
% if numel(pth)==0
%    pth=pwd ;
% end
% 
% if strcmp(ext,'.mat') % phylocell project file
%    % 'ok'
%    load(inputfile) 
%    
%     
%    if numel(positions)==0
%        %timeLapse.position
%       positions=1:numel(timeLapse.position.list);
%    end
%    
%    % create a movi object for each of the position
%    cc=1;
%    %mov=movi('test','test');
%    for i=positions
%    %timeLapse.position
%        strpos=[pth '/' timeLapse.filename '-pos' num2str(i)];
%        
%        for j=1:numel(timeLapse.list)
%            pathname{j}= [strpos '/' timeLapse.filename '-pos' num2str(i) '-ch' num2str(j) '-' timeLapse.list(j).ID];
%        end
%       
%        mov(cc)=movi(pathname,timeLapse.filename,GFPChannel,PhaseChannel);
%        
%        mov(cc).path=[outputPath '/' ofle '-pos' num2str(i)];
%        mov(cc).id=['pos' num2str(i)];
%        mov(cc).projectpath= [outputPath '/' outputFilename];
%        
%        mkdir([outputPath '/' ofle '-pos' num2str(i)]); % directory to store mat files
%        
%        eval(['save '  outputPath '/' outputFilename    ' mov']);
%        
%        cc=cc+1;
%    end
%    
%    
% elseif strcmp(ext,'.avi') % input avi file %% not implemented yet
%           pathname{1}=inputfile;
%           pathname{2}=varargin{1};
%           filename=fle;
%           mov=movi(pathname,filename,GFPChannel,PhaseChannel);
%           eval(['save '  outputPath '/' outputFilename    ' mov']);
%           
% elseif strcmp(ext,'') % loading images in folders // 1 position only
%     
%    % size(imagepath)
%    % imagepath
%     
%     [pth fle ext]=fileparts(imagepath{1,1});
%     
%     if numel(pth)==0
%     pth=pwd;
%     end
% 
%     for i=1:numel(imagepath)
%     pathname{i}=[pth '/' imagepath{1,i}];
%     end
%     
%     mov=movi(pathname,outputFilename,GFPChannel,PhaseChannel);
%     
%     mov.path=[outputPath '/' ofle '-pos' num2str(1)];
%     mov.id=['pos' num2str(1)];
%     mov.projectpath= [outputPath '/' outputFilename];
%        
%     mkdir([outputPath '/' ofle '-pos' num2str(1)]); % directory to store mat files
%        
%     eval(['save '  outputPath '/' outputFilename    ' mov']);
% end
% 
% 
% 
