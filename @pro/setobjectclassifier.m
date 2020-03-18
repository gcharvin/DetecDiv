function setobjectclassifier(obj,str,opt)

% set the classifier for objects according to specific rules

% if 'str'==path, then load/save a classifier in a given path
% in this case opt=='save' : saves all existing training data in the given
% file; opt=='load' : load classifer from eisiting file; opt='append' : add
% movi training data to the existing classifer
%

if nargin<3
    opt='load';
end

obj.objclassifier=[];

obj.objclassifierpath=str;

X=[];
Y=[];



if strcmp(opt,'load')  || strcmp(opt,'append')
    if exist(str)
        load(str);
        obj.objclassifier=tree;
    else
        fprintf('Classifier file not found \n')
        
        if strcmp(opt,'load')
        return;
        end
    end
    
end


if strcmp(opt,'save') || strcmp(opt,'append')
    
    ce=1;
    reverseStr='';
    for i=1:numel(obj.trap)
        
        
        [Xtmp,Ytmp]=obj.trap(i).collectObjectTrapData;
        
        X=[X ; Xtmp];
        Y=[Y ; Ytmp];
        
        
        
        msg = sprintf('%d / %d Traps screened', ce , numel(obj.trap) ); %Don't forget this semicolon
        msg=[msg ' for trap ' obj.id];
        
        fprintf([reverseStr, msg]);
        reverseStr = repmat(sprintf('\b'), 1, length(msg));
        
        ce=ce+1;
    end
    
    fprintf('\n');
    
    if numel(Y)==0
        fprintf('there is no training event in this movie ! quiting...\n');
        return;
    end
    
    %  Y'
    
    
    if strcmp(opt,'save')
        tree = fitctree(X,Y);
    end
    
    if strcmp(opt,'append')
      
        
        if numel(obj.objclassifier)~=0
        X= [obj.objclassifier.X ; X];
        Y= [obj.objclassifier.Y ; Y];
        end
        
         [X ix]=unique(X,'rows'); % remove doublons. 
        Y=round(Y(ix)); % round should not be necessary, but.... problems occured with non integer values
        
        tree = fitctree(X,Y);
    end
    
    imp = 1000*predictorImportance(tree)
    
    save(str,'tree');
end



obj.objclassifier=tree;

for i=1:numel(obj.trap)
    obj.trap(i).objtree=tree;
end











