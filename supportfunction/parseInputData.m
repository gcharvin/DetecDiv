function output=parseInputData(pathdir)
% this function is used to parse input file or directory when importing
% data

output=[];
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
output.pos.channelfilter={'channel'};
output.pos.stackfilter={'_z'};
output.pos.channelname={};

typ=[];

% check if stringrepresents a valid file or folder


switch exist(pathdir)
    case 7 % is a dir
        
    otherwise
        disp('this directory does not exist ! Quitting !')
        return;
end


% list files and folder present in the propose directory

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
    else
        disp('This folder contains one or several folders, which will be processed as separate positions');
        typ='folders';
    end
else % only files available
    disp('This folder contains one or several files but no folders');
    
    
    plist= list([list.isdir]==0);
    plist=plist(contains({plist.name},{'.tif','.jpg'})); % takes all image files
    
    if numel(plist)
        disp('This folder contains image files');
    else
        disp('This folder does not contain image files...Quitting!');
        return;
    end
    
    
    plist=plist(contains({plist.name},{'.tif'})); % takes all image files
    
     
    if numel(plist)
        im=imfinfo(fullfile(plist(1).folder,plist(1).name));
        
        if numel(im)>1  % multi tif file
            disp('This folder contains multifiles files, which will be processed as separate positions');
           typ='multitif';
        end
    end
    
    if ~strcmp(typ,'multitif') % if list single tif/jpg file, then use the build folder method with one single folder
        typ='folders';
        
        list=dir(fullfile(pathdir,'..'));
        
        for i=1:numel(list)
            if strfind(pathdir, list(i).name)
                list=list(i);
                break
            end
        end
        
    end

end

switch typ
    case 'phylocell'  % this is a phyloCell project
        
        output= buildphylocell(phyloproj,output);

    case 'folders' % process each folder as independent positions (incldues micromanager)
        
        output = buildfolders(list,output);
        
    case 'multitif'  % check if it a list of files or a collection of mutitiff files (positions)
        
         output=buildmultitif(list,output);
end


function output=buildmultitif(filelist,outputin)
% build list offiles and parse channels based on a multif files 

output=outputin;

  filelist= filelist([filelist.isdir]==0);
  filelist=filelist(contains({filelist.name},{'.tif','.jpg'})); % takes all image files
  
  res=[];
  
  foldername=filelist(1).folder;
  
  cc=1;
  for i=1:numel(filelist)
   if cc~=1
        output.pos(cc)=output.pos(1);
   end
    output.pos(cc).name=filelist(i).name;
    cc=cc+1;
  end   
    
  cc=1;
 for i=1:numel(filelist)
     [pth fle ext]=fileparts(filelist(i).name);
     
    tmp=regexp(fle, '\d+$','match');
    
    if numel(tmp)==0 % there is no trailing number
        break;
    end
    
    res(cc)= str2double(tmp{1});
    cc=cc+1;
end

if numel(tmp)>0 %positions are terminated by a numer, so sort them
    [sortedres ix]=sort(res);
    output.pos=output.pos(ix);
end

cc=1;
  for i=1:numel(output.pos) % loop on positions
         
  im=imfinfo(fullfile(foldername,output.pos(i).name));
  nimages=numel(im);

  str=im(i).ImageDescription;
  
  nch=regexp(str,['(?<=channels=)\d+'],'match');
  
   if numel(nch)==0 % channel parsing failed, will consider only one channel 
       nch=1;
   else
  nch=str2double(nch{1});
   end
   
  nframes=regexp(str,['(?<=frames=)\d+'],'match');
  if numel(nframes)
       nframes=str2double(nframes{1});
  else
       nframes=nimages./nch;
  end
  
 interval=regexp(str,['(?<=finterval=)\d+'],'match');
  if numel(interval)
       interval=str2double(interval{1});
  else
       interval=nimages./nch;
  end
  
  
%   framelist={};
%   for j=1:nch
%       pix={j:nch:nimages};
%      framelist=[framelist pix];
%   end
  
sut=struct('name',output.pos(cc).name);

   output.pos(cc).channels=nch;
    output.pos(cc).frames=nframes;
    
    output.pos(cc).filelist={sut};
    output.pos(cc).pathlist={foldername};
    output.pos(cc).unfilteredpathlist={foldername};
    
    output.pos(cc).unfilteredfilelist={sut};
    
    output.pos(cc).binning=ones(1,nch);
    output.pos(cc).interval=interval;
    output.pos(cc).name= ['pos' num2str(sortedres(cc))];
    
    for j=1:nch
    output.pos(cc).channelname{j}=['ch' num2str(j)];
    end
    
    cc=cc+1;
  
  end
  



