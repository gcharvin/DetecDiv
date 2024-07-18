function output=buildmultitif(filelist,outputin,progress)
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
    
   % tmp=regexp(fle, '\d+$','match');
    tmp = regexp(fle, '(\d+)(\.ome)?$', 'tokens');

    if numel(tmp)==0 % there is no trailing number
        break;
    end
    
    %res(cc)= str2double(tmp{1});
    res(cc) = str2double(tmp{1}{1});
    cc=cc+1;
end



if numel(tmp)>0 %positions are terminated by a numer, so sort them
    [sortedres ix]=sort(res);
    output.pos=output.pos(ix);
end

cc=1;
output.comments=[output.comments num2str(numel(output.pos)) ' positions were identifed' char(10)];

for i=1:numel(output.pos) % loop on positions
    
    info=['Processing position: ' num2str(i) '/' num2str(numel(output.pos))];
    disp(info);
    if numel(progress)
        progress.Message=info;
        progress.Value=min(1,0.67+0.33*(i-1));
    end
    
    im=imfinfo(fullfile(foldername,output.pos(i).name));
    nimages=numel(im);
    
    if isfield(im,'ImageDescription')
        str=im(1).ImageDescription;
        
        if ~isempty(str)
        nch=[];
        nframes=[];
        
        if contains(str,'ImageJ')
            nch=regexp(str,['(?<=channels=)\d+'],'match');
            nframes=regexp(str,['(?<=frames=)\d+'],'match');
        end
        
        if contains(str,'OME')
            nch=regexp(str,['(?<=SizeC=")\d+'],'match');
            nframes=regexp(str,['(?<=SizeT=")\d+'],'match');
        end
        end
    else % not fiji or OME, probably matlab based
        nch=[];
        nframes=[];
    end
   
   % to be improved

    % if numel(nch)==0 % parsing using ImageDescription failed, trying metadata.txt
    % 
    %         if endsWith(fle, '.ome')
    %             fle2 = extractBefore(fle, strlength(fle) - 3);
    %         else
    %             fle2 = fle;
    %         end
    % 
    % 
    %         % Construct the metadata file path
    %         metadataFilePath = fullfile(pth, [fle2 'metadata.txt'])
    % 
    %         % Read the metadata file
    %         if exist(metadataFilePath, 'file')
    %             metadata = fileread(metadataFilePath);
    %             metadata = jsondecode(metadata);
    % 
    %             % Extract channel information from metadata
    %             if isfield(metadata.Summary, 'IntendedDimensions')
    %                 nch = metadata.Summary.IntendedDimensions.channel;
    %                 nframes = metadata.Summary.IntendedDimensions.time;
    %             else
    %                 nch = 1;
    %                 nframes = nimages;
    %             end
    %         else
    %             nch = 1;
    %             nframes = nimages;
    %         end
    % end
    
    if numel(nch)==0 % channel parsing failed, will consider only one channel
        nch=1;
    else
        nch=str2double(nch{1});
    end
    
    
    if numel(nframes)
        nframes=str2double(nframes{1});
    else
        nframes=nimages./nch;
    end
    
    %  interval=regexp(str,['(?<=finterval=)\d+'],'match');
    %   if numel(interval)
    %        interval=str2double(interval{1});
    %   else
    interval=ones(1,nch); % an array that represents the reletaive frequency of each channel
    %  end
    
    
    %   framelist={};
    %   for j=1:nch
    %       pix={j:nch:nimages};
    %      framelist=[framelist pix];
    %   end
    
    sut=struct('name',output.pos(cc).name);
    
    output.pos(cc).channels=nch;
    output.pos(cc).frames=nframes;
    
    
    %  for k=1:nch
    %   output.pos(cc).filelist=[ output.pos(cc).filelist sut];
    %   output.pos(cc).pathlist=[output.pos(cc).pathlist foldername];
    output.pos(cc).filelist={sut};
    output.pos(cc).pathlist={foldername};
    %  end
    
    output.pos(cc).unfilteredpathlist={foldername};
    
    output.pos(cc).unfilteredfilelist={sut};
    
    output.pos(cc).binning=ones(1,nch);
    output.pos(cc).interval=interval;
    output.pos(cc).name= ['pos' num2str(sortedres(cc))];
    output.pos(cc).channelfilter={''};
    output.pos(cc).stackfilter={''};
    
    for j=1:nch
        output.pos(cc).channelname{j}=['ch' num2str(j)];
    end
    
    cc=cc+1;
    
end