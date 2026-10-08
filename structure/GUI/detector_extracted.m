classdef detector < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        DataexportingandplottingUIFigure  matlab.ui.Figure
        FileMenu                       matlab.ui.container.Menu
        LoaddatagroupsMenu             matlab.ui.container.Menu
        SavedatagroupsasMenu           matlab.ui.container.Menu
        TabGroup                       matlab.ui.container.TabGroup
        SelectROIsTab                  matlab.ui.container.Tab
        SelectDatasourceTab            matlab.ui.container.Tab
        DatatypeDropDown               matlab.ui.control.DropDown
        DatatypeDropDownLabel          matlab.ui.control.Label
        PutdataingroupsTab             matlab.ui.container.Tab
        DatagroupsoptionalPanel        matlab.ui.container.Panel
        AssignselectedgroupparamtoallButton  matlab.ui.control.Button
        RenamegroupEditField           matlab.ui.control.EditField
        RenamegroupEditFieldLabel      matlab.ui.control.Label
        DeleteselectedgroupButton      matlab.ui.control.Button
        NewgroupButton                 matlab.ui.control.Button
        DatagroupsListBox              matlab.ui.control.ListBox
        SetplottingoptionsTab          matlab.ui.container.Tab
        SetoutputdirTab                matlab.ui.container.Tab
        SetfileButton                  matlab.ui.control.Button
        DatasheetexportfilexlsxEditField  matlab.ui.control.EditField
        DatasheetexportfilexlsxEditFieldLabel  matlab.ui.control.Label
        SetdirectoryButton             matlab.ui.control.Button
        PlottingexportdirectoryfigandpdfEditField  matlab.ui.control.EditField
        PlottingexportdirectoryfigandpdfEditFieldLabel  matlab.ui.control.Label
        PlotLineagesButton             matlab.ui.control.Button
        PlotRLSButton                  matlab.ui.control.Button
        PlotdivisiontimesButton        matlab.ui.control.Button
        ExportdataasxlsxButton         matlab.ui.control.Button
        PlotselecteddatasourcesButton  matlab.ui.control.Button
        Lamp                           matlab.ui.control.Lamp
        SaveselectionButton            matlab.ui.control.Button
    end


    properties (Access = private)
        Data % Description
    end

    methods (Access = private)
        function  gatherVarsFromWorkspace(app)

            varlist=evalin('base','who');
            st=struct('Project',{''},'Classifier',{''},'Projectpos',{''},'Projectclassi',{''});
            stclassi=struct('Classifier',{[]},'Projectclassi',{[]});

            cc=0;
            cd=0;
            app.Data.st=[];
            app.Data.stclassi=[];

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
                    tmpclassi2=classi;

                    for k=1:numel(tmp.processing.classification)
                        tmpclassi = [tmpclassi tmp.processing.classification(k).strid];

                        tmpclassi2(k)= tmp.processing.classification(k);
                    end

                    st.Projectclassi{cc}=tmpclassi;
                    stclassi.Projectclassi{cc}=tmpclassi2;

                    tmpproj={};

                    for k=1:numel(tmp.fov)
                        %  k
                        tmpproj = [tmpproj tmp.fov(k).id];
                    end

                    st.Projectpos{cc}=tmpproj;
                end

                if isa(tmp,'classi')

                    disp('this is a classification object')
                    cd=cd+1;
                    st.Classifier{cd}=varlist{i};

                    stclassi.Classifier{cd}=evalin('base',varlist{i});
                    % aa= st.Classifier{cd}
                end

            end

            %  st
            app.Data.st=st;
            app.Data.stclassi=stclassi;
            %    app.Data.convert={};
        end


        function param = newGroup(app)
            tip={'Select how single trajectories should be averaged',...
                'Select the single cell plotting type',...
                'Select the single cell traj low color',...
                'Select the single cell traj high color',...
                'select the min max value for color extremes; leave as is to get an automated normaization',...
                  'Check to display edges around contours',...
                     'Select the single cell edge color',...
                  'Mark mother vs daughter lineage',...
                     'Sort trajectory by number of generation',...
                     'Check box to display the name of the ROI',...
                'Check to display single cells',...
                'Check to display population averages'};

            param=struct('Traj_synchronization',{{'birth','sep','death','birth'}},...
                'Single_cell_display_type',{{'traj','plot','traj'}},...
                'Single_cell_traj_low_color','0.85 0.85 0.85',...
                'Single_cell_traj_high_color','1 0 0',...
                'Single_cell_min_max','NaN NaN',...
                 'Display_traj_edge',false,...
                 'Display_traj_edge_color','0 0 0',...
                    'Display_MD_lineage',false,...
                    'Sort_traj',true,...
                    'Display_ROI_name',false, ...
                'Display_single_cell_plot',true,...
                'Display_average',true,...
                'tip',{tip});
        end

        function fields = gatherROIsfields(app,rois,datatype)
            fields=[];
            %fields={[] [] []};
            fields.Results={[] [] []};

            if numel(rois)==0
                return
            end

            % results fields
            tmpr={};
            idx={};

            cc=1;

            for i=1:numel(rois)
                rois(i).load('data');
                for j=1:numel(rois(i).data)
                    if rois(i).data(j).type==string(datatype)
                        tmpr=[tmpr rois(i).data(j).groupid];
                        idx=[idx rois(i).data(j).id];
                        cc=cc+1;
                    end
                end
            end

            [tmpr,ia]=unique(tmpr);

            %   tmpr=tmpr(ia)

            subt={};
            subcat={};


            for i=1:numel(tmpr)

                tt={};
                catr={};

                for j=1:numel(rois)

                    pix=find(matches({rois(j).data.groupid},tmpr(i)));

                    if numel(pix)
                        %pix=matches(tmpr2,tmpr{i});

                        % if sum(pix)>0

                        subtmpr=rois(j).data(pix).data.Properties.VariableNames;

                        si=rois(j).data(pix).dataSize;

                        for k=1:numel(subtmpr)
                            %
                            %                                 if ~isstruct(rois(j).results.(tmpr2{pix}).(subtmpr{k}))
                            %
                            tt=[tt subtmpr(k)];
                            %

                            catr=[catr [' // ' num2str(si(1)) ' elements // ' class(rois(j).data(pix).data.(subtmpr{k})) ' ']];
                            %                                 end
                            %                             end
                        end


                    end
                    %   end
                end

                [ttt,iaa,~]=unique(tt);
                catrr=catr(iaa);

                subt{i}=ttt;
                subcat{i}=catrr;
            end

            % subt,subcat
            fields.Results={tmpr subt}; % subcat};
        end
    end

    methods (Access = public)
        function display2(app,datapicker)
            d = uiprogressdlg(app.DataexportingandplottingUIFigure,'Title','Please Wait...',...
                'Message','Loading data group...');
            d.Value=0.33;

            groups=evalin('base','datagroups');

            % check if data/sources are selected to enable corresponding
            % buttons

            for i=1:numel(groups)

                %       if numel()

            end

            %groups = app.Data.groups;
            items= {groups.Name};

            if numel(app.DatagroupsListBox.Value)
                aa=app.DatagroupsListBox.Value;
                pix=find(matches(items,aa));

                if numel(pix)==0
                    pix=1;
                else
                    pix=pix(1);
                end
            else
                pix=1;
            end

            % create panel with plotting options
            app.DatagroupsListBox.Items=items;
            app.DatagroupsListBox.Value=items{pix};

            param=groups(pix).Param;

            tip=param.tip;
            param=rmfield(param,'tip');

            if numel(app.SetplottingoptionsTab.Children)
                delete(app.SetplottingoptionsTab.Children)
                app.SetplottingoptionsTab.UserData=[];
            end

            struct2GUI(param,[10 330],'Handle',app.SetplottingoptionsTab,'Tip',tip,'Flag',app.Lamp);
            param.tip=tip;
            app.RenamegroupEditField.Value=char(string(items{pix}));

            if nargin==2 % creates ROI picker
                if numel(groups(pix).Data.nodeid)
                    %nodes=app.Data.groups(pix).Data;Data
                    nodes=groups(pix).Data.nodeid;
                else
                    nodes=[];
                end

                if exist('datatree','var')
                    if ishandle(datatree)
                        delete(datatree)
                    end
                end

                d.Value=0.5;

                d.Message='Refreshing data picker...';

                [datatree,~]=datapickerGUI2('Handle',app.SelectROIsTab,'Flag',app.Lamp,'Position',[12 12 540 340],'Input',nodes);
                app.Data.tree=datatree;
                %  tmp=app.Data.tree.UserData
                drawnow
            end

            % create data source picker
            rois=groups(pix).Data.roiobj;

            if isfield(app.Data, 'sourcetree')
                delete(app.Data.sourcetree)
            end

            Tree = uitree(app.SelectDatasourceTab,'checkbox');
            Tree.CheckedNodesChangedFcn = {@checkChanged, app.Lamp};
            Tree.Tooltip = {'Select data to be plotted or exported'};
            Tree.Position = [10 10 540 310];
            app.Data.sourcetree=Tree;

            if ~isempty(rois)
                typedata=groups(pix).Type; %Param.Plot_type{end};

                fields=gatherROIsfields(app,rois,typedata);

                if numel(groups(pix).Source)==0
                    sourceid={};
                else
                    sourceid=groups(pix).Source.nodeid;
                end

                checkedNodes=[];

                for i=1:numel(fields.Results{1})
                    if numel(fields.Results{2}{i})
                        h3(i)=uitreenode(Tree,'Text',fields.Results{1}{i},'Tag','Results','UserData',[]);

                        for j=1:numel(fields.Results{2}{i})

                            str= fields.Results{2}{i}{j}; % fields.Results{3}{i}{j}];
                            h4(i,j)=uitreenode(h3(i),'Text',str,'Tag',['Results' num2str(i) '_' num2str(j)],'UserData',...
                                {fields.Results{1}{i} fields.Results{2}{i}{j}} );
                            if numel(sourceid)
                                if numel(find(matches(sourceid,['Results' num2str(i) '_' num2str(j)])))
                                    checkedNodes=[checkedNodes; h4(i,j)];
                                end
                            end
                        end
                    end
                end

                Tree.CheckedNodes=checkedNodes;

                expand(Tree);
            end

            % set output directory fields

            d.Value=0.8;
            d.Message='Set output directories...';

            savedirstr=evalin('base','datagroups_savedir');
            savesheet=evalin('base','datagroups_savesheet');

            app.DatasheetexportfilexlsxEditField.Value=savesheet;
            app.PlottingexportdirectoryfigandpdfEditField.Value=savedirstr;


            % enable available buttons
            sel=pix;
            test_roi=false;
            test_source=false;

            if numel(groups(sel).Data.roiobj)
                test_roi=true;
            end


            if isfield(groups(sel).Source,'nodeid')
                if numel(groups(sel).Source.nodeid)
                    test_source=true;
                end
            end

            app.PlotLineagesButton.Enable="off";
            app.PlotRLSButton.Enable="off";
            app.PlotdivisiontimesButton.Enable="off";
            app.PlotselecteddatasourcesButton.Enable="off";
            app.ExportdataasxlsxButton.Enable="off";

            if test_roi && test_source

                app.ExportdataasxlsxButton.Enable="on";

                for h=1:numel(groups(sel).Source.nodename)

                    if  strcmp(groups(sel).Source.nodename{h}{2},'event')
                        app.PlotRLSButton.Enable="on";
                    elseif strcmp(groups(sel).Source.nodename{h}{2},'divduration')
                        app.PlotdivisiontimesButton.Enable="on";
                    else
                        app.PlotselecteddatasourcesButton.Enable="on";
                    end
                end
            end


            function checkChanged(src, event, flag)

                if numel(flag)
                    flag.Color=[1 0 0];
                end

                nodeid={};
                nodename={};

                checkedN = event.LeafCheckedNodes;

                if numel(checkedN)
                    for k=1:numel(checkedN)
                        nodeid{end+1}=checkedN(k).Tag;
                        nodename{end+1}=checkedN(k).UserData;
                    end
                end

                src.UserData.nodeid=nodeid;
                src.UserData.nodename=nodename;
            end

            d.Value=0.9;
            d.Message='Data loaded...';
            close(d)

        end
    end


    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            app.Data=[];

            %gatherVarsFromWorkspace(app)

            varlist=evalin('base','who');

            ok=0;
            okfile=0;
            oksheet=0;

            for i=1:numel(varlist)
                if strcmp(varlist{i},'datagroups')
                    % groups=evalin('base','datagroups');
                    ok=1;
                    %  break
                end

                if strcmp(varlist{i},'datagroups_savedir')
                    % groups=evalin('base','datagroups');
                    okfile=1;
                    %    break
                end

                if strcmp(varlist{i},'datagroups_savesheet')
                    % groups=evalin('base','datagroups');
                    oksheet=1;
                    %    break
                end
            end

            if ok==0
                param = newGroup(app);

                groups=struct('Name','group01','Data',[],'Param',param,'Table',[],'Source',[],'Type','temporal');
                groups.Data.nodeid=[];
                groups.Data.roiobj=[];
                groups.Source.nodeid={};
                groups.tip=param.tip;



                assignin('base','datagroups',groups);
            end

            if okfile==0
                datagroups_savedir=userpath;
                assignin('base','datagroups_savedir',datagroups_savedir);
            end

            if oksheet==0
                datagroups_savesheet=fullfile(userpath,'myexportsheet.xlsx');
                assignin('base','datagroups_savesheet', datagroups_savesheet);
            end

            display2(app,'datapicker')


        end

        % Value changed function: DatagroupsListBox
        function DatagroupsListBoxValueChanged(app, event)
            tmp=app.DatagroupsListBox.Value;
            app.Data.selectedgroup = tmp;
            display2(app,'refresh')
        end

        % Value changed function: RenamegroupEditField
        function RenamegroupEditFieldValueChanged(app, event)
            value = app.RenamegroupEditField.Value;

            groups=evalin('base','datagroups');

            if numel(app.DatagroupsListBox.Value)
                pix=find(matches(app.DatagroupsListBox.Items,app.DatagroupsListBox.Value));
                pix=pix(1);
                groups(pix).Name=value;
                app.DatagroupsListBox.Items{pix}=value;
                app.DatagroupsListBox.Value=value;
            end

            assignin('base','datagroups',groups);
        end

        % Button pushed function: NewgroupButton
        function NewgroupButtonPushed(app, event)
            pix=numel(app.DatagroupsListBox.Items);

            sel=find(matches(app.DatagroupsListBox.Items,app.DatagroupsListBox.Value));

            groups=evalin('base','datagroups');

            groupName=['group' num2str(pix+1)];
            if isempty(groups)
                param=newGroup(app);
                newGroupData=struct('nodeid',[],'roiobj',[],'filepath',[],'type',{{}});
                newGroupSource=struct('nodeid',{{}},'nodename',{{}});
                newGroupItem=struct('Name',groupName,'Data',newGroupData,'Param',param, ...
                    'Table',[],'Source',newGroupSource,'Type','temporal','tip',{param.tip});
                groups=newGroupItem;
            else
                if ~isempty(sel)
                    templateIndex=sel(1);
                    param=groups(templateIndex).Param;
                    dataType=groups(templateIndex).Type;
                    filepath=[];
                    if isfield(groups(templateIndex).Data,'filepath')
                        filepath=groups(templateIndex).Data.filepath;
                    end
                else
                    param=newGroup(app);
                    dataType='temporal';
                    filepath=[];
                end
                newGroupItem=groups(end);
                newGroupItem.Name=groupName;
                newGroupItem.Param=param;
                newGroupItem.Source=struct('nodeid',{{}},'nodename',{{}});
                newGroupItem.Type=dataType;
                newGroupItem.tip=param.tip;
                newGroupItem.Data=struct('nodeid',[],'roiobj',[],'filepath',filepath,'type',{{}});
                groups(end+1)=newGroupItem;
            end

            app.DatagroupsListBox.Items={groups.Name};
            app.DatagroupsListBox.Value=groupName;

            assignin('base','datagroups',groups);

             display2(app,'datapicker')

        end

        % Button pushed function: DeleteselectedgroupButton
        function DeleteselectedgroupButtonPushed(app, event)
            sel=find(matches(app.DatagroupsListBox.Items,app.DatagroupsListBox.Value));
            sel=sel(1);

            groups=evalin('base','datagroups');

            if numel(sel)
                li=setxor(1:numel(app.DatagroupsListBox.Items),sel);
                if numel(li)
                    app.DatagroupsListBox.Items=app.DatagroupsListBox.Items(li);
                    %groups= app.Data.groups(li);
                    app.DatagroupsListBox.Value=app.DatagroupsListBox.Items{1};
                    groups= groups(li);
                else
                    uialert(app.DataexportingandplottingUIFigure, ...
                        'At least one data group must remain.','Warning');
                    return;
                end
            end

            assignin('base','datagroups',groups);

              display2(app,'datapicker')
        end

        % Button pushed function: SaveselectionButton
        function SaveselectionButtonPushed(app, event)
            sel=find(matches(app.DatagroupsListBox.Items,app.DatagroupsListBox.Value));
            sel=sel(1);

            groups=evalin('base','datagroups');

            test_roi=false;
            test_source=false;

            if numel(sel)
                %app.Data.groups(sel).Param=app.DivisionextractionparametersPanel.UserData;

                if numel(app.Data.tree.UserData)
                    if numel(app.Data.tree.UserData.nodeid)
                        groups(sel).Data.nodeid= app.Data.tree.UserData.nodeid;
                        groups(sel).Data.roiobj= app.Data.tree.UserData.roiobj;
                        groups(sel).Data.filepath= app.Data.tree.UserData.filepath;
                        groups(sel).Data.type= app.Data.tree.UserData.type;
                    else
                        % groups(sel).Data.nodeid=[];
                        % groups(sel).Data.roiobj= [];
                        % groups(sel).Data.filepath= [];
                        % groups(sel).Data.type= [];
                    end
                end



                if numel(app.SetplottingoptionsTab.UserData)
                    groups(sel).Param=app.SetplottingoptionsTab.UserData;
                    groups(sel).Param.tip=groups(sel).tip;

                    % here : if you change birth vs temporal, then clear
                    % the source tree below !!!
                    %    groups(sel).Source.nodename=[];
                    %  groups(sel).Source.nodeid=[];
                end

                if numel(app.Data.sourcetree.UserData)
                    if numel(app.Data.sourcetree.UserData.nodeid)
                        groups(sel).Source=app.Data.sourcetree.UserData;
                    else
                        %     groups(sel).Source=[];
                    end
                end



                app.Lamp.Color=[0 1 0];
                assignin('base','datagroups',groups);
            end

            display2(app)

        end

        % Button pushed function: AssignselectedgroupparamtoallButton
        function AssignselectedgroupparamtoallButtonPushed(app, event)
            sel=find(matches(app.DatagroupsListBox.Items,app.DatagroupsListBox.Value));
            sel=sel(1);

            groups=evalin('base','datagroups');

            if numel(sel)
                li=setxor(1:numel(app.DatagroupsListBox.Items),sel);
                if numel(li)
                    for i=li
                        groups(i).Param=groups(sel).Param;
                        groups(i).Data=groups(sel).Data;
                    end
                end
            else
                uialert(app.DataexportingandplottingUIFigure,'First select a data group !','Warning');
            end

            assignin('base','datagroups',groups);

        end

        % Menu selected function: LoaddatagroupsMenu
        function LoaddatagroupsMenuSelected(app, event)

            [file,path] = uigetfile('*.mat','Select a shallow project',pwd);
            if isequal(file,0)
                disp('User selected Cancel')
                return;
            else
                disp(['User selected ', fullfile(path, file)]);
                filename=fullfile(path, file);

                load(filename);

                % check if projects are loaded ; if not , load them ...
                for i=1:numel(groups)
                    %  tmp=groups(i).Data
                    for j=1:numel(groups(i).Data.filepath)
                        if numel(groups(i).Data.filepath{j})
                            if strcmp(groups(i).Data.type{j},'shallow')
                                sha=shallowLoad(groups(i).Data.filepath{j});
                                if numel(sha)
                                    name=sha.io.file;
                                    assignin('base',name,sha);
                                end
                            end
                            if strcmp(groups(i).Data.type{j},'classi')
                                sha=classiLoad(groups(i).Data.filepath{j});
                                if numel(sha)
                                    name=[sha.strid '_indep'];
                                    assignin('base',name,sha);
                                end
                            end
                        end
                    end
                end

                assignin('base','datagroups',groups);
              assignin('base','datagroups_savedir',groups_dir);
              assignin('base','datagroups_savesheet',groups_sheet);

                display2(app,'refresh');
            end

        end

        % Menu selected function: SavedatagroupsasMenu
        function SavedatagroupsasMenuSelected(app, event)
            [file,path] = uiputfile('*.mat','Choose a data group filename',pwd);

            if isequal(file,0)
                disp('User selected Cancel')
                return;
            else
                disp(['User selected ', fullfile(path, file)]);
                filename=fullfile(path, file);

                groups=evalin('base','datagroups');
                groups_dir=evalin('base','datagroups_savedir');
                groups_sheet=evalin('base','datagroups_savesheet');

                save(filename, 'groups','groups_dir','groups_sheet');
            end
        end

        % Button pushed function: ExportdataasxlsxButton
        function ExportdataasxlsxButtonPushed(app, event)


            groups=evalin('base','datagroups');

            %groups = app.Data.groups;
            items= {groups.Name};

            if numel(app.DatagroupsListBox.Value)
                aa=app.DatagroupsListBox.Value;
                pix=find(matches(items,aa));

                if numel(pix)==0
                    pix=1;
                else
                    pix=pix(1);
                end
            else
                pix=1;
            end

            rois=groups(pix).Data.roiobj;

            if numel(rois)==0
                uialert(app.DataexportingandplottingUIFigure,'First select at least one ROI !', 'Warning');
                return;
            end

            if numel(app.DatasheetexportfilexlsxEditField.Value)
                filename=app.DatasheetexportfilexlsxEditField.Value;
            else
                uialert(app.DataexportingandplottingUIFigure,'Please specify a filename first !','Warning');
                return;
            end

            if numel(filename)==0
                uialert(app.DataexportingandplottingUIFigure,'First select a valid filename first !', 'Warning');
                return;
            end

            datagroup=groups(pix);
            exportData(datagroup,rois,filename)

        end

        % Button pushed function: SetfileButton
        function SetfileButtonPushed(app, event)
            tmp=evalin('base','datagroups_savesheet');
            [file,path] = uiputfile('*.xlsx','Enter the path and filename of the exported file',tmp);
            if isequal(file,0)
                disp('User selected Cancel')
                return;
            else
                disp(['User selected ', fullfile(path, file)]);
                filename=fullfile(path, file);
                app.DatasheetexportfilexlsxEditField.Value=filename;
                app.Data.file=filename;
                assignin('base','datagroups_savesheet',filename);
            end
        end

        % Button pushed function: SetdirectoryButton
        function SetdirectoryButtonPushed(app, event)
            tmp=evalin('base','datagroups_savedir');
            path = uigetdir(tmp,'Enter the path of the exported plots');
            if path==0
                disp('User selected Cancel')
                return;
            else
                disp(['User selected ', fullfile(path)]);
                %filename=fullfile(path, file);
                app.PlottingexportdirectoryfigandpdfEditField.Value=path;
                app.Data.dir=path;
                assignin('base','datagroups_savedir',path);
            end
        end

        % Button pushed function: PlotselecteddatasourcesButton
        function PlotselecteddatasourcesButtonPushed(app, event)

            groups=evalin('base','datagroups');

            %             %groups = app.Data.groups;
            %             items= {groups.Name};
            %
            %             if numel(app.DatagroupsListBox.Value)
            %                 aa=app.DatagroupsListBox.Value;
            %                 pix=find(matches(items,aa));
            %
            %                 if numel(pix)==0
            %                     pix=1;
            %                 else
            %                     pix=pix(1);
            %                 end
            %             else
            %                 pix=1;
            %             end

            for i=1:numel(groups)
                rois=groups(i).Data.roiobj;

                if numel(rois)==0
                    uialert(app.DataexportingandplottingUIFigure,'First select at least one ROI in each group !', 'Warning');
                    return;
                end
            end

            filename=app.PlottingexportdirectoryfigandpdfEditField.Value;

            if numel(filename)==0
                uialert(app.DataexportingandplottingUIFigure,'Please specify a filename first !','Warning');
                return;
            end

            if numel(filename)==0
                uialert(app.DataexportingandplottingUIFigure,'First select a valid filename first !', 'Warning');
                return;
            end

            %  datagroup=groups(pix);

            plotData_generic(groups,filename)

        end

        % Value changed function: DatatypeDropDown
        function DatatypeDropDownValueChanged(app, event)
            value = app.DatatypeDropDown.Value;

            sel=find(matches(app.DatagroupsListBox.Items,app.DatagroupsListBox.Value));
            sel=sel(1);

            groups=evalin('base','datagroups');

            if numel(sel)

                groups(sel).Type=value;
                groups(sel).Source.nodename=[];
                groups(sel).Source.nodeid=[];

                app.Lamp.Color=[1 0 0];
                assignin('base','datagroups',groups);
                display2(app)
            end



        end

        % Button pushed function: PlotdivisiontimesButton
        function PlotdivisiontimesButtonPushed(app, event)
            groups=evalin('base','datagroups');

            for i=1:numel(groups)
                rois=groups(i).Data.roiobj;

                if numel(rois)==0
                    uialert(app.DataexportingandplottingUIFigure,'First select at least one ROI in each group !', 'Warning');
                    return;
                end
            end

            filename=app.PlottingexportdirectoryfigandpdfEditField.Value;

            if numel(filename)==0
                uialert(app.DataexportingandplottingUIFigure,'Please specify a filename first !','Warning');
                return;
            end

            if numel(filename)==0
                uialert(app.DataexportingandplottingUIFigure,'First select a valid filename first !', 'Warning');
                return;
            end

            plotDivisionTimes(groups,filename)
        end

        % Button pushed function: PlotRLSButton
        function PlotRLSButtonPushed(app, event)
            groups=evalin('base','datagroups');

            for i=1:numel(groups)
                rois=groups(i).Data.roiobj;

                if numel(rois)==0
                    uialert(app.DataexportingandplottingUIFigure,'First select at least one ROI in each group !', 'Warning');
                    return;
                end
            end

            filename=app.PlottingexportdirectoryfigandpdfEditField.Value;

            if numel(filename)==0
                uialert(app.DataexportingandplottingUIFigure,'Please specify a filename first !','Warning');
                return;
            end

            if numel(filename)==0
                uialert(app.DataexportingandplottingUIFigure,'First select a valid filename first !', 'Warning');
                return;
            end

            plotRLS(groups,filename)

        end

        % Button pushed function: PlotLineagesButton
        function PlotLineagesButtonPushed(app, event)

        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create DataexportingandplottingUIFigure and hide until all components are created
            app.DataexportingandplottingUIFigure = uifigure('Visible', 'off');
            app.DataexportingandplottingUIFigure.Position = [100 100 747 475];
            app.DataexportingandplottingUIFigure.Name = 'Data exporting and plotting';

            % Create FileMenu
            app.FileMenu = uimenu(app.DataexportingandplottingUIFigure);
            app.FileMenu.Text = 'File...';

            % Create LoaddatagroupsMenu
            app.LoaddatagroupsMenu = uimenu(app.FileMenu);
            app.LoaddatagroupsMenu.MenuSelectedFcn = createCallbackFcn(app, @LoaddatagroupsMenuSelected, true);
            app.LoaddatagroupsMenu.Text = 'Load data groups...';

            % Create SavedatagroupsasMenu
            app.SavedatagroupsasMenu = uimenu(app.FileMenu);
            app.SavedatagroupsasMenu.MenuSelectedFcn = createCallbackFcn(app, @SavedatagroupsasMenuSelected, true);
            app.SavedatagroupsasMenu.Text = 'Save data groups as...';

            % Create SaveselectionButton
            app.SaveselectionButton = uibutton(app.DataexportingandplottingUIFigure, 'push');
            app.SaveselectionButton.ButtonPushedFcn = createCallbackFcn(app, @SaveselectionButtonPushed, true);
            app.SaveselectionButton.Position = [14 12 128 53];
            app.SaveselectionButton.Text = 'Save selection';

            % Create Lamp
            app.Lamp = uilamp(app.DataexportingandplottingUIFigure);
            app.Lamp.Position = [18 30 20 20];

            % Create PlotselecteddatasourcesButton
            app.PlotselecteddatasourcesButton = uibutton(app.DataexportingandplottingUIFigure, 'push');
            app.PlotselecteddatasourcesButton.ButtonPushedFcn = createCallbackFcn(app, @PlotselecteddatasourcesButtonPushed, true);
            app.PlotselecteddatasourcesButton.WordWrap = 'on';
            app.PlotselecteddatasourcesButton.Enable = 'off';
            app.PlotselecteddatasourcesButton.Tooltip = {'Plot matlab figures for all selected groups and data sources, export figures as .fig and .pdf'};
            app.PlotselecteddatasourcesButton.Position = [274 44 174 23];
            app.PlotselecteddatasourcesButton.Text = 'Plot selected data sources';

            % Create ExportdataasxlsxButton
            app.ExportdataasxlsxButton = uibutton(app.DataexportingandplottingUIFigure, 'push');
            app.ExportdataasxlsxButton.ButtonPushedFcn = createCallbackFcn(app, @ExportdataasxlsxButtonPushed, true);
            app.ExportdataasxlsxButton.Enable = 'off';
            app.ExportdataasxlsxButton.Position = [149 12 114 53];
            app.ExportdataasxlsxButton.Text = 'Export data as .xlsx';

            % Create PlotdivisiontimesButton
            app.PlotdivisiontimesButton = uibutton(app.DataexportingandplottingUIFigure, 'push');
            app.PlotdivisiontimesButton.ButtonPushedFcn = createCallbackFcn(app, @PlotdivisiontimesButtonPushed, true);
            app.PlotdivisiontimesButton.WordWrap = 'on';
            app.PlotdivisiontimesButton.Enable = 'off';
            app.PlotdivisiontimesButton.Tooltip = {'this is possible if a "divduration" dataset is available in the "generation" data mode'};
            app.PlotdivisiontimesButton.Position = [274 16 174 23];
            app.PlotdivisiontimesButton.Text = 'Plot division times';

            % Create PlotRLSButton
            app.PlotRLSButton = uibutton(app.DataexportingandplottingUIFigure, 'push');
            app.PlotRLSButton.ButtonPushedFcn = createCallbackFcn(app, @PlotRLSButtonPushed, true);
            app.PlotRLSButton.WordWrap = 'on';
            app.PlotRLSButton.Enable = 'off';
            app.PlotRLSButton.Tooltip = {'this is possible if an "event" dataset is available in the "generation" data mode'};
            app.PlotRLSButton.Position = [454 45 174 23];
            app.PlotRLSButton.Text = 'Plot RLS';

            % Create PlotLineagesButton
            app.PlotLineagesButton = uibutton(app.DataexportingandplottingUIFigure, 'push');
            app.PlotLineagesButton.ButtonPushedFcn = createCallbackFcn(app, @PlotLineagesButtonPushed, true);
            app.PlotLineagesButton.WordWrap = 'on';
            app.PlotLineagesButton.Enable = 'off';
            app.PlotLineagesButton.Tooltip = {'this is possible if a "lineage" dataset is available in the "generation" data mode'};
            app.PlotLineagesButton.Position = [456 14 174 23];
            app.PlotLineagesButton.Text = 'Plot Lineages';

            % Create TabGroup
            app.TabGroup = uitabgroup(app.DataexportingandplottingUIFigure);
            app.TabGroup.Position = [14 75 715 391];

            % Create SelectROIsTab
            app.SelectROIsTab = uitab(app.TabGroup);
            app.SelectROIsTab.Title = '1) Select ROIs';

            % Create SelectDatasourceTab
            app.SelectDatasourceTab = uitab(app.TabGroup);
            app.SelectDatasourceTab.Title = '2) Select Data source';

            % Create DatatypeDropDownLabel
            app.DatatypeDropDownLabel = uilabel(app.SelectDatasourceTab);
            app.DatatypeDropDownLabel.HorizontalAlignment = 'right';
            app.DatatypeDropDownLabel.Position = [14 335 56 22];
            app.DatatypeDropDownLabel.Text = 'Data type';

            % Create DatatypeDropDown
            app.DatatypeDropDown = uidropdown(app.SelectDatasourceTab);
            app.DatatypeDropDown.Items = {'temporal', 'generation'};
            app.DatatypeDropDown.ValueChangedFcn = createCallbackFcn(app, @DatatypeDropDownValueChanged, true);
            app.DatatypeDropDown.Position = [95 335 243 22];
            app.DatatypeDropDown.Value = 'temporal';

            % Create PutdataingroupsTab
            app.PutdataingroupsTab = uitab(app.TabGroup);
            app.PutdataingroupsTab.Title = '3) Put data in groups';

            % Create DatagroupsoptionalPanel
            app.DatagroupsoptionalPanel = uipanel(app.PutdataingroupsTab);
            app.DatagroupsoptionalPanel.Title = 'Data groups (optional)';
            app.DatagroupsoptionalPanel.Position = [11 13 260 344];

            % Create DatagroupsListBox
            app.DatagroupsListBox = uilistbox(app.DatagroupsoptionalPanel);
            app.DatagroupsListBox.Items = {'group01', 'group02'};
            app.DatagroupsListBox.ValueChangedFcn = createCallbackFcn(app, @DatagroupsListBoxValueChanged, true);
            app.DatagroupsListBox.Position = [12 192 238 122];
            app.DatagroupsListBox.Value = 'group01';

            % Create NewgroupButton
            app.NewgroupButton = uibutton(app.DatagroupsoptionalPanel, 'push');
            app.NewgroupButton.ButtonPushedFcn = createCallbackFcn(app, @NewgroupButtonPushed, true);
            app.NewgroupButton.Position = [12 156 238 27];
            app.NewgroupButton.Text = 'New group';

            % Create DeleteselectedgroupButton
            app.DeleteselectedgroupButton = uibutton(app.DatagroupsoptionalPanel, 'push');
            app.DeleteselectedgroupButton.ButtonPushedFcn = createCallbackFcn(app, @DeleteselectedgroupButtonPushed, true);
            app.DeleteselectedgroupButton.Position = [12 119 238 27];
            app.DeleteselectedgroupButton.Text = 'Delete selected group';

            % Create RenamegroupEditFieldLabel
            app.RenamegroupEditFieldLabel = uilabel(app.DatagroupsoptionalPanel);
            app.RenamegroupEditFieldLabel.HorizontalAlignment = 'right';
            app.RenamegroupEditFieldLabel.Position = [77 44 88 22];
            app.RenamegroupEditFieldLabel.Text = 'Rename group:';

            % Create RenamegroupEditField
            app.RenamegroupEditField = uieditfield(app.DatagroupsoptionalPanel, 'text');
            app.RenamegroupEditField.ValueChangedFcn = createCallbackFcn(app, @RenamegroupEditFieldValueChanged, true);
            app.RenamegroupEditField.Position = [12 20 238 22];

            % Create AssignselectedgroupparamtoallButton
            app.AssignselectedgroupparamtoallButton = uibutton(app.DatagroupsoptionalPanel, 'push');
            app.AssignselectedgroupparamtoallButton.ButtonPushedFcn = createCallbackFcn(app, @AssignselectedgroupparamtoallButtonPushed, true);
            app.AssignselectedgroupparamtoallButton.Position = [12 71 238 38];
            app.AssignselectedgroupparamtoallButton.Text = 'Assign selected group param to all';

            % Create SetplottingoptionsTab
            app.SetplottingoptionsTab = uitab(app.TabGroup);
            app.SetplottingoptionsTab.Title = '4) Set plotting options';

            % Create SetoutputdirTab
            app.SetoutputdirTab = uitab(app.TabGroup);
            app.SetoutputdirTab.Title = '5) Set output dir.';

            % Create PlottingexportdirectoryfigandpdfEditFieldLabel
            app.PlottingexportdirectoryfigandpdfEditFieldLabel = uilabel(app.SetoutputdirTab);
            app.PlottingexportdirectoryfigandpdfEditFieldLabel.HorizontalAlignment = 'right';
            app.PlottingexportdirectoryfigandpdfEditFieldLabel.Position = [8 325 203 22];
            app.PlottingexportdirectoryfigandpdfEditFieldLabel.Text = 'Plotting export directory (.fig and.pdf)';

            % Create PlottingexportdirectoryfigandpdfEditField
            app.PlottingexportdirectoryfigandpdfEditField = uieditfield(app.SetoutputdirTab, 'text');
            app.PlottingexportdirectoryfigandpdfEditField.Position = [226 321 356 29];

            % Create SetdirectoryButton
            app.SetdirectoryButton = uibutton(app.SetoutputdirTab, 'push');
            app.SetdirectoryButton.ButtonPushedFcn = createCallbackFcn(app, @SetdirectoryButtonPushed, true);
            app.SetdirectoryButton.Position = [591 315 91 42];
            app.SetdirectoryButton.Text = 'Set directory...';

            % Create DatasheetexportfilexlsxEditFieldLabel
            app.DatasheetexportfilexlsxEditFieldLabel = uilabel(app.SetoutputdirTab);
            app.DatasheetexportfilexlsxEditFieldLabel.HorizontalAlignment = 'right';
            app.DatasheetexportfilexlsxEditFieldLabel.Position = [9 269 154 22];
            app.DatasheetexportfilexlsxEditFieldLabel.Text = 'Data sheet export file (.xlsx)';

            % Create DatasheetexportfilexlsxEditField
            app.DatasheetexportfilexlsxEditField = uieditfield(app.SetoutputdirTab, 'text');
            app.DatasheetexportfilexlsxEditField.Position = [225 265 354 29];

            % Create SetfileButton
            app.SetfileButton = uibutton(app.SetoutputdirTab, 'push');
            app.SetfileButton.ButtonPushedFcn = createCallbackFcn(app, @SetfileButtonPushed, true);
            app.SetfileButton.Position = [591 262 90 37];
            app.SetfileButton.Text = 'Set file...';

            % Show the figure after all components are created
            app.DataexportingandplottingUIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = detector

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.DataexportingandplottingUIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.DataexportingandplottingUIFigure)
        end
    end
end
