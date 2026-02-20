function varstr=listClasssfiers(shallowObj,classiObj)

s=gatherVariablesFromWorkspace;

if nargin==0
    shallowObj=[];
    classiObj=[];
end

if nargin==1
    classiObj=[];
end


cc=1;
store=[];
displaystr={};
varstr={};
tobeclassified_varstr={};
tobeclassified_projectstr={};
cd=1;

% list avaialable fovs and classi with ROIs
specificobj=[];

for i=1:numel(s.Projectclassi)

    proj=s.Project{i};

    if shallowObj==evalin('base',proj)
        specificobj=shallowObj; % project variable is provdided as input
    end

    for k=1:numel(s.Projectpos{i})

        if isa(shallowObj,'classi') % if classi is provided as inout, then skip project pos
            continue
        end

        tmp= evalin('base',[proj '.fov(' num2str(k) ')']);

        if numel(tmp.roi)>0 & numel(tmp.roi(1).id)>0
            tobeclassified_varstr{cd}=[proj '.fov(' num2str(k) ')'];
            tobeclassified_projectstr{cd}=proj;
            %displaystr{cc}=[proj '  //  ' s.Projectpos{i}{k}];
            if numel(store)==0
                store=numel(tmp.roi);
            end
            cd=cd+1;
            %  cc=cc+1;
        end
    end

    for k=1:numel(s.Projectclassi{i})

        tmp= evalin('base',[proj '.processing.classification(' num2str(k) ')']);

        if shallowObj==tmp
            specificobj=shallowObj; % classi variable from project is provided
        else
            if isa(shallowObj,'classi') % remove all other classi is classi obj is provided
                continue
            else            % if project is provided with a specific classifier as input, then discard all other classifer
                if tmp~=classiObj
                    continue
                end


            end
        end

        % if numel(tmp.roi)>0 & numel(tmp.roi(1).id)>0
        varstr{cc}=[proj '.processing.classification(' num2str(k) ')'];

        tobeclassified_varstr{cd}=[proj '.processing.classification(' num2str(k) ')'];
        tobeclassified_projectstr{cd}=proj;
        displaystr{cc}=[proj '  //  ' s.Projectclassi{i}{k}];

        if numel(store)==0
            store=numel(tmp.roi);
        end
        cc=cc+1;
        cd=cd+1;
        % end
    end
end
for i=1:numel(s.Classifier)

    clas=s.Classifier{i};

    tmp= evalin('base',clas);

    if shallowObj==tmp
        specificobj=shallowObj;
    else
        if isa(shallowObj,'classi') % remove all other classi is classi obj is provided
            continue
        else            % if project is provided with a specific classifier as input, then discard all other classifer
            if tmp~=classiObj
                continue
            end

        end
    end

    %if numel(tmp.roi)>0 & numel(tmp.roi(1).id)>0
    varstr{cc}=clas;

    displaystr{cc}=clas;
    tobeclassified_varstr{cd}=clas;
    tobeclassified_projectstr{cd}='';
    if numel(store)==0
        store=numel(tmp.roi);
    end
    cd=cd+1;
    cc=cc+1;
    % end

end
