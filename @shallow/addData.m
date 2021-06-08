function addData(obj,inputproject)

name=-1;

if nargin>1
    name=1;
else
    
    prompt='Data type: list of Images-->0;  PhyloCell project-->1;  4D Tiff files-->2; MicroManager folder -->3; (Default: 0)';
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

switch answer
    case {0,1,2,3}
    otherwise
        disp('Invalid data type, quit !');
        return;
end

switch answer
    case 0
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
        filtlist={};
        
        tmppath=pwd; 
        for i=1:ncha% loop on channels to get directory location
            disp(['Input data for channel : ' num2str(i) ' / ' num2str(ncha) ' :']);  
            path = uigetdir(tmppath,['Directory with all images for channel:' num2str(i)]);
            
            if isequal(path,0)
                disp('User selected Cancel')
                return;
            else
                pathlist{i}=path;
                tmppath=path;
            end
            
            prompt=['Use filter to subselect images in folder as comma separated test: filter1,filter2, etc. for the current channel; Default: none'];
            filt= input(prompt,'s');
            
            if numel(filt)==0
                filt='';
            end
            tmp = regexp(filt,'([^ ,:]*)','tokens');
            tmp=cat(2,tmp{:});
            filtlist(i)={tmp};
        end
        
        n=numel(obj.fov);
        
        if n==1
            if numel(obj.fov.srcpath{1})==0 % no fov present
                n=0;
                obj.fov=fov;
            end
        end
        
        obj.fov(n+1)=fov; % add fov to exisiting datasets
        obj.fov(n+1).setpathlist(pathlist,n+1,filtlist);
        obj.fov(n+1).display.binning=binning;
        
        %     mov.path=[outputPath '/' ofle '-pos' num2str(1)];
        %     mov.id=['pos' num2str(1)];
        %     mov.projectpath= [outputPath '/' outputFilename];
        %
        %     mkdir([outputPath '/' ofle '-pos' num2str(1)]); % directory to store mat files
        %
        %     eval(['save '  outputPath '/' outputFilename    ' mov']);
        
        %
        
    case 1 % phyloCell project
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
            fi={''};
            fi=repmat(fi,[numel(pathname(i,:)) 1]);
            
            tmpfov(i).setpathlist(pathname(i,:),nid(i),fi);
            
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
        fprintf('\n');
        
    case 2 % 4D Tiff / not implemented
        
        
    case 3 % micromanager project
        
        if nargin > 1
            filename=inputproject;
            [path fle ext]=fileparts(filename);
            path=[path '/'];
        else
            
            path= uigetdir('Select a Micromanager project folder',pwd);
            if isequal(path,0)
                disp('User selected Cancel')
                return;
            else
                disp(['User selected ', fullfile(path)]);
            end
        end
        
        list=dir(path);
        list=struct2cell(list);
        list=list(1,:);
        %folders=arrayfun(@isfolder,list);
 
        folders=arrayfun(@(x) fullfile(path , x{:}),list(1,:),'UniformOutput',false);
        realfolders=arrayfun(@(x) numel(strfind(x{:},'.'))==0,folders,'UniformOutput',false);
        realfolders=folders(cell2mat(realfolders));
        realfolders(2,:)=num2cell(1:numel(realfolders));
        realfolders=realfolders([2 1],:);
        
        tab=cell2table(realfolders','VariableNames',{'ID' 'Folders available'});
        disp(tab)
        
        if size(realfolders,2)==0
            disp('Error : there is no folder within the selected folder !')
            return;
        end
        
        prompt=['Please enter the positions to import (using Matlab syntax); Default: 1:' num2str(size(realfolders,2)) ' '];
        npos= input(prompt,'s');
        if numel(npos)==0
            npos=1:numel(timeLapse.position.list);
        else
            npos=eval(npos);
        end
        
        %      di=struct2table(list);
        %      disp(di);
        %      clist=struct2cell(list);
        %                 clist=clist(1,:);
        %                 occ=regexp(clist,filtlist{i});
        %                 occ=arrayfun(@(x) numel(x{:}),occ)==1;
        %                 list=list(occ);
        
        disp(['OK, we will import folder IDs: ' num2str(npos)]);
        
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
        
        disp(['Now we will set the channels/stacks to be imported !']);
        
        prompt=['How many channels?  Default: 1'];
        ncha= input(prompt);
        
        if numel(ncha)==0
            ncha=1;
        end
        
    %    filt={};
        
        cc=1;
        outputfilt={};
        binning=[];
        binarray=[];
        
        for j=1:ncha
            
        prompt=['Binning for channel ' num2str(j) '?  Default: 1'];
        binning= input(prompt);
        
        if numel(binning)==0
            binning=1;
        end
        
            prompt=['Filter string for channel ' num2str(j) '  Default: l00' num2str(j-1)];
            chastr= input(prompt,'s');
            
            if numel(chastr)==0
                chastr=['l00' num2str(j-1)];
            end
            
         %   filt(j)={chastr};
            
            prompt=['How many stacks for channel ' num2str(j) '?  Default: 1'];
            nst= input(prompt);
            
            if numel(nst)==0
                nst=1;
            end
            
            tmpfilt={};
            for k=1:nst
                
              prompt=['Filter string for channel  ' num2str(j) ' , stack ' num2str(k) '; Default: z00' num2str(k-1)];
            nststr= input(prompt,'s');
            
            if numel(nststr)==0
                nststr=['z00' num2str(k-1)];
            end
                
            tmpfilt(k)={nststr};
            
            outputfilt{cc}={{chastr},{nststr}};
            binarray(cc)=binning;
            cc=cc+1;
            end
           %  filt(j,2)={tmpfilt};
        end
   
disp('These filters will applied to all selected positions/folders !');

pathname={};
binning=[];

filt={};

cd=1;
for i=npos
  
    for j=1:cc-1
        pathname{i,j}= realfolders{2,i};
        binning(i,j)=binarray(j);
        filt{i,j}=outputfilt{j};
    end
    
    nid(cd)=n+cd;
    cd=cd+1;
end

for i=npos % loop on all the fov / positions / folders to be created 
  
    fprintf('.');
    tmpfov(i)=fov;
    tmpfov(i).setpathlist(pathname(i,:),nid(i),filt(i,:));
    
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
fprintf('\n');

end


% prompt = {'Enter matrix size:','Enter colormap name:'};
% dlg_title = 'Input';
% num_lines = 1;
% defaultans = {'20','hsv'};
% answer = inputdlg(prompt,dlg_title,num_lines,defaultans);

