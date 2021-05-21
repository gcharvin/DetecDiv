function fillTraining(obj,varargin)
%Arguments:
%*'Type': 'default' fills holes as the previous annotated frame
%'div': fills holes with nodiv or death. 

%%%%%%%%%%%%%%%%%%%%DIV%%%%%%%%%%%%%%%%%%%%
%For div classification (annotation for manual quantif, no DL)
%you need the classes 
%'dead'
%'censor'
%'nodiv'
%'div'
%'empty'

%If cell isnt born at frame 1, you
%must annotate the last frame before birth as Empty.

%If a cell is born at frame one -->no div or div

%If cell isnt dead at the last frame, you must annotate the last frame as
%censored. 

%If the cell is replaced before its death, annotate the frame of
%replace as censored.

%Otherwise, you only need to annotate the divs

%%%%%%%%%%%%%%%%%%%DEFAULT%%%%%%%%%%%%%%%%%%%
%Just annotate the first frame of each strech and the function will fill
%the holes using the first previous annotation. Exemple : 1 0 0 2 0 3
%will output 1 1 1 2 2 3

type='default';
for i=1:numel(varargin)
    if strcmp(varargin{i},'Type')
        type=varargin{i+1};
        if strcmp(type,'default') && strcmp(type,'div')
            error('Please enter a valide Type, among default or div');
        end
    end
end


%find the training id
trainids=fieldnames(obj.train);

str=[];
for i=1:numel(trainids)
    str=[str num2str(i) ' - ' trainids{i} ';'];
end

prompt=['Choose which training to fill among: ' str];
trainid=input(prompt);

if numel(trainid)==0
                trainid=numel(trainids);
end

trainid=trainids{trainid};
classes= obj.classes;
%%
switch type
    case 'default'
    %fill the holes
    lastAnnotatedFrame=find(obj.train.(trainid).id,1,'last');

    for f=2:lastAnnotatedFrame 
        if obj.train.(trainid).id(f)==0
         obj.train.(trainid).id(f)=     obj.train.(trainid).id(f-1);
        end
    end
    disp('Array filled');
    
    case 'div'
        %find class ids
        deathid=findclassid(classes,'dead');
        censorid=findclassid(classes,'censor');
        nodivid=findclassid(classes,'nodiv');
        divid=findclassid(classes,'div');
        emptyid=findclassid(classes,'empty');

        startFrame=find(obj.train.(trainid).id==emptyid,1,'last');
        if numel(startFrame)==0
            startFrame=1;
        end
        
        endFrame=min( [find(obj.train.(trainid).id==deathid,1,'first')  find(obj.train.(trainid).id==censorid,1,'first')]);
        if numel(endFrame)==0
            endFrame=numel(obj.train.(trainid).id);
        end
        
        %fill everything with nodiv or death
        for f=1:startFrame
            if obj.train.(trainid).id(f)==0 %if not annotated, annotate as no div
                obj.train.(trainid).id(f)=obj.train.(trainid).id(startFrame);
            end
        end
        
        
        for f=endFrame:numel(obj.train.(trainid).id)
            if obj.train.(trainid).id(f)==0 %if not annotated, annotate as no div
                obj.train.(trainid).id(f)=obj.train.(trainid).id(endFrame);
            end
        end
        
        
        for f=startFrame:endFrame
            if obj.train.(trainid).id(f)==0 %if not annotated, annotate as no div
                    obj.train.(trainid).id(f)=nodivid;
            end
        end
        
    disp('Array holes filled with nodiv');
end
function clid=findclassid(classes,str)
clid=[];
for i=1:numel(classes)
    if strcmp(classes{i},str)
        clid=i;
        break;
    end
end