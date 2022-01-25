function output=buildfolders(dirlist,outputin,progress)
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
  %  i
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


realfolders=cellfun(@(x) fullfile(dirlist(1).folder ,x),{output.pos.name},'UniformOutput',false) ;
% fullfile folder name

for i=1:numel(output.pos) % extract channels from string names, treat different stackes as different channels
    
  
     info=['Processing position: ' num2str(i) '/' num2str(numel(output.pos))];
       disp(info);
 if numel(progress)
 progress.Message=info;
 progress.Value=min(1,0.67+0.33*(i-1)./numel(output.pos));
 end
 
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
        
        if numel(str)
        nstr=regexp(strname,['(?<=' str ')\d+'],'match');
        rescha=[rescha nstr];
        end
        
    end
    
    rescha=unique(rescha); % number of toal channels
    
    resstack={};
    
    if numel(rescha)==0 % no channel was identifies
        rescha={''};
        disp('We could not identify any image with the requested channel filter');
        disp('Hence we will consider that there is only one channel');
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
            if numel(str)
            nstr=regexp(strname,['(?<=' str ')\d+'],'match');
            resstack{k}= [resstack{k} nstr];
            end
        end
        
        resstack{k}=unique(resstack{k});
        
        if numel(resstack{k})==0
            resstack{k}={''};
        end
    end
    
  %   numel( rescha{1})
  %     resstack
    
    %rescha,resstack
    
    cc=1;
    
    filelist= filelist([filelist.isdir]==0);
    filelist=filelist(contains({filelist.name},{'.tif','.jpg'})); % takes all image files
    
    if numel(filelist)==0
        disp('There are no image in the folder!');
         output.comments='No image files available!';
        return
    end
    
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