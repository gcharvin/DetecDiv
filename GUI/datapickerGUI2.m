function [Tree handle]=datapickerGUI2(varargin)

handle=[];
flag=[];
input=[];
position=[12 12 400 400];

for i=1:numel(varargin)
    if strcmp(varargin{i},'Handle') % insert struct in a given gui
        handle=varargin{i+1};
    end
    if strcmp(varargin{i},'Flag') % indicate the handle to modify the color of a button when any field has been modifed
        flag=varargin{i+1};
    end
    if strcmp(varargin{i},'Input') % indicate the handle to modify the color of a button when any field has been modifed
        input=varargin{i+1};
    end
    if strcmp(varargin{i},'Position') % indicate the handle to modify the color of a button when any field has been modifed
        position=varargin{i+1};
    end
end

if numel(handle)==0
    handle=uifigure;
end

workspaceVars=gatherVarsFromWorkspace;


[pth fle ext]= fileparts(which('detecdiv.mlapp'));

Tree = uitree(handle,'checkbox');
%      Tree.SelectionChangedFcn = createCallbackFcn(app, @TreeSelectionChanged, true);


%  Tree.SelectionChangedFcn = {@TreeSelectionChanged, workspaceVars};
Tree.CheckedNodesChangedFcn = {@checkChanged, workspaceVars, flag};

Tree.CheckedNodes=[];
checkedNodes=[];

%  Tree.SelectionChangedFcn = createCallbackFcn(app, @TreeSelectionChanged, true);
Tree.Tooltip = {'Select data from projects loaded in memory'};
Tree.Position = position;

         Tree.UserData.roiobj=[];
        Tree.UserData.nodeid=[];
        Tree.UserData.filepath=[]; 

% Create ProjectsNode
ProjectNode = uitreenode(Tree);
ProjectNode.Text = 'Projects';
ProjectNode.Tag='Projects';

% Create IndependentClassifiersNode
IndependentClassifiersNode = uitreenode(Tree);
IndependentClassifiersNode.Text = 'Independent Classifiers';
IndependentClassifiersNode.Tag = 'IndependentClassifiers';


udata=[];
udata.parentnames={};
udata.name='';
udata.path='';
udata.ROI=[];
udata.link=[];
udata.nodeid=[];

