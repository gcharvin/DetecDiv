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
cancelTokenFile='';
typ=[];

% check if string represents a valid file or folder
inputIsFile = false;
inputFileName = '';

switch exist(pathdir)
    case 7 % is a dir
    case 2 % is a file
        inputIsFile = true;
        [~, inputFileName, inputExt] = fileparts(pathdir);
        inputFileName = [inputFileName inputExt];
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
    if strcmpi(varargin{i}, 'canceltokenfile') || strcmpi(varargin{i}, 'cancel_token_file')
        cancelTokenFile=char(string(varargin{i+1}));
    end
end
progress = attachCancelTokenToProgress(progress, cancelTokenFile);
detecdiv_check_cancel(progress, 'raw parser startup');

% list files and folder present in the propose directory
info='Listing files and folders....';
disp(info);
if numel(progress)
    progress.Message=info;
end
detecdiv_check_cancel(progress, info);

if inputIsFile
    list=dir(pathdir);
    pathdir = list(1).folder;
    if any(strcmpi(inputFileName, {'zarr.json', '.zattrs', '.zgroup'}))
        % A user may select the Zarr index file rather than the containing
        % folder. If it is nested inside a *.ome.zarr store, normalize to
        % the store root so buildomezarr sees the whole dataset.
        zroot = pathdir;
        probe = pathdir;
        for up = 1:10
            if endsWith(probe, '.ome.zarr', 'IgnoreCase', true) && localHasZarrRootMetadata(probe)
                zroot = probe;
                break;
            end
            parentDir = fileparts(probe);
            if isempty(parentDir) || strcmp(parentDir, probe)
                break;
            end
            probe = parentDir;
        end
        pathdir = zroot;
        inputIsFile = false;
        list=dir(pathdir);
    end
else
    if localHasZarrRootMetadata(pathdir)
        % If a nested Zarr group was selected inside a *.ome.zarr store,
        % normalize to the root folder.
        probe = pathdir;
        zroot = '';
        for up = 1:10
            if endsWith(probe, '.ome.zarr', 'IgnoreCase', true) && localHasZarrRootMetadata(probe)
                zroot = probe;
                break;
            end
            parentDir = fileparts(probe);
            if isempty(parentDir) || strcmp(parentDir, probe)
                break;
            end
            probe = parentDir;
        end
        if ~isempty(zroot)
            pathdir = zroot;
        end
    end
    list=dir(pathdir);
end
list = list(~startsWith({list.name}, '._')); % remove ._ files in mac os .

% --- detect NDTiff dataset(s) ---
ndtiffDirs = {};
if ~inputIsFile && exist(fullfile(pathdir,'NDTiff.index'), 'file')==2
    ndtiffDirs = {pathdir};
elseif ~inputIsFile
    subdirs = list([list.isdir]);
    subdirs = subdirs(~ismember({subdirs.name},{'.','..'}));
    for k = 1:numel(subdirs)
        p = fullfile(subdirs(k).folder, subdirs(k).name, 'NDTiff.index');
        if exist(p, 'file')==2
            ndtiffDirs{end+1} = fullfile(subdirs(k).folder, subdirs(k).name); %#ok<AGROW>
        end
    end
end

% --- detect OME-Zarr dataset(s) ---
omezarrDirs = {};
if ~inputIsFile && localHasZarrRootMetadata(pathdir) && ...
        (endsWith(pathdir, '.ome.zarr', 'IgnoreCase', true) || localLooksLikeOmeZarrRoot(pathdir, list))
    omezarrDirs = {pathdir};
elseif ~inputIsFile
    subdirs = list([list.isdir]);
    subdirs = subdirs(~ismember({subdirs.name},{'.','..'}));
    for k = 1:numel(subdirs)
        zp = fullfile(subdirs(k).folder, subdirs(k).name);
        if localHasZarrRootMetadata(zp) && ...
                (endsWith(zp, '.ome.zarr', 'IgnoreCase', true) || localLooksLikeOmeZarrRoot(zp, dir(zp)))
            omezarrDirs{end+1} = zp; %#ok<AGROW>
        end
    end
end

% --- detect time series stored as one stack file per timepoint ---
stkFiles = [];
if inputIsFile
    [~, ~, selectedExt] = fileparts(inputFileName);
    if strcmpi(selectedExt, '.stk')
        stkFiles = list;
    end
else
    stkFiles = list(~[list.isdir]);
    if ~isempty(stkFiles)
        [~, ~, exts] = cellfun(@fileparts, {stkFiles.name}, 'UniformOutput', false);
        stkFiles = stkFiles(strcmpi(exts, '.stk'));
    end
