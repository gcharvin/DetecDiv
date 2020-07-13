function addData(obj,inputproject)

name=-1;

if nargin>1
    name=1;
else
    
    prompt='Data type: 0-->list of Images; 1--> PhyloCell project; 2-> 4D Tiff files (Default: 0)';
    name= input(prompt);
    if numel(name)==0
        name=0;
    end
end


% prompt = {'Data type: 0-->list of Images; 1--> PhyloCell project :'; 'Comment'};
% dlg_title = 'Input project type';
% num_lines = 1;
% defaultans = {'0',''};
% answer = inputdlg(prompt,dlg_title,num_lines,defaultans);
%
% comments=answer{2};
%
% if numel(answer)==0
%     disp('User canceled');
%     return;
% end

answer=name;

if answer~=0 & answer~=1 & answer~=2
    disp('Invalid data type, quit !');
    return;
end

if answer==0 % list of images
    
    %     prompt = {'Number of channels:','Binning for each channel; ex: [1 2]:'};
    %     dlg_title = 'Input number of channels';
    %     num_lines = 1;
    %     defaultans = {'2','[1 2]'};
    %     answer = inputdlg(prompt,dlg_title,num_lines,defaultans);
    
    prompt='Number of channels (Default: 1)';
    ncha= input(prompt);
    if numel(ncha)==0
        ncha=1;
    end
    
    tmp=ones(1,ncha);
    
    prompt=['Binning for each channel in the format : channel1binning channel2binning etc ; Default: ' num2str(tmp) '; '];
    binning= input(prompt,'s');
    
    if numel(binning)==0
        binning=tmp;
    else
        binning=str2num(binning);
    end
    
    pathlist={};
    
    for i=1:ncha% loop on channels to get directory location
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
        obj.fov=fov(pathlist,1,'');
        obj.fov.display.binning=binning;
    else
        obj.fov(end+1)=fov(pathlist,numel(obj.fov)+1,''); % add fov to exisiting datasets
        obj.fov(end+1).display.binning=binning;
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

if answer==1 % phyloCell project
    
    if nargin > 1
        filename=inputproject;
        [path fle ext]=fileparts(filename);
        path=[path '/'];
    else
        
        [file,path] = uigetfile('*.mat','Select a phylocell/XG project',pwd);
        if isequal(file,0)
            disp('User selected Cancel')
            return;
        else
            disp(['User selected ', fullfile(path, file)]);
            filename=fullfile(path, file);
        end
    end
    
    load(filename) % load timeLapse variable
    
    if isfield(timeLapse,'position')
        disp(['There are ' num2str(numel(timeLapse.position.list)) ' positions available in this timeLapse project']);
        
        if nargin>1
            npos=1:numel(timeLapse.position.list);
            %npos=1;
        else
            prompt=['Please enter the positions to import (in Matlab syntax); Default: 1:' num2str(numel(timeLapse.position.list)) ' '];
            npos= input(prompt,'s');
            if numel(npos)==0
                npos=1:numel(timeLapse.position.list);
            else
                npos=eval(npos);
            end
        end
    else
        disp('There are no positions available in this timeLapse project; Quitting...')
        return;
    end
    
    % cc=1;
    
    %npos
    
    n=numel(obj.fov);
    
    if n==1
        if numel(obj.fov.srcpath{1})==0 % no fov present
            n=0;
        end
    end
    
    
    tmpfov=fov;
    
    pathname={};
    binning=[];
    
    nid=n;
    cc=1;
    for i=npos
        strpos=[path timeLapse.filename '-pos' num2str(i)]; % add / here if necessary
        
        for j=1:numel(timeLapse.list) % sources files for each channel
            pathname{i,j}= [strpos '/' timeLapse.filename '-pos' num2str(i) '-ch' num2str(j) '-' timeLapse.list(j).ID];
            binning(i,j)=timeLapse.list(j).binning;
        end
        
        nid(i)=n+cc;
        cc=cc+1;
    end
    
    
    parfor i=npos
        
        
        %         % now create fov objects
        %         if n==1
        %         if numel(obj.fov.srcpath{1})==0 % no fov present
        %         %    'new project'
        %           %  obj.fov=fov(pathname,1,'');
        %           %  obj.fov.display.binning=binning;
        %             n=0;
        %         end
        %         end
        
        fprintf('.');
        
        tmpfov(i)=fov;
        
        % tic;
        tmpfov(i).setpathlist(pathname(i,:),nid(i));
        %toc;
        
        % obj.fov(n+1)=fov(n+1,''); % add fov to exisiting datasets
        % THIS IS VERY SLOW BECAUSE THE DIR FUNCTION IS VERY SLOW ;
        % SHOULD REPLACE BY FILE REAL NAME IF IT IS KNOWN !!!
        
        
        tmpfov(i).display.binning=binning(i,:);
        
        %  n=n+1;
        %  cc=cc+1;
    end
    
    
    
    for i=npos
        obj.fov(n+1)=tmpfov(i);
        n=n+1;
    end
end
fprintf('\n');

% prompt = {'Enter matrix size:','Enter colormap name:'};
% dlg_title = 'Input';
% num_lines = 1;
% defaultans = {'20','hsv'};
% answer = inputdlg(prompt,dlg_title,num_lines,defaultans);



end