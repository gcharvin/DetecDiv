function addData(obj)


prompt = {'Data type: 0-->list of Images; 1--> PhyloCell project :'; 'Comment'};
dlg_title = 'Input project type';
num_lines = 1;
defaultans = {'0',''};
answer = inputdlg(prompt,dlg_title,num_lines,defaultans);

comments=answer{2};

if numel(answer)==0
    disp('User canceled');
    return;
end



if str2num(answer{1})~=0 & str2num(answer{1})~=1
    disp('Invalid data type, quit !');
    return;
end

if str2num(answer{1})==0 % list of images
    
    prompt = {'Number of channels:','Binning for each channel; ex: [1 2]:'};
    dlg_title = 'Input number of channels';
    num_lines = 1;
    defaultans = {'2','[1 2]'};
    answer = inputdlg(prompt,dlg_title,num_lines,defaultans);
    pathlist={};
    
    for i=1:str2num(answer{1}) % loop on channels to get directory location
        path = uigetdir(userpath,['Directory with all images for channel:' num2str(i)]);
        
        if isequal(path,0)
            disp('User selected Cancel')
            return;
        else
             pathlist{i}=path;
        end
    end
    
    % now create fov objects 
    if numel(obj.fov.srcpath{1})==0 % no fov present
    obj.fov=fov(pathlist,1,comments);
    obj.fov.display.binning=answer{2}; 
    else
    obj.fov(end+1)=fov(pathlist,numel(obj.fov)+1,comments); % add fov to exisiting datasets
    obj.fov(end+1).display.binning=answer{2}; 
    end

%     mov.path=[outputPath '/' ofle '-pos' num2str(1)];
%     mov.id=['pos' num2str(1)];
%     mov.projectpath= [outputPath '/' outputFilename];
% 
%     mkdir([outputPath '/' ofle '-pos' num2str(1)]); % directory to store mat files
% 
%     eval(['save '  outputPath '/' outputFilename    ' mov']);

%

end

if answer{1}==1 % phyloCell project
    
end

% prompt = {'Enter matrix size:','Enter colormap name:'};
% dlg_title = 'Input';
% num_lines = 1;
% defaultans = {'20','hsv'};
% answer = inputdlg(prompt,dlg_title,num_lines,defaultans);



end