end

% If user selected a subfolder inside an NDTiff dataset, check parent
if isempty(ndtiffDirs) && ~inputIsFile
    [parentDir, ~, ~] = fileparts(pathdir);
    if ~isempty(parentDir) && exist(fullfile(parentDir,'NDTiff.index'), 'file')==2
        ndtiffDirs = {parentDir};
    end
end

% if there are directories avaialable, ignore files in the folder and
% consider directories as distinct positions
% unless there is .mat file corresponding to a phyloCell project

if numel(list)==0
    disp('this directory is empty ! Quitting !')
    return;
end

pix=[list.isdir];
phyloproj=[];

if ~isempty(ndtiffDirs)
    disp('NDTiff dataset(s) detected');
    typ='ndtiff';
    info='Processing NDTiff dataset(s)...';
elseif ~isempty(omezarrDirs)
    disp('OME-Zarr dataset(s) detected');
    typ='omezarr';
    info='Processing OME-Zarr dataset(s)...';
elseif ~isempty(stkFiles)
    disp('STK stack time series detected');
    typ='stkseries';
    info='Processing STK stack time series...';
elseif ~inputIsFile && sum(pix)>2 % there are folders available (. and .. are not real folders)
    % check if there is a phyloCell project
    phyloproj=list((contains({list.name},{'-project.mat'})) & (~contains({list.name},{'BK-project.mat'})) &  (~contains({list.name},{'-project.mat.bk'})));
    
    if numel( phyloproj ) % phylocell project was found
        disp('This folder contains a phylocell project');
        typ='phylocell';
        info='Processing phylocell project...';
    else
        disp('This folder contains one or several folders, which will be processed as separate positions');
        typ='folders';
        output.posinfolder=1;
    end
else % only files available, or a single image file was selected
    disp('This folder contains one or several files but no folders');
    plist= list([list.isdir]==0);
    plist=plist(contains({plist.name},{'.tif','.jpg','.png'})); % takes all image files
    
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
detecdiv_check_cancel(progress, info);


switch typ
    case 'phylocell'  % this is a phyloCell project
        detecdiv_check_cancel(progress, 'raw parser phylocell');
        
        output.comments=['The folder contains a phylocell project' char(10)];
        output= buildphylocell(phyloproj,output,progress);
        
    case 'folders' % process each folder as independent positions (incldues micromanager)
        detecdiv_check_cancel(progress, 'raw parser folders');
        
        output.comments=['The folder(s) contains (a) series of individual images' char(10)];
        output = buildfolders(list,output,progress);
        
    case 'multifiles' % contains a list of files, potentially with multiple poistions
        detecdiv_check_cancel(progress, 'raw parser multifiles');
        output.comments=['The folder contains (a) series of individual images with multiple positions' char(10)];
        output = buildmultifiles(list,output,progress);
        
    case 'multitif'  % check if it a list of files or a collection of mutitiff files (positions)
        detecdiv_check_cancel(progress, 'raw parser multitiff');
        
        output.comments=['The folder contains (a) series of multi-tiff images' char(10)];
        output=buildmultitif(list,output,progress);
        
    case 'ndtiff'
        detecdiv_check_cancel(progress, 'raw parser ndtiff');
        output.comments=['The folder contains one or more NDTiff datasets' char(10)];
        output=buildndtiff(ndtiffDirs,output,progress);

    case 'omezarr'
        detecdiv_check_cancel(progress, 'raw parser omezarr');
        output.comments=['The folder contains one or more OME-Zarr datasets' char(10)];
        output=buildomezarr(omezarrDirs,output,progress);

    case 'stkseries'
        detecdiv_check_cancel(progress, 'raw parser stkseries');
        output.comments=['The folder contains a time series of stack files' char(10)];
        output=buildstkseries(stkFiles,output,progress);
end

output.datatype=typ;
detecdiv_check_cancel(progress, 'raw parser finished');

end

function progress = attachCancelTokenToProgress(progress, cancelTokenFile)
if isempty(cancelTokenFile)
    return;
end
if isempty(progress)
    progress = struct('CancelTokenFile', cancelTokenFile);
elseif isstruct(progress)
    progress.CancelTokenFile = cancelTokenFile;
end
end

function tf = localHasZarrRootMetadata(pathstr)
tf = exist(fullfile(pathstr,'zarr.json'), 'file') == 2 || ...
    (exist(fullfile(pathstr,'.zattrs'), 'file') == 2 && exist(fullfile(pathstr,'.zgroup'), 'file') == 2);
end