function output=buildfolders(dirlist,outputin)
% build list of files and parse channels and stacks, takiing each folder as
% an individual position

output=outputin;

selecteddir=[];

%dirlist
cc=1;

for i=1:numel(dirlist)
    
    if dirlist(i).isdir==0
        continue
    end
    
    if strcmp(dirlist(i).name,'.')
        continue
    end
    if strcmp(dirlist(i).name,'..')
        continue
    end
    
    selecteddir(cc)=i;
    
    if cc~=1
        output.pos(cc)=output.pos(1);
    end
    
    output.pos(cc).name=dirlist(i).name;
    
    cc=cc+1;
end

cc=1;

res=[];
for i=selecteddir
    tmp=regexp(dirlist(i).name, '\d+$','match');
    
    if numel(tmp)==0 % there is no trailing number
        break;
    end
    
    res(cc)= str2double(tmp{1});
    cc=cc+1;
end

if numel(tmp)>0 %positions are terminated by a numer, so sort them
    [cc ix]=sort(res);
    output.pos=output.pos(ix);
end

realfolders=cellfun(@(x) fullfile(dirlist(1).folder ,x),{output.pos.name},'UniformOutput',false); % fullfile folder name

for i=1:numel(output.pos) % extract channels from string names, treat different stackes as different channels
    
    % list all files in folder
    tmp=realfolders{i};
    
    filelist=dir(realfolders{i});
    
    rescha={};
    
    % identfy all channels according to channelfilter string
    
    for j=1:numel(filelist)
        
        
        if filelist(j).isdir==1
            continue
        end
        
        [pth fle ext]=fileparts(filelist(j).name);
        
        if ~strcmp(ext,'.tif') & ~strcmp(ext,'.jpg') % exclude non image files
            continue
        end
        
        % now parse to retrieve channels according to filters
        strname=filelist(j).name;
        str=output.pos(i).channelfilter{:};
        nstr=regexp(strname,['(?<=' str ')\d+'],'match');
        rescha=[rescha nstr];
        
    end
    
    rescha=unique(rescha); % number of toal channels
    
    resstack={};
    
    if numel(rescha)==0 % no channel was identifies
        rescha={''};
        disp('We could not identify any image with the requested channel filter');
        disp('Hence we will consider that ther is only one channel');
    end
    
    for k=1:numel(rescha) % loop on all channels to identify stacks for each channel
        
        resstack{k}={};
        
        for j=1:numel(filelist)
            
            if filelist(j).isdir==1
                continue
            end
            
            [pth fle ext]=fileparts(filelist(j).name);
            
            if ~strcmp(ext,'.tif') & ~strcmp(ext,'.jpg') % exclude non image files
                continue
            end
            
            % exclude files that do not contain the channel
            if ~strcmp(rescha{k},'') % if no channel was found, don't go through this, and take all possible files
                if ~contains(fle,[output.pos(i).channelfilter{:} rescha{k}])
                    continue
                end
            end
            
            % now parse to retrieve channels according to filters
            strname=filelist(j).name;
            str=output.pos(i).stackfilter{:};
            nstr=regexp(strname,['(?<=' str ')\d+'],'match');
            resstack{k}= [resstack{k} nstr];
        end
        
        resstack{k}=unique(resstack{k});
        
        if numel(resstack{k})==0
            resstack{k}={''};
        end
    end
    
  %   numel( rescha{1})
  %     resstack
    
    
    cc=1;
    
    filelist= filelist([filelist.isdir]==0);
    filelist=filelist(contains({filelist.name},{'.tif','.jpg'})); % takes all image files
    
    interval=[];
    
    for k=1:numel(rescha)
        for st=1:numel(resstack{k})
            stack=true;
            chan=true;
            %   di=
            tmpfilelist=filelist;
            
            %    tmpfilelist= tmpfilelist([tmpfilelist.isdir]==0);
            %     tmpfilelist=tmpfilelist(contains({tmpfilelist.name},{'.tif','.jpg'})); % takes all image files
            
            if strcmp(rescha{k},'') % no channels were detected, so take all the files
           
            else
                % test=contains({filelist.name},{'.tif'});
                chan= contains({tmpfilelist.name},[output.pos(i).channelfilter{:} rescha{k}]);
                tmpfilelist=tmpfilelist(chan);
            end
            
            
            if strcmp(resstack{k},'') % no stacks
             
            else
                stack= contains({tmpfilelist.name},[output.pos(i).stackfilter{:} resstack{k}{st}]);
                tmpfilelist=tmpfilelist(stack);
            end
            
            tmp=imfinfo(fullfile(realfolders{i},tmpfilelist(1).name));
            
            tmpstr=resstack{k};
            tmpstr=tmpstr{st};
            
            output.pos(i).frames=[output.pos(i).frames numel(tmpfilelist)];
            output.pos(i).filelist=[output.pos(i).filelist tmpfilelist];
            output.pos(i).pathlist=[ output.pos(i).pathlist realfolders{i}];
            
            output.pos(i).binning=[output.pos(i).binning tmp.Width] ;
            
            output.pos(i).interval=[output.pos(i).interval numel(tmpfilelist)];
            
            output.pos(i).channelname{cc}=['ch' rescha{k} '-st' tmpstr];
            cc=cc+1;
            
        end
    end
    
    output.pos(i).unfilteredpathlist= realfolders{i};
    output.pos(i).unfilteredfilelist=filelist;
    
    output.pos(i).binning=max(output.pos(i).binning)./output.pos(i).binning;
    output.pos(i).interval=round(max(output.pos(i).interval)./output.pos(i).interval);
    output.pos(i).channels=numel( output.pos(i).filelist);
    
