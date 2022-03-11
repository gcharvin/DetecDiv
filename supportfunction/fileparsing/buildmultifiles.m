function output=buildmultifiles(dirlist,outputin,progress)
% build list of files and parse channels and stacks, takiing each folder as
% an individual position

output=outputin;

selecteddir=[];

%dirlist
cc=1;

filelist=dirlist;

%filter out folders and take only image files.
filelist= filelist([filelist.isdir]==0);
filelist=filelist(contains({filelist.name},{'.tif','.jpg'})); % takes all image files

% filter files based on position filter
posfilter=output.pos(1).positionfilter;

npos={}; % if numel(npos=0), there is one single poistion found

posfilter2={};

for i=1:numel(posfilter)
    
    if endsWith(posfilter{i},'$') % numerated positions
        
        tmp=regexp({filelist.name}, [posfilter{i}(1:end-1) '\d+'],'match');
        tmp=cellfun(@testx,tmp,'UniformOutput',false) ;
        tmp=unique(tmp);  tmp=tmp(cellfun(@(x) ~isempty(x),tmp));
        if numel(tmp)
            npos=[npos tmp];
            posfilter2=[posfilter2 posfilter{i}];
        end
        
        
    else % manually defined positions
        
        tmp=regexp({filelist.name}, posfilter{i},'match');
        tmp=cellfun(@testx,tmp,'UniformOutput',false) ;
        tmp=unique(tmp);  tmp=tmp(cellfun(@(x) ~isempty(x),tmp));
        if numel(tmp)
            npos=[npos tmp];
            posfilter2=[posfilter2 posfilter{i}];
        end
        
    end
end

% if positions are numerated, then reorder positions
% nposorder=1:numel(npos);
if numel(npos)
    
    npostmp=regexp(npos, '\d+$','match');
    
    npostmp=cellfun(@(x) str2num(x{1}),npostmp,'UniformOutput',false) ;
    
    npostmp=cell2mat(npostmp);
    [~,ix]=sort(npostmp);
    npos=npos(ix);
end

if numel(npos)==0 % there is ony one position
    npos={''};
    posfilter2={};
    disp('We could not identify any image with the requested position filter');
    disp('Hence we will consider that there is only one position');
end

% list of channels

chafilter= output.pos(1).channelfilter;

chafilter2={};

ncha=[];
for i=1:numel(chafilter)
    
    if endsWith(chafilter{i},'$') % numerated positions
        
        tmp=regexp({filelist.name}, [chafilter{i}(1:end-1) '\d+'],'match');
        tmp=cellfun(@testx,tmp,'UniformOutput',false) ;
        tmp=unique(tmp);  tmp=tmp(cellfun(@(x) ~isempty(x),tmp));
        if numel(tmp)
            ncha=[ncha tmp];
            chafilter2=[chafilter2 chafilter{i}];
        end
        
    else % manually defined positions
        
        tmp=regexp({filelist.name}, chafilter{i},'match');
        tmp=cellfun(@testx,tmp,'UniformOutput',false) ;
        tmp=unique(tmp);  tmp=tmp(cellfun(@(x) ~isempty(x),tmp));
        if numel(tmp)
            ncha=[ncha tmp];
            chafilter2=[chafilter2 chafilter{i}];
        end
        
    end
end

if numel(ncha)==0 % there is ony one channel
    ncha={''};
    disp('We could not identify any image with the requested channel filter');
    disp('Hence we will consider that there is only one channel');
    chafilter2={};
end


% list of stacks

stackfilter= output.pos(1).stackfilter;

stackfilter2={};

nsta=[];

for i=1:numel( stackfilter)
    
    if endsWith(stackfilter{i},'$') % numerated positions
        
        tmp=regexp({filelist.name}, [stackfilter{i}(1:end-1) '\d+'],'match');
        tmp=cellfun(@testx,tmp,'UniformOutput',false) ;
        tmp=unique(tmp); tmp=tmp(cellfun(@(x) ~isempty(x),tmp));
        if numel(tmp)
            nsta=[nsta tmp];
            stackfilter2=[ stackfilter2  stackfilter{i}];
        end
        
    else % manually defined positions
        %    aa=stackfilter{i}
        
        tmp=regexp({filelist.name}, stackfilter{i},'match');
        tmp=cellfun(@testx,tmp,'UniformOutput',false) ;
        tmp=unique(tmp); tmp=tmp(cellfun(@(x) ~isempty(x),tmp));
        if numel(tmp)
            nsta=[nsta tmp];
            stackfilter2=[ stackfilter2  stackfilter{i}];
        end
        
    end
end

if numel(nsta)==0 % there is only one stack
    nsta={''};
    disp('We could not identify any image with the requested stack filter');
    disp('Hence we will consider that there is only one stack');
    stackfilter2={};
end


%npos,ncha,nsta

% build list of positions



for i=1:numel(npos)
    
    if i~=1
        output.pos(i)=output.pos(1);
        output.pos(i).name=npos{i};
        output.pos(i).frames=[];
        output.pos(i).filelist={};
        output.pos(i).binning=[];
        output.pos(i).interval=[];
        output.pos(i).pathlist={};
        output.pos(i).channelname={};
    end
    
    
    cc=1;
    
    info=['Processing position: ' num2str(i) '/' num2str(numel(npos))];
    disp(info);
    
    if numel(progress)
        progress.Message=info;
        progress.Value=min(1,0.67+0.33*(i-1)./numel(npos));
    end
    
    % npos
    ispos=contains({filelist.name},npos(i));
    
    % loop on channels
    
    for j=1:numel(ncha)
        
        ischa=contains({filelist.name},ncha(j));
        
        for k=1:numel(nsta)
            %  i,j,k
            isstack=contains({filelist.name},nsta(k));
            
            files=filelist(ispos & ischa & isstack);
            
            if numel(files) % there are files to gather here
                
                output.pos(i).frames=[output.pos(i).frames numel(files)];
                
                [~, idx]=natsortfiles({files.name});
                files=files(idx);
                
                output.pos(i).filelist=[output.pos(i).filelist files];
                
                output.pos(i).pathlist=[ output.pos(i).pathlist files(1).folder];
                
                tmp=imfinfo(fullfile(files(1).folder,files(1).name));
                
                output.pos(i).binning=[output.pos(i).binning tmp.Width] ;
                output.pos(i).interval=[output.pos(i).interval numel(files)];
                output.pos(i).channelname{cc}=[ncha{j} '' nsta{k}];
                
                cc=cc+1;
            end
            
        end
        
    end
    
    
    if numel(npos{i})~=0
        output.pos(i).name=npos{i};
    else
        output.pos(i).name='Pos1';
    end
    
    
    
    output.pos(i).channels=numel(output.pos(i).binning);
    output.pos(i).binning= output.pos(i).binning./ output.pos(i).binning(1);
    output.pos(i).interval=output.pos(i).interval(1)./output.pos(i).interval;
    
    
    output.pos(i).positionfilter2=posfilter2; % output filter
    output.pos(i).channelfilter2=chafilter2;
    output.pos(i).stackfilter2=stackfilter2;
    
    %    output.pos(i).unfilteredpathlist= realfolders{i};
    %   output.pos(i).unfilteredfilelist=filelist;
end

function out=testx(x)

if numel(x)==0
    out='';
else
    out=x{1};
end

