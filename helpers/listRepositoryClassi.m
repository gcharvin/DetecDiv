function list=listRepositoryClassi(option)
% this function lists the classi objects avaiable on the repository
% location
% if an optional string is provided, will return the index in the
% repository listing

list=[];
filename=fullfile(userpath, 'classifier_repository_path.txt');

if exist(filename)
    
    fileID=fopen(filename);
    C = textscan(fileID,'%s');
    fclose(fileID);
    
    repstr=C{1}{1}; % contains the path to the classi repository
    
    
    disp(['Found repository folder : ' repstr]);
    % now list all the classification variables available
else
    prompt='Local file with repository path does not exist; Create? y/n ;  Default (y): ';
    classitype= input(prompt,'s');
    if numel(classitype)==0
        classitype='y';
    end
    
    if strcmp(classitype,'y')
        disp('You will now enter the path where the repository is located;   Default: M:\matlab\shallow_classifier_repository' );
        prompt='Enter path:';
        classitype= input(prompt,'s');
        if numel(classitype)==0
            classitype=' M:\matlab\shallow_classifier_repository';
        end
        
        if numel(exist(classitype))==0
            disp('This path is not valid; Quitting ...');
            return;
        end
        
        writecell({classitype},filename);
        repstr=classitype;
        
    else
        disp('Quitting !');
    end
end

l=dir(repstr);


id=[];
idstr={};
cc=1;

history=table('Size',[1 6],'VariableTypes',{'uint8','string','cell','string','cell','uint16'},'VariableNames',{'Number','Classification name','Description','category','classes','# ROIs'});

for i=1:numel(l)
    
    if l(i).isdir~=1
        continue
    end
    
    if strcmp(l(i).name,'.') | strcmp(l(i).name,'..')
        continue
    end
    
    pth=fullfile(repstr,l(i).name,[l(i).name '_classification.mat']);
    if ~exist(pth)
        disp(['Found classification ' l(i).name ' but main classi file is missing!']);
        continue
    end
    
    if nargin==0
        classiObj=classiLoad(pth);
        
        if ~isa(classiObj,'classi')
            disp(['Found classification ' l(i).name ' but main file is not a regular @classi object!']);
            continue
        end
    end
    
    
    % id=[id cc];
    %  idstr(cc,1)={ i};
    %  idstr(cc,2)={ l(i).name};
    
    warning off all;
    history(cc,1)={cc};
    history(cc,2)={l(i).name};
    
    if nargin==0
       
        if numel(classiObj.description)>0
        history(cc,3)={classiObj.description{1}};
        end
        history(cc,4)={classiObj.category};
        history(cc,5)={cell2mat(classiObj.classes')};
        
        tmp=numel(classiObj.roi);
        if numel(classiObj.roi)==1 & numel(classiObj.roi.id)==0
            tmp=0;
        end
        
        history(cc,6)={tmp};
    end
    warning on all;
    
    cc=cc+1;
end

if cc==1
    disp('Coud not find any item in repository ! Quitting...');
    list=[];
    return;
end

if nargin==0
%    disp(history);
    list=history;
    return
end


ok=0;
for i=1:size(history,1)
    if ischar(option)
        if strcmp(option, history{i,2})
            disp('Found requested repository');
            ok=i;
            break;
        end
    end
    if isnumeric(option)
        if option==history{i,1}
             disp('Found requested repository');
            ok=i;
            break;
        end
    end
end

if ok>0
 list=fullfile(repstr,char(history{ok,2}),[char(history{ok,2}) '_classification.mat']);
else
          disp('Did not find requested repository');
end



