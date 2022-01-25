


function output=buildphylocell(phyloproj,outputin,progress)

output=outputin;
load(fullfile(phyloproj.folder, phyloproj.name)); % load timeLapse variable

if exist('timeLapse','var')
    disp('File corresponds to a valid  timeLapse phyloCell project');
else
    disp('This is not a valid file ! Quitting....');
     output.comments='No image files available!';
    return;
end

if isfield(timeLapse,'position')
    disp(['There are ' num2str(numel(timeLapse.position.list)) ' positions available in this timeLapse project']);
    npos=1:numel(timeLapse.position.list);
else
    disp('There are no positions available in this timeLapse project; Quitting...')
     output.comments='No image files available!';
    return;
end

pathname={};
binning=[];

%   nid=n;
cc=1;
for i=npos
    
         info=['Processing position: ' num2str(i) '/' num2str(numel(npos))];
       disp(info);
 if numel(progress)
 progress.Message=info;
 progress.Value=min(1,0.67+0.33*(i-1));
 end
 
  %  strpos=fullfile(phyloproj.folder,[timeLapse.filename '-pos' num2str(i)]);
    
    strpos= fullfile(phyloproj.folder,timeLapse.pathList.position{i});
    
    filename={};
    frames=[];
    pathname={};
    binning=[];
    interval=[];
    channelname={};
    
    for j=1:numel(timeLapse.list) % sources files for each channel
        %pathname{j}= fullfile(strpos,[timeLapse.filename '-pos' num2str(i) '-ch' num2str(j) '-' timeLapse.list(j).ID]);
        
        pathname{j}= fullfile(phyloproj.folder,timeLapse.pathList.channels{i,j});
       
        
        if isfield(timeLapse.list,'binning')
        binning(j)=timeLapse.list(j).binning;
        else
        binning(j)=1;   
        end
        
        if isfield(timeLapse,'interval')
        interval(j)=timeLapse.interval;
        else
        interval(j)=1;    
        end
        
        list=dir([pathname{j} '/*.jpg']);
        list=[list dir([pathname{j} '/*.tif'])];
        
        %tmp= [list.name'];
        filename{j}=list;
        
        channelname{j}=['ch' num2str(j) '-'  timeLapse.list(j).ID];
    end
    
    frames=numel(list);
    
    lf=dir(strpos);
    lf= lf([lf.isdir]==0);
    lf=lf(contains({lf.name},{'.mat'})); % takes all mat files
    [~,idxdate] = sort([lf.datenum],'descend');% sort them by date 
    lf = lf(idxdate);
    
    for ll=1:numel(lf)
        
     %   zzz=lf(ll).name
        
        load(fullfile(lf(ll).folder,lf(ll).name));
        
        h=findobj('Name','phyloCell_mainGUI'); % in cas a figure is linked to the seg variable
        delete(h);
        
        if exist('segmentation','var')
            
             progress.Message=['Found segmentation variable : ' lf(ll).name];
             pause(0.2);
             
             disp(['Found segmentation variable : ' lf(ll).name]);
             
            if numel(segmentation.cells1)>=1 && segmentation.cells1(1,1).n~=0
            output.pos(cc).contours.cells1=segmentation.cells1;
            end
            
             if numel(segmentation.nucleus)>=1 && segmentation.nucleus(1,1).n~=0
            output.pos(cc).contours.nucleus=segmentation.nucleus;
             end
            
             break; % take only the most recent segmentation variable 
        end
    end
    

    
    output.pos(cc).channels=numel(pathname);
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
