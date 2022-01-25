function output=parseInputData(pathdir,varargin)
% this function is used to parse input file or directory when importing
% data

output=[];
%output.posinfolder=0; % 1 : positions are stored as folders; 0 positions are stores as files in the same folder, multitiff or not
output.pos=[];
output.pos.channels=[];
output.pos.frames=[];
output.pos.pathlist={};
output.pos.unfilteredpathlist={};
output.pos.unfilteredfilelist={};
output.pos.filelist={};
output.pos.binning=[];
output.pos.interval=[];
output.pos.name=[];
output.pos.contours=[];
output.pos.positionfilter={'xy$','s$'};
output.pos.channelfilter={'channel$','_w$'};
output.pos.stackfilter={'_z$'};

output.pos.positionfilter2={}; % output filter
output.pos.channelfilter2={};
output.pos.stackfilter2={};

output.pos.channelname={};
output.comments='';
output.datatype='';
progress=[];
typ=[];

% check if stringrepresents a valid file or folder
                
switch exist(pathdir)
    case 7 % is a dir
        
    otherwise
        disp('this directory does not exist ! Quitting !')
         output.comments='Folder does not exist!';
        return;
end
    
% include additional input parameters
for i=1:numel(varargin)
    if strcmp(varargin{i}, 'channelfilter')
        output.pos.channelfilter=varargin{i+1};
    end
      if strcmp(varargin{i}, 'stackfilter')
        output.pos.stackfilter=varargin{i+1};
      end
       if strcmp(varargin{i}, 'positionfilter')
        output.pos.positionfilter=varargin{i+1};
       end
      
       if strcmp(varargin{i}, 'progress') % progress bar 
       progress=varargin{i+1};
    end
end

% list files and folder present in the propose directory
info='Listing files and folders....';
 disp(info);
 if numel(progress)
 progress.Message=info;
 end
 
list=dir(pathdir);

% if there are directories avaialable, ignore files in the folder and
% consider directories as distinct positions
% unless there is .mat file corresponding to a phyloCell project

if numel(list)==0
    disp('this directory is empty ! Quitting !')
    return;
end

pix=[list.isdir];
phyloproj=[];

if sum(pix)>2 % there are folders available (. and .. are not real folders)
    % check if there is a phyloCell project
    phyloproj=list((contains({list.name},{'-project.mat'})) & (~contains({list.name},{'BK-project.mat'})));
    
    if numel( phyloproj ) % phylocell project was found
        disp('This folder contains a phylocell project');
        typ='phylocell';
         info='Processing phylocell project...';
    else
        disp('This folder contains one or several folders, which will be processed as separate positions');
        typ='folders';
        output.posinfolder=1;
    end
else % only files available
    disp('This folder contains one or several files but no folders');
    
    
    plist= list([list.isdir]==0);
    plist=plist(contains({plist.name},{'.tif','.jpg'})); % takes all image files
    
    if numel(plist)
        disp('This folder contains image files');
    else
        disp('This folder does not contain image files...Quitting!');
        output.comments='No image files available!';
        return;
    end
    
    plist=plist(contains({plist.name},{'.tif'}));
    % takes all image files
    
     
    if numel(plist)
        im=imfinfo(fullfile(plist(1).folder,plist(1).name));
        
        if numel(im)>1  % multi tif file
            disp('This folder contains multifiles files, which will be processed as separate positions');
           typ='multitif';
            info='Processing multi tiff images...';
        end
    end
    
    if ~strcmp(typ,'multitif') % if list single tif/jpg file, then use the build folder method with one single folder
       
        typ='multifiles';
        
%         typ='folders';
%         info='Processing folder(s)...';
%         list=dir(fullfile(pathdir,'..'));
%         
%   %     list
%         for i=1:numel(list)
%              bb= list(i).name;
%              
%           %   aaa=endsWith(pathdir,bb)
%           %  tt= pathdir(end-numel(bb)-1:end-numel(bb)-1)
%             if endsWith(pathdir,bb) % & ( strcmp(pathdir(1:end-numel(bb)),'/') | strcmp(pathdir(1:end-numel(bb)),'\'))
%                 
%                 tt=pathdir(end-numel(bb):end-numel(bb));
%                 if strcmp(tt,'/') || strcmp(tt,'\')
%                 list=list(i);
%                 break
%                 end
%             end
%         end
        
    end

end

%list

 disp(info);
 if numel(progress)
 progress.Message=info;
 end
 

switch typ
    case 'phylocell'  % this is a phyloCell project
        
        output.comments=['The folder contains a phylocell project' char(10)];
        output= buildphylocell(phyloproj,output,progress);

    case 'folders' % process each folder as independent positions (incldues micromanager)
        
         output.comments=['The folder(s) contains (a) series of individual images' char(10)];
        output = buildfolders(list,output,progress);
        
    case 'multifiles' % contains a list of files, potentially with multiple poistions 
        
         output.comments=['The folder contains (a) series of individual images with multiple poistions' char(10)];
        output = buildmultifiles(list,output,progress);     
        
    case 'multitif'  % check if it a list of files or a collection of mutitiff files (positions)
        
          output.comments=['The folder contains (a) series of multi-tiff images' char(10)];
         output=buildmultitif(list,output,progress);
end

output.datatype=typ;





  