for i=1:numel(workspaceVars.Project)

    proj=workspaceVars.Project{i};
    shallowObj=evalin('base',proj);
    io=shallowObj.io.path;

    udata.parentnames={};
    udata.name=proj;
    udata.path=io;
    udata.link=i;
    udata.nodeid=[proj '_' ];

    h1(i)=uitreenode(ProjectNode,'Text',workspaceVars.Project{i},'Tag','Project','UserData',udata,'Icon',fullfile(pth,'detecDiv_logo.png'));


    for k=1:numel(workspaceVars.Projectclassi{i})

        udata.parentnames={proj};
        udata.name=workspaceVars.Projectclassi{i}{k};
        udata.path=io;
        udata.link=[i,k];
        udata.nodeid=[proj '_' udata.name];

        g1(i,k)=uitreenode(h1(i),'Text',workspaceVars.Projectclassi{i}{k},'Tag','Projectclassi','UserData',udata,'Icon',fullfile(pth,'brain.png'));

                cc=udata.link;
                pos=cc(2);

                    if numel(workspaceVars.Projectclassirois{cc(1)})
                    %    [pth fle ext]= fileparts(which('detecdiv.mlapp'));
                        for n=1:numel(workspaceVars.Projectclassirois{cc(1)}{cc(2)})
                            % aa=app.Data.Projectclassirois{i}{k}{n}
                            %       cm=uicontextmenu(app.DetecDivUIFigure);
                            %   m = uimenu(cm,'Text','Open ROI...');
                            %   m.MenuSelectedFcn={@contextMenuROIFcn,[cc(1),cc(2),n],'Projectclassirois'};
                            %  ''ContextMenu',cm'

                            udata2=[];
                            udata2.parentnames={proj udata.name};
                            udata2.name=proj;
                            udata2.path=udata.path;
                            udata2.ROI=n;
                            udata2.link=[cc(1),cc(2),n];
                            udata2.nodeid=[udata.nodeid '_ROI' num2str(n)];

                            roinode=uitreenode(g1(i,k),'Text',workspaceVars.Projectclassirois{cc(1)}{cc(2)}{n},'Tag','Projectclassirois','UserData',udata2);%,'Icon',fullfile(pth,'roi.png'));
                                       if numel(input)
                                       if numel(find(matches(input,udata2.nodeid)))
                                                checkedNodes=[checkedNodes; roinode];
                                        end
                               end
                         
                        end
                    end


    end

    for k=1:numel(workspaceVars.Projectpos{i})

        udata.parentnames={proj};
         
        udata.name=workspaceVars.Projectpos{i}{k};

         pix=strfind(udata.name,'-');
         udata.name=udata.name(pix(1)+2:end);
    
        udata.path=io;
        udata.link=[i,k];
        udata.nodeid=[proj '_' udata.name];

        g2(i,k)=uitreenode(h1(i),'Text',workspaceVars.Projectpos{i}{k},'Tag','Projectpos','UserData',udata);%,'Icon',fullfile(pth,'data.png'));

        cc=udata.link;
        position= udata.nodeid;

        % display subnodes

        if numel(workspaceVars.Projectposrois{cc(1)})

            for n=1:numel(workspaceVars.Projectposrois{cc(1)}{cc(2)})

                udata2=[];
                udata2.parentnames={proj udata.name};
                udata2.name=proj;
                udata2.path=udata.path;
                udata2.link=[cc(1),cc(2),n];
                udata2.ROI=n;
                udata2.nodeid=[udata.nodeid  '_ROI' num2str(n)];

               roinode= uitreenode(g2(i,k),'Text',workspaceVars.Projectposrois{cc(1)}{cc(2)}{n},'Tag','Projectposrois','UserData',udata2);%,'Icon',fullfile(pth,'roi.png'));

               if numel(input)
                        if numel(find(matches(input,udata2.nodeid)))
                                checkedNodes=[checkedNodes; roinode];
                        end
               end

                % disabled because too heavy with large projects
            end
        end
    end
end

for i=1:numel(workspaceVars.Classifier)

    proj=workspaceVars.Classifier{i};
    classiObj=evalin('base',proj);

    udata.parentnames={};
    udata.name=[classiObj.strid '_indep'];
    udata.path=classiObj.path;
    udata.link=i;

    udata.nodeid=[udata.name];

    g3(i)=uitreenode(IndependentClassifiersNode,'Text',workspaceVars.Classifier{i},'Tag','Classifier','UserData',udata,'Icon',fullfile(pth,'brain.png'));

      cc=i;

                    if numel(workspaceVars.Classifierrois{cc})

                        for n=1:numel(workspaceVars.Classifierrois{cc})
                            % aa=app.Data.Projectclassirois{i}{k}{n}
                            %    cm=uicontextmenu(app.DetecDivUIFigure);
                            % m = uimenu(cm,'Text','Open ROI...');
                            %m.MenuSelectedFcn={@contextMenuROIFcn,[cc,n],'Projectposrois'};
                            %  'ContextMenu',cm
                            %  [pth fle ext]= fileparts(which('detecdiv.mlapp'));

                            udata2=[];
                            udata2.parentnames={proj};
                            udata2.name=[classiObj.strid '_indep'];
                            udata2.path=classiObj.path;
                            udata2.ROI=n;
                            udata2.link= [cc(1),n];
                            udata2.nodeid=[udata.name '_ROI' num2str(n)];

                            roinode=uitreenode(g3(i),'Text',workspaceVars.Classifierrois{cc}{n},'Tag','Classifierrois','UserData',udata2);%,'Icon',fullfile(pth,'roi.png'));

                               if numel(input)
                                       if numel(find(matches(input,udata2.nodeid)))
                                                checkedNodes=[checkedNodes; roinode];
                                        end
                               end

                            % disabled because too heavy with large projects
                        end
                    end