end




function output=buildphylocell(phyloproj,outputin)

output=outputin;
load(fullfile(phyloproj.folder, phyloproj.name)); % load timeLapse variable

if exist('timeLapse','var')
    disp('File corresponds to a valid  timeLapse phyloCell project');
else
    disp('This is not a valid file ! Quitting....');
    return;
end

if isfield(timeLapse,'position')
    disp(['There are ' num2str(numel(timeLapse.position.list)) ' positions available in this timeLapse project']);
    npos=1:numel(timeLapse.position.list);
else
    disp('There are no positions available in this timeLapse project; Quitting...')
    return;
end

pathname={};
binning=[];

%   nid=n;
cc=1;
for i=npos
    strpos=fullfile(phyloproj.folder,[timeLapse.filename '-pos' num2str(i)]);
    
    filename={};
    frames=[];
    pathname={};
    binning=[];
    interval=[];
    channelname={};
    
    for j=1:numel(timeLapse.list) % sources files for each channel
        pathname{j}= fullfile(strpos,[timeLapse.filename '-pos' num2str(i) '-ch' num2str(j) '-' timeLapse.list(j).ID]);
        binning(j)=timeLapse.list(j).binning;
        
        interval(j)=timeLapse.interval;
        list=dir([pathname{j} '/*.jpg']);
        list=[list dir([pathname{j} '/*.tif'])];
        
        %tmp= [list.name'];
        filename{j}=list;
        
        channelname{j}=['ch' num2str(j) '-'  timeLapse.list(j).ID];
    end
    
    frames=numel(list);
    
    %    fi={''};
    %    fi=repmat(fi,[numel(pathname(i,:)) 1]);
    
    %tmpfov(i).setpathlist(pathname(i,:),nid(i),fi);
    
    %toc;
    
    % obj.fov(n+1)=fov(n+1,''); % add fov to exisiting datasets
    % THIS IS VERY SLOW BECAUSE THE DIR FUNCTION IS VERY SLOW ;
    % SHOULD REPLACE BY FILE REAL NAME IF IT IS KNOWN !!!
    
    
    % tmpfov(i).display.binning=binning(i,:);
    %tmpfov(i).channel=chanames;
    
    %  n=n+1;
    
    output.pos(cc).channels=[];
    output.pos(cc).frames=frames;
    output.pos(cc).filelist=filename;
    output.pos(cc).pathlist=pathname;
    output.pos(cc).unfilteredpathlist=pathname;
    output.pos(cc).unfilteredfilelist=filename;
    output.pos(cc).binning=binning;
    output.pos(cc).interval=interval;
    output.pos(cc).name= ['pos' num2str(i)];
    output.pos(cc).channelfilter={'ch'};
    output.pos(cc).stackfilter={''};
    output.pos(cc).channelname=channelname;
    
    cc=cc+1;
    
end