end

 if numel(input)
                                Tree.CheckedNodes=checkedNodes;
 end

expand(ProjectNode);
expand(IndependentClassifiersNode);


function st=gatherVarsFromWorkspace()
varlist=evalin('base','who');
st=struct('Project',{''},'Classifier',{''},'Projectpos',{''},'Projectclassi',{''},'Projectprocess',{''},'Projectposrois',{''},'Projectclassirois',{''},'Classifierrois',{''});
cc=0;
cd=0;

for i=1:numel(varlist)

    if strcmp(varlist{i},'ans')
        continue;
    end

    tmp=evalin('base',varlist{i});


    if isa(tmp,'shallow')
        disp('this is a shallow object')
        cc=cc+1;

        st.Project{cc}=varlist{i};

        tmpclassi={};

        for k=1:numel(tmp.processing.classification)
            %  k
            tmpclassi = [tmpclassi tmp.processing.classification(k).strid];

            if numel(tmp.processing.classification(k).roi)==1 && numel(tmp.processing.classification(k).roi.id)==0
                ntot=0;
            else
                ntot=numel(tmp.processing.classification(k).roi);
            end

            tmproi={};

            %  ntot

            for n=1:ntot

                tmproi=[tmproi [num2str(n) ' - ' tmp.processing.classification(k).roi(n).id]];

            end

            % tmproi
            st.Projectclassirois{cc}{k}=tmproi;
        end

        st.Projectclassi{cc}=tmpclassi;
        tmpprocess={};

        if isfield(tmp.processing,'processor')
            for k=1:numel(tmp.processing.processor)
                %  k
                tmpprocess = [tmpprocess tmp.processing.processor(k).strid];

            end

            st.Projectprocess{cc}=tmpprocess;
        end

        tmpproj={};

        for k=1:numel(tmp.fov)
            %  k
            if numel(tmp.fov(k).srcpath{1})>0
                tmpproj = [tmpproj [num2str(k) ' - ' tmp.fov(k).id]];
                %  aa=tmp.fov(k).srcpath
            end

            if numel(tmp.fov(k).roi)==1 && numel(tmp.fov(k).roi.id)==0
                ntot=0;
            else
                ntot=numel(tmp.fov(k).roi);
            end

            tmproi={};

            %  ntot

            for n=1:ntot

                tmproi=[tmproi [num2str(n) ' - ' tmp.fov(k).roi(n).id]];

            end

            % tmproi
            st.Projectposrois{cc}{k}=tmproi;


        end

        st.Projectpos{cc}=tmpproj;
    end

    if isa(tmp,'classi')

        disp('this is a classification object')
        cd=cd+1;
        st.Classifier{cd}=varlist{i};

        if numel(tmp.roi)==1 && numel(tmp.roi.id)==0
            ntot=0;
        else
            ntot=numel(tmp.roi);
        end

        tmproi={};

        %  ntot

        for n=1:ntot

            tmproi=[tmproi [num2str(n) ' - ' tmp.roi(n).id]];

        end

        % tmproi,cc
        st.Classifierrois{cd}=tmproi;

    end
end

    function checkChanged(src, event,data,flag)

    if numel(flag)

      %  if isfield(flag,'Color')
      %      'okk'
            flag.Color=[1 0 0];
     %   end
    end

        roiobj=[];
        nodeid={};
        filepath={};
        type={};

        checkedNodes = event.LeafCheckedNodes;

        if numel(checkedNodes)
            for i=1:numel(checkedNodes)

                typ= checkedNodes(i).Tag;

                if strcmp(typ,'Projectpos')

                    udata=checkedNodes(i).UserData;

                    shallowObj=evalin('base',udata.parentnames{1});
                    pix=strfind(udata.name,'-');
                    str=udata.name(pix+2:end);
                    listpos={shallowObj.fov(:).id};
                    posindex=find(matches(listpos,str));

                    roiobj=[roiobj  ; shallowObj.fov(posindex).roi(:)];

                    nodeid=[nodeid udata.nodeid];

                    filepath=[filepath fullfile(shallowObj.io.path,[shallowObj.io.file '.mat'])];
                    type=[type 'shallow'];
                end

                if strcmp(typ,'Projectposrois')

                    udata=checkedNodes(i).UserData;

                    shallowObj=evalin('base',udata.parentnames{1});
                    %  pix=strfind(udata.name,'-');
                    %   str=udata.name(pix+2:end);
                    listpos={shallowObj.fov(:).id};
                    posindex=find(matches(listpos,udata.parentnames{2}));

                    roiobj=[roiobj  ; shallowObj.fov(posindex).roi(udata.ROI)];
                    nodeid=[nodeid udata.nodeid];
                     filepath=[filepath fullfile(shallowObj.io.path,[shallowObj.io.file '.mat'])];
                       type=[type 'shallow'];
                end

                if strcmp(typ,'Projectclassi')

                    udata=checkedNodes(i).UserData;

                    shallowObj=evalin('base',udata.parentnames{1});

                    listclassi={shallowObj.processing.classification.strid};
                    posindex=find(matches(listclassi,udata.name));
                    % tmp=shallowObj.processing.classification(posindex).roi(:)
                    tmp=shallowObj.processing.classification(posindex).roi;
                    tmp=tmp';

                    roiobj=[roiobj ; tmp];
                    nodeid=[nodeid udata.nodeid];
                    filepath=[filepath fullfile(shallowObj.io.path,[shallowObj.io.file '.mat'])];
                      type=[type 'shallow'];
                end

                if strcmp(typ,'Projectclassirois')

                    udata=checkedNodes(i).UserData;

                    shallowObj=evalin('base',udata.parentnames{1});
                    %  pix=strfind(udata.name,'-');
                    %   str=udata.name(pix+2:end);
                    listclassi={shallowObj.processing.classification.strid};

                    posindex=find(matches(listclassi,udata.parentnames{2}));

                    tmp=shallowObj.processing.classification(posindex).roi(udata.ROI);
                    tmp=tmp';

                    roiobj=[roiobj ; tmp];
                    nodeid=[nodeid udata.nodeid];
                     filepath=[filepath fullfile(shallowObj.io.path,[shallowObj.io.file '.mat'])];
                       type=[type 'shallow'];
                end

                if strcmp(typ,'Classifier')

                    udata=checkedNodes(i).UserData;

                    classiObj=evalin('base',udata.name);

                    roiobj=[roiobj  ; classiObj.roi(:)];
                    nodeid=[nodeid udata.nodeid];
                     filepath=[filepath fullfile(classiObj.path,[classiObj.strid '_classification.mat'])];
                       type=[type 'classi'];
                end

                if strcmp(typ,'Classifierrois')

                    udata=checkedNodes(i).UserData;

                    classiObj=evalin('base',udata.parentnames{1});

                    tmp=classiObj.roi(udata.ROI);
                    tmp=tmp';

                    roiobj=[roiobj ; tmp];
                    nodeid=[nodeid udata.nodeid];
                    filepath=[filepath fullfile(classiObj.path,[classiObj.strid '_classification.mat'])];
                      type=[type 'classi'];
                end

            end
        end

        src.UserData.roiobj=roiobj;
        src.UserData.nodeid=nodeid;
        [src.UserData.filepath, ia,~]=unique(filepath); 
        src.UserData.type=type(ia);

    %    aa=src.UserData

        function TreeSelectionChanged(src, event,data)
            selectedNodes = event.SelectedNodes;

            if numel(selectedNodes)==0
                return
            end

            [pth fle ext]= fileparts(which('detecdiv.mlapp'));

            if strcmp(selectedNodes.Tag,'Projectpos')

                cc=selectedNodes.UserData.link;

                proj=data.Project{cc(1)};
                pos=cc(2);
                shallowObj=evalin('base',proj);
                position=shallowObj.fov(pos);

                % display subnodes

                if numel( selectedNodes.Children)==0
                    if numel(data.Projectposrois{cc(1)})

                        for n=1:numel(data.Projectposrois{cc(1)}{cc(2)})

                            % aa=app.Data.Projectclassirois{i}{k}{n}
                            %   cm=uicontextmenu(app.DetecDivUIFigure);
                            %  m = uimenu(cm,'Text','Open ROI...');
                            %  m.MenuSelectedFcn={@contextMenuROIFcn,[i,k,n],'Projectposrois'};

                            udata=[];
                            udata.parentnames={proj position.id};
                            udata.name=proj;
                            udata.path=shallowObj.io.path;
                            udata.link=[cc(1),cc(2),n];
                            udata.ROI=n;
                            udata.nodeid=[proj '_' position.id '_ROI' num2str(n)];

                            uitreenode(selectedNodes,'Text',data.Projectposrois{cc(1)}{cc(2)}{n},'Tag','Projectposrois','UserData',udata,'Icon',fullfile(pth,'roi.png'));
                            % disabled because too heavy with large projects
                        end
                    end
                end
            end


            if strcmp(selectedNodes.Tag,'Projectclassi')

                cc=selectedNodes.UserData.link;
                proj=data.Project{cc(1)};
                pos=cc(2);
                shallowObj=evalin('base',proj);
                clas=shallowObj.processing.classification(pos);

                if numel(selectedNodes.Children)==0
                    if numel(data.Projectclassirois{cc(1)})
                        [pth fle ext]= fileparts(which('detecdiv.mlapp'));
                        for n=1:numel(data.Projectclassirois{cc(1)}{cc(2)})
                            % aa=app.Data.Projectclassirois{i}{k}{n}
                            %       cm=uicontextmenu(app.DetecDivUIFigure);
                            %   m = uimenu(cm,'Text','Open ROI...');
                            %   m.MenuSelectedFcn={@contextMenuROIFcn,[cc(1),cc(2),n],'Projectclassirois'};
                            %  ''ContextMenu',cm'

                            udata=[];
                            udata.parentnames={proj clas.strid};
                            udata.name=proj;
                            udata.path=shallowObj.io.path;
                            udata.ROI=n;
                            udata.link=[cc(1),cc(2),n];
                            udata.nodeid=[proj '_' clas.strid '_ROI' num2str(n)];

                            uitreenode(selectedNodes,'Text',data.Projectclassirois{cc(1)}{cc(2)}{n},'Tag','Projectclassirois','UserData',udata,'Icon',fullfile(pth,'roi.png'));
                            % disabled because too heavy with large projects
                        end
                    end
                end
            end

            if strcmp(selectedNodes.Tag,'Classifier')

                cc=selectedNodes.UserData.link;
                proj=data.Classifier{cc};

                clas=evalin('base',proj);

                if numel(selectedNodes.Children)==0
                    if numel(data.Classifierrois{cc})

                        for n=1:numel(data.Classifierrois{cc})
                            % aa=app.Data.Projectclassirois{i}{k}{n}
                            %    cm=uicontextmenu(app.DetecDivUIFigure);
                            % m = uimenu(cm,'Text','Open ROI...');
                            %m.MenuSelectedFcn={@contextMenuROIFcn,[cc,n],'Projectposrois'};
                            %  'ContextMenu',cm
                            %  [pth fle ext]= fileparts(which('detecdiv.mlapp'));

                            udata=[];
                            udata.parentnames={proj};
                            udata.name=[clas.strid '_indep'];
                            udata.path=clas.path;
                            udata.ROI=n;
                            udata.link= [cc(1),n];
                            udata.nodeid=[udata.name '_ROI' num2str(n)];

                            uitreenode(selectedNodes,'Text',data.Classifierrois{cc}{n},'Tag','Classifierrois','UserData',udata,'Icon',fullfile(pth,'roi.png'));
                            % disabled because too heavy with large projects
                        end
                    end
                end
            end
        




