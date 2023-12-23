function [him, hp]=draw(obj,h,classif)

% function used to draw ROIs
% obj is an roi , h is a figure handle n which to draw it
%this function is called by the roi view() method

% updates number of channel if userTraining mode is on.

if nargin<3
    classif=[];
    % refresh='full';
end
% if nargin<4
%     refresh='full';
% end


% % This should work in both HG1 and HG2:
% hManager = uigetmodemanager(h);
% try
%     set(hManager.WindowListenerHandles, 'Enable', 'off');  % HG1
% catch
%     [hManager.WindowListenerHandles.Enabled] = deal(false);  % HG2
% end
% set(h, 'WindowKeyPressFcn', []);
%set(hFig, 'KeyPressFcn', @myKeyPressCallback);

h.Name=['ROI# :' obj.id];




if numel(h.UserData)~=0 % window is already displayed; therefore just update the figure
    him=h.UserData.him;

    hp=findobj(h,'Type','Axes');

    % sort Axes !
    s=[];
    %hp
    for i=1:numel(hp)
        s(i)=str2num(hp(i).Tag(7:end));
    end
    
    [q, ix]=sort(s);
    hp=hp(ix);

    updatedisplay(obj,him,hp,classif);

    return;
end

if numel(classif)>0
    if strcmp(classif.category{1},'Pixel') | strcmp(classif.category{1},'Object') | strcmp(classif.category{1},'Delta')  | strcmp(classif.category{1},'Pedigree')  % display properties for pixel classification

        % first create a decidated channel in the image matrix for pixel
        % classification if it is not exisiting

        %pix=find(classif.roi(i).channelid==classif.channel);

        %[pth fle ex]=fileparts(obj.path); % get the name of the current classification process
        % change here to use the reference to the classif being used

        %         pix = strfind(obj.display.channel, classif.strid);
        %
        %         cc=[];
        %         for i=1:numel(pix)
        %             if numel(pix{i})~=0
        %                 cc=i;
        %
        %                 break
        %             end
        %         end
        %
        %         pixelchannel=i;

        cc=obj.findChannelID(classif.strid);

        if numel(cc)==0 % create new empty array for user training (painting)
            matrix=uint16(zeros(size(obj.image,1),size(obj.image,2),1,size(obj.image,4)));
            obj.addChannel(matrix,classif.strid,[1 1 1],[0 0 0]);

            %pixelchannel=size(obj.image,3);
            %else

        else
            %pixelchannel=cc;

        end

    end


    if strcmp(classif.category{1},'Pedigree')
        ccpedigree=obj.findChannelID(classif.strid);
    end

    obj.display.selectedchannel=zeros(1,numel(obj.display.selectedchannel));

    ps=find(matches(obj.display.channel,classif.channelName));
    if numel(ps)
        obj.display.selectedchannel(ps)=1;
    end

    pix =obj.findChannelID(classif.strid);
    pix= obj.channelid(pix);
    obj.display.selectedchannel(pix)=1;

end


% create display menu %

handles=findobj(h,'Tag','DisplayMenu');

if numel(handles)==0
    m = uimenu(h,'Text','Display','Tag','DisplayMenu');
    mitem=[];

    for i=1:numel(obj.display.channel)
        mitem(i) = uimenu(m,'Text',obj.display.channel{i},'Checked','on','Tag',['channel_' num2str(i)]);
        set(mitem(i),'MenuSelectedFcn',{@displayMenuFcn,obj,h,classif});


        pix=find(obj.channelid==i); % find matrix index associated with channel
        
        pix=pix(1); % there may be several items in case of a   multi-array channel


        % here !!!!!
        if obj.display.selectedchannel(i)==1
            % if obj.display.selectedchannel(pix)==1
            set(mitem(i),'Checked','on');
        else
            set(mitem(i),'Checked','off');
        end

        if numel(classif)>0
            %    set(mitem(i),'Enable','off');
        else

        end
    end
end

% find channel to be displayed
cd=0;

%aa=obj.display.selectedchannel

for i=1:numel(obj.display.channel)
    pix=find(obj.channelid==i); % find matrix index associated with channel
    pix=pix(1); % there may be several items in case of a   multi-array channel


    if obj.display.selectedchannel(i)==1
        %    i
        %   if obj.display.selectedchannel(pix)==1
        cd=cd+1;
    end
end



% create draw menu

handles=findobj(h,'Tag','DrawMenu');

if numel(handles)==0
    dr = uimenu(h,'Text','Draw','Tag','DrawMenu');
    dritem = uimenu(dr,'Text','Add Channel','Tag','AddChannel');
    set(dritem,'MenuSelectedFcn',{@addChannel,obj});

    dritem(2) = uimenu(dr,'Text','Remove Channel','Tag','RemoveChannel');
    set(dritem(2),'MenuSelectedFcn',{@removeChannel,obj});

    dritem(3) = uimenu(dr,'Text','Copy frames between channels','Tag','CopyFrames');
    set(dritem(3),'MenuSelectedFcn',{@copyFrames,obj});

    dritem(4) = uimenu(dr,'Text','Draw object','Tag','Draw object','Separator','on');
    set(dritem(4),'MenuSelectedFcn',{@drawObject,obj});


    if numel(classif)>0
        if strcmp(classif.category{1},'Image')  || strcmp(classif.category{1},'LSTM') % display user training and results

            dr = uimenu(h,'Text','Classification options','Tag','Classification');

            dritem = uimenu(dr,'Text','Assign classes for multiple frames','Tag','FillIn1');
            set(dritem,'MenuSelectedFcn',{@fillInClasses,obj,classif});

            dritem2 = uimenu(dr,'Text','Fill-in unclassified frames with class from last classified frame','Tag','FillIn2');
            set(dritem2,'MenuSelectedFcn',{@fillInClassesTheo,obj,classif});

        end
    end

    %   dritem(5) = uimenu(dr,'Text','Draw cell number for tracked cells','Checked','off','Tag','DrawCellNumber');
    %   set(dritem(5),'MenuSelectedFcn',{@checkCells,obj,h,classif});
end

% build display image object

im=buildimage(obj);

% display corresponding axes

cc=1;
him=[];
%hp=[]; don't initialize axes as doubles, otherwise they don t use the HG2
% formalism

%pos=h.Position;


for i=1:numel(obj.display.channel)

    pix= find( obj.channelid==i);
    pix=pix(1);

    if obj.display.selectedchannel(i)==1
        % if obj.display.selectedchannel(pix)==1
        figure(h);


        if cd>1
            hp(cc)=subplot(1,cd,cc);
        else

            hp(cc)=axes('Units','normalized');
        end

        dis=0;
        % pixelchannel
        if numel(classif)>0
            if strcmp(classif.category{1},'Pixel') | strcmp(classif.category{1},'Object')  | strcmp(classif.category{1},'Delta')  | strcmp(classif.category{1},'Pedigree')   % display user training and results
                % pixelchannel
                %   tmppix=obj.findChannelID(classif.strid);
                %   pix=obj.findChannelID(classif.strid);
                if pix==obj.findChannelID(classif.strid)
                    dis=1;
                end
            end
        end

        if dis==0 %  channel to be displayed is not that of the ongoing classification
            if sum(obj.display.intensity(i,:))==0 % choose colormap to use to plot indexed data
                dis=1;
                %    tp=obj.image(:,:i,:);
                tp=obj.image(:,:,pix,:);
                maxe=double(max(tp(:)));
                %    maxe
                cmap=shallowColormap(maxe);
            end
        end

        if numel(classif)>0
            %'ok'

            cmap=classif.colormap;

            if strcmp(classif.category{1},'Delta')
                tp=obj.image(:,:,pix,:);
                maxe=double(max(tp(:)));
                cmap=shallowColormap(maxe);
            end
        end

        % size(im)

        aa=h.Position;

        if dis==0
            him.image(cc)=imshow(im(cc).data);
        else

            him.image(cc)=imshow(im(cc).data,cmap);
            % 'ok'
            %    return;
        end



        h.Position=aa; % forcing positioning (in case cd==1)

        set(hp(cc),'Tag',['AxeROI' num2str(cc)]);

        set(hp(cc),'UserData',obj.display.channel{i});


        %axis equal square
        %     tt=obj.display.intensity(i,:);

        %         if numel(classif)==0
        %             title(hp(cc),[obj.display.channel{i} ]); %' -Intensity:' num2str(tt)]);
        %         end

        if cd==1 % setting position in case of one axis, to adjust display size
            set(gca,'Position',[0.2 0.2 0.7 0.7]  );
        end

        %   ax=gca;

        %    set(zoom(ax),'ActionPreCallback',@(x,y) myCallbackFcn(ax,h));

        cc=cc+1;
    end
end

if cd>0
    linkaxes(hp);
end

if numel(handles)==0
    if numel(classif)>0


        if strcmp(classif.category{1},'Image')  || strcmp(classif.category{1},'LSTM') % display user training and results

            dritem2 = uimenu(dr,'Text','Correction Mode GT vs Pred','Checked','off','Tag','Correction1');
            set(dritem2,'MenuSelectedFcn',{@correctionMode,obj, him, hp, classif,1});

            dritem2 = uimenu(dr,'Text','Correction Mode Class group','Checked','off','Tag','Correction2');
            set(dritem2,'MenuSelectedFcn',{@correctionMode,obj,him,hp,classif,2});

            dritem2 = uimenu(dr,'Text','Display current classi state on image','Checked','off','Tag','classitextflag');
            set(dritem2,'MenuSelectedFcn',{@setclassitextflag,obj,him,hp,classif});

        end
    end

end


%========POSITION IMAGE=========
%set(h,'Units', 'Normalized','Position',[0 0 1 1]);


h.UserData.him=him;
h.UserData.correctionMode='off';

% reset mouse interaction function
h.WindowButtonDownFcn='';
h.Pointer = 'arrow';
h.WindowButtonMotionFcn = '';
h.WindowButtonUpFcn = '';


% add buttons and fcn to chanfe frame


pth=userpath;
fle= fullfile(pth,'Detecdiv/userprefs.mat');
if exist(fle)
    load(fle) % loads userprefs variable
    keys=textscan(userprefs.roi_view_shortcut_keys,'%s');
    keys=keys{1};
    keys=keys';


    specialkeys={};
    tmp=userprefs.roi_view_corr_shortcut_keys;  tmp=textscan(tmp,'%s');   tmp=tmp{1}; tmp=tmp'; specialkeys{1}=tmp;
    tmp=userprefs.roi_view_bounds_shortcut_keys;  tmp=textscan(tmp,'%s');   tmp=tmp{1}; tmp=tmp'; specialkeys{2}=tmp;
    tmp=userprefs.roi_view_frames_jump_size;  tmp=textscan(tmp,'%s');   tmp=tmp{1}; tmp=tmp'; specialkeys{3}=tmp;
    tmp=userprefs.painting_fill_holes_shortcut;  tmp=textscan(tmp,'%s');   tmp=tmp{1}; tmp=tmp'; specialkeys{4}=tmp;
    tmp=userprefs.painting_transparency_shortcut;  tmp=textscan(tmp,'%s');   tmp=tmp{1}; tmp=tmp'; specialkeys{5}=tmp;

else % structure must me created
    errordlg('Could not file the shortcut preferences; Please reset user preferences before launching this indow again!,Error');
    close
    return;
end

%keys={'a' 'z' 'e' 'r' 't' 'y' 'u' 'i' 'o' 'p'};
h.KeyPressFcn={@changeframe,obj,him,hp,keys,classif,specialkeys,userprefs};

handles=findobj(h,'Tag','frametexttitle');
if numel(handles)==0
    btnSetFrame = uicontrol('Style', 'text','FontSize',10, 'String', 'Frame:',...
        'Position', [50 50 450 20],'HorizontalAlignment','left', ...
        'Tag','frametexttitle') ;
end

handles=findobj(h,'Tag','frametext');
if numel(handles)==0
    btnSetFrame = uicontrol('Style', 'edit','FontSize',10, 'String', num2str(obj.display.frame),...
        'Position', [50 20 80 20],...
        'Callback', {@setframe,obj,him,hp,classif},'Tag','frametext') ;
else
    handles.Callback=  {@setframe,obj,him,hp,classif};
    handles.String=num2str(obj.display.frame);
end


btnSetFrame = uicontrol('Style', 'pushbutton','FontSize',10, 'String', 'Display Settings...',...
        'Position', [150 20 120 40],...
        'Callback', {@displayGUI,obj,him,hp,classif,h},'Tag','displayGUI') ;

btnSetFrame = uicontrol('Style', 'pushbutton','FontSize',10, 'String', 'Plot data',...
        'Position', [300 20 120 40],...
        'Callback', {@plotdata,obj,him,hp,classif,h},'Tag','plotdata') ;

btnSetFrame = uicontrol('Style', 'pushbutton','FontSize',10, 'String', 'Plot settings...',...
        'Position', [450 20 120 40],...
        'Callback', {@plotsettings,obj,him,hp,classif,h},'Tag','plotsettings') ;


% create training specific menus and graphics
% training classes menu

% display user classification status
if numel(classif)>0

    if strcmp(classif.category{1},'Image')  || strcmp(classif.category{1},'LSTM') % display user training and results
%         if numel(obj.train)==0 % new roi , training not yet used
%             obj.train.(classif.strid)=[];
%             obj.train.(classif.strid).id=zeros(1,size(obj.image,4));
%         end

        %         if obj.train(obj.display.frame)==0 % user training
        %             str='not classified';
        %             colo=[0 0 0];
        %
        %         else
        %             str= obj.classes{obj.train(obj.display.frame)};
        %             colo=cmap(obj.train(obj.display.frame),:);
        %         end


        %         cc=1;
        %         for i=1:numel(obj.display.channel)
        %             if obj.display.selectedchannel(i)==1
        %                 tt=hp(cc).Title.String;
        %                 hp(cc).Title.String=[tt ' - ' str ' (training)'];
        %                 %title(hp(cc),str, 'Color',colo,'FontSize',20);
        %                 cc=cc+1;
        %             end
        %         end
    end

    if strcmp(classif.category{1},'Pixel') | strcmp(classif.category{1},'Object')  | strcmp(classif.category{1},'Delta')  | strcmp(classif.category{1},'Pedigree')  % display the axis associated with user training to paint on the channel

        %         pix = strfind(obj.display.channel, classif.strid);
        %         cc=[];
        %         for i=1:numel(pix)
        %             if numel(pix{i})~=0
        %                 cc=i;
        %
        %                 break
        %             end
        %         end

        cc=obj.findChannelID(classif.strid);
        cc= obj.channelid(cc);

        if numel(cc)
            if obj.display.selectedchannel(cc)==1
                % cha1= classif.channelName{1};
                %pix= obj.
                cha1=1;
                % axes where to copy the new axes
                axes(hp(cha1));
                alpha(0.8);

                cha1pos=get(hp(cha1),'Position');
                hcopy=findobj(hp,'UserData',classif.strid);
                %
                htmp = copyobj(hcopy,h);
                htmp.Position=cha1pos;

                if   strcmp(classif.category{1},'Object')  | strcmp(classif.category{1},'Delta')  | strcmp(classif.category{1},'Pedigree');
                    htmp.Children.CData= htmp.Children.CData;
                end

                % aa=classif.strid,
                %  h.Childr

                set(htmp,'Tag',classif.strid);
                axes(htmp);
                alpha(0.2);

                linkaxes([hp htmp]);
            end
        end

    end


    if strcmp(classif.category{1},'Pixel') | strcmp(classif.category{1},'Object') | strcmp(classif.category{1},'Image')  | strcmp(classif.category{1},'LSTM')
        % plotting classes menu for classification


        handles=findobj('Tag','TrainingClassesMenu');

        if numel(handles)~=0
            delete(handles)
        end

        m = uimenu(h,'Text',[classif.category{1} 'Training Classes'],'Tag','TrainingClassesMenu');
        mitem=[];

        hpaint=findobj('Tag',classif.strid); % if the painting axe is displayed

        for i=1:numel(classif.classes)
            %  cmap
            %aa=keys{i}
            %bb=cmap(i+1,:)


            mitem(i) = uimenu(m,'Text',obj.classes{i},'Checked','off','Tag',['classes_' num2str(i)],'ForegroundColor',cmap(i+1,:),'Accelerator',keys{i});

            if strcmp(classif.category{1},'Pixel') | strcmp(classif.category{1},'Object') % only in pixel mode

                if numel(hpaint)~=0

                    set(mitem(i),'MenuSelectedFcn',{@classesMenuFcn,h,obj,hpaint.Children(1),hcopy.Children(1),hpaint,classif,userprefs});

                end
            end

            %         if strcmp(classif.category{1},'Object') % only in object mode
            %             hpaint=findobj('Tag',classif.strid); % if the painting axe is displayed
            %             if numel(hpaint)~=0
            %                 set(mitem(i),'MenuSelectedFcn',{@classesMenuFcnObject,h,obj,hpaint.Children(1),hcopy.Children(1),hpaint,classif});
            %
            %             end
            %         end

            %     if obj.display.selectedchannel(i)==1
            %         set(mitem(i),'Checked','on');
            %     else
            %         set(mitem(i),'Checked','off');
            %     end
        end

        % change keypressfcn if painting is allowed to allow more functions
        %

        % here

        if strcmp(classif.category{1},'Pixel') | strcmp(classif.category{1},'Object')  | strcmp(classif.category{1},'Delta')  | strcmp(classif.category{1},'Pedigree') % only in pixel mode
            h.KeyPressFcn={@changeframe,obj,him,hp,keys,classif,specialkeys,userprefs,hpaint.Children(1),hcopy.Children(1),hpaint};
        else
            h.KeyPressFcn={@changeframe,obj,him,hp,keys,classif,specialkeys,userprefs};
        end
    end

    if strcmp(classif.category{1},'Pedigree') % Pedigree analysis
        % nothing here to do
        hpaint=findobj(hp,'UserData',classif.strid);
        ccpedigree=obj.findChannelID(classif.strid);
        set(h,'WindowButtonDownFcn',{@pedigree,h,hpaint,obj,ccpedigree,hp,classif});%%% HERE

        plotLinks(obj,hp,classif);

    end

    if strcmp(classif.category{1},'LSTM Regression') || strcmp(classif.category{1},'Image Regression') % Regression training analysis
        %ccpedigree=obj.findChannelID(classif.strid);
        set(h,'WindowButtonDownFcn',{@regression,h,obj,him,hp,classif});%%% HERE

        %  plotLinks(obj,hp,classif);
    end

    if strcmp(classif.category{1},'Delta') % | strcmp(classif.category{1},'Delta')
        hpaint=findobj('Tag',classif.strid);
        % if the painting axe is displayed
        if numel(hpaint)
            set(h,'WindowButtonDownFcn',{@wbdcb_delta,obj,hpaint.Children(1),hcopy.Children(1),hpaint,classif,him,hp});
        end

        % create text field to input cell number

        handles=findobj(h,'Tag','celltexttitle');
        if numel(handles)==0
            btnSetFrame = uicontrol('Style', 'text','FontSize',10, 'String', 'Cell #',...
                'Position', [50 350 50 20],'HorizontalAlignment','left', ...
                'Tag','celltexttitle') ;
        end

        handles=findobj(h,'Tag','celltext');
        if numel(handles)==0
            btnSetFrame = uicontrol('Style', 'edit','FontSize',14, 'String', '-',...
                'Position', [50 300 50 20],...
                'Callback', {@setcell,obj,hpaint,classif,him,hp},'Tag','celltext') ;
        else
            handles.Callback=  {@setcell,obj,hpaint,classif,him,hp};
            handles.String='-';
        end

    end

    plotdata(handles, '', obj,him,hp,classif,h); % plot data for user annotation 
end

% display results for image classification & plot tracking results if
% available

cc=1;

% delete text handle if present
htext=findobj(gcf,'Tag','tracktext');

if numel(htext)>0
    if ishandle(htext)
        delete(htext);
    end
end

htextclassi=findobj(gcf,'Tag','classitext');

if numel(htextclassi)>0
    if ishandle(htextclassi)
        delete(htextclassi);
    end
end

updatedisplay(obj,him,hp,classif)

end

%  function checkCells(handles, event,obj,h,classif)
%  if strcmp(handles.Checked,'on')
%  set(handles,'Checked','off')
%  else
%  set(handles,'Checked','on')
%  end
%
%clf
%h.UserData=[];
%[him hp]=draw(obj,h,classif);

%obj.view;
% end

function addChannel(handles, event,obj)
matrix=uint16(zeros(size(obj.image,1),size(obj.image,2),1,size(obj.image,4)));
rgb=[1 1 1];
intensity=[0 0 0];
answer = inputdlg({'Channel Name','RGB','Intensity'},'New CHannel',1,{'mychannel','[1 1 1]','[0 0 0]'});

if numel(answer)==0
    return;
end

h=findobj('Tag',['ROI' obj.id]);
close(h);
obj.addChannel(matrix,answer{1},str2num(answer{2}),str2num(answer{3}));

disp(['update stretchlim: ' num2str(obj.id) ', computing them...']);
obj.computeStretchlim;

obj.view;
end

function removeChannel(handles, event,obj)

h=findobj('Tag',['ROI' obj.id]);
h.UserData.selection=[];


fig = uifigure('Position',[100 100 300 150],'UserData',h,'Name','Select channel:');
dd = uidropdown(fig,'Items', obj.display.channel,...
    'Position',[10, 120, 200, 32],...
    'Value', obj.display.channel{1},...
    'ValueChangedFcn',@(dd,event) selection(dd,fig));

btn = uibutton(fig,'push',...
    'Position',[10, 10, 100, 22],'Text','Proceed',...
    'ButtonPushedFcn', @(btn,event) plotButtonPushed(btn,fig));

% Create the function for the ButtonPushedFcn callback
    function plotButtonPushed(btn,fig)
        close(fig)
    end

    function selection(dd,fig)
        val = dd.Value;
        fig.UserData.UserData.selection = val;
    end

uiwait(fig);

sele=h.UserData.selection;

if numel(sele)
    close(h);

    obj.removeChannel(sele);
    obj.view;
end

end

function copyFrames(handles, event,obj)

h=findobj('Tag',['ROI' obj.id]);
h.UserData.copyframes={obj.display.channel{1} obj.display.channel{1} num2str(obj.display.frame) num2str(obj.display.frame) };

fig = uifigure('Position',[100 100 350 150],'UserData',h,'Name','Copy frames:');

lab=uilabel(fig,'Position',[10, 120, 100, 22],'Text','From channel::');
lab=uilabel(fig,'Position',[180, 120, 100, 22],'Text','To channel::');


dd1 = uidropdown(fig,'Items', obj.display.channel,...
    'Position',[10, 100, 150, 22],...
    'Value', obj.display.channel{1},...
    'ValueChangedFcn',@(dd,event) selection(dd,fig,1));

dd2 = uidropdown(fig,'Items', obj.display.channel,...
    'Position',[180, 100, 150, 22],...
    'Value', obj.display.channel{1},...
    'ValueChangedFcn',@(dd2,event) selection(dd2,fig,2));

lab=uilabel(fig,'Position',[10, 80, 120, 22],'Text','Source frames:');

txt = uieditfield(fig,...
    'Value', num2str(obj.display.frame), 'Position',[40 60 100 22],...
    'ValueChangedFcn',@(txt,event) selection(txt,fig,3));


lab=uilabel(fig,'Position',[140, 80, 120, 22],'Text','Destination frames:');

txt2 = uieditfield(fig,...
    'Value', num2str(obj.display.frame), 'Position',[190 60 100 22],...
    'ValueChangedFcn',@(txt,event) selection(txt,fig,4));

% Code the callback function

btn = uibutton(fig,'push',...
    'Position',[10, 10, 100, 22],'Text','Proceed',...
    'ButtonPushedFcn', @(btn,event) plotButtonPushed(btn,fig));


% Create the function for the ButtonPushedFcn callback
    function plotButtonPushed(btn,fig)
        fig.UserData.UserData.copyframes{5}='ok';
        close(fig)
    end

% drop down selection function
    function selection(dd,fig,id)
        val = dd.Value;
        fig.UserData.UserData.copyframes{id} = val;
    end

uiwait(fig);

sele=h.UserData.copyframes;

if numel(sele)==5

    pix1=obj.findChannelID(sele{1});
    pix2=obj.findChannelID(sele{2});
    fr1=str2num(sele{3});
    fr2=str2num(sele{4});

    obj.image(:,:,pix2,fr2)=obj.image(:,:,pix1,fr1);

    close(h);
    %
    %     obj.removeChannel(sele);
    obj.view;
end

end

function fillInClasses(handles, event,obj, classif)

if numel(obj.classes)==0
    disp('there are no classes in this roi !');
    return;
end

h=findobj('Tag',['ROI' obj.id]);

listdata={obj.data.groupid};
pixdata=find(matches(listdata,classif.strid));

if numel(pixdata)
id=obj.data(pixdata).getData('id_training');
else
    return;
end

%id=obj.train.(classif.strid).id;

idframe=id(obj.display.frame);

if idframe==0
    idframe=1;
end

h.UserData.classframes={obj.classes{idframe}   num2str(obj.display.frame) num2str(size(obj.image,4)) };


fig = uifigure('Position',[100 100 350 150],'UserData',h,'Name','Fill in classes in frames:');

lab=uilabel(fig,'Position',[10, 120, 100, 22],'Text','Class: :');

dd1 = uidropdown(fig,'Items', obj.classes,...
    'Position',[10, 100, 150, 22],...
    'Value', obj.classes{idframe},...
    'ValueChangedFcn',@(dd,event) classselection(dd,fig,1));

lab=uilabel(fig,'Position',[10, 80, 120, 22],'Text','Start frame:');

txt = uieditfield(fig,...
    'Value', num2str(obj.display.frame), 'Position',[40 60 100 22],...
    'ValueChangedFcn',@(txt,event) classselection(txt,fig,2));


lab=uilabel(fig,'Position',[140, 80, 120, 22],'Text','End frame:');

txt2 = uieditfield(fig,...
    'Value', num2str(size(obj.image,4)), 'Position',[190 60 100 22],...
    'ValueChangedFcn',@(txt,event) classselection(txt,fig,3));

% Code the callback function

btn = uibutton(fig,'push',...
    'Position',[10, 10, 100, 22],'Text','Proceed',...
    'ButtonPushedFcn', @(btn,event) classButtonPushed(btn,fig));


% Create the function for the ButtonPushedFcn callback
    function classButtonPushed(btn,fig)
        fig.UserData.UserData.classframes{4}='ok';
        close(fig)
    end

% drop down selection function
    function classselection(dd,fig,id)
        val = dd.Value;
        fig.UserData.UserData.classframes{id} = val;
    end

uiwait(fig);

sele=h.UserData.classframes;

if numel(sele)==4

    pix1=find(matches(obj.classes,sele{1}));
    fr1=str2num(sele{2});
    fr2=str2num(sele{3});

    obj.train.(classif.strid).id(fr1:fr2)=pix1;

     pix=fr1:fr2;
              % li=findobj(htraj(j),'Tag',[obj.id '_track']);
              % data=li.UserData;
              % classes=data.userData.classes;

              htraj=findobj('Type','Figure');
              for j=1:numel(htraj)

                     z= htraj(j).Name;

                      if contains(z,obj.id)

                     li=findobj(htraj(j),'Tag',[obj.id '_track']);

                        if numel(li)==0
                       continue
                        end

                      
               training_pixdata=find(arrayfun(@(x) strcmp(x.groupid, classif.strid),obj.data)); % find if object exists already
               if numel(training_pixdata)
                    training_data=obj.data(training_pixdata);
               end

               classes=training_data.userData.classes;

               tmp=training_data.data.('labels_training');
               tmp(pix)=categorical(classes(pix1));
               training_data.data.('labels_training')=tmp;

               hpp=findobj(htraj(j),'Tag','labels_training');
               hpp.YData=tmp;

               tmp=training_data.data.('id_training');
               tmp(pix)=pix1;
               training_data.data.('id_training')=tmp;

               obj.data(training_pixdata)=training_data;
                      end
              end



    close(h);

    %
    %    obj.removeChannel(sele);
    %   obj.view;

    obj.view(obj.display.frame,classif);
end

end

function fillInClassesTheo(handles, event,obj, classif)


if numel(obj.classes)==0
    disp('there are no classes in this roi !');
    return;
end

h=findobj('Tag',['ROI' obj.id]);

obj.fillTraining('Training',classif.strid);
close(h);
obj.view(obj.display.frame,classif);

end

function displayGUI(handles, event, obj,him,hp,classif,h)

ROIdisplayGUI(obj,him,hp,classif,h);

end

function plotdata(handles, event, obj,him,hp,classif,h)

data=obj.data;



% find if roi is already displayed 
  hroi=findobj('Tag',['ROI' obj.id]);
% 
  if numel(hroi) 
      pos=hroi.Position;
      %pos(2)=pos(2)-pos(4);
  else
      pos=[0.1 0.1 0.25 0.25];
  end

cc=0;

if numel(data)==1 & numel(data(1).data)==0
    disp('No data available to display');
    return
end

if numel(classif)==0 % plots all requested data when no classifier is provided 

for i=1:numel(data)
 if data(i).show
       
n=0;
cc=cc+1;
groups=data(i).plotGroup{6};

for j=1:numel(groups)

    pix=contains(data(i).plotProperties(:,end),string(groups{j}));
    pix2=cellfun(@(x) x(:,1)==true, data(i).plotProperties(:,1));

    pix=find(pix & pix2); % id of plots to be displayed indenpendlty 

    if numel(pix)
        n=n+1;
    end

end

pos(2)=pos(2)-n*0.15;
data(i).plot(pos);
 end
end

else % user annotation mode with function classif

   pixdata=find(arrayfun(@(x) strcmp(x.groupid, classif.strid),data)); % find if object exists already

        %
        if numel(pixdata)
            cc=pixdata(1); 
            pos(2)=pos(2)-1*0.25;
            ind=find(contains(data(cc).data.Properties.VariableNames,"labels_training"));

            if numel(ind)==0 % must create the array 

            else

            end

            
            data(cc).plotProperties(:,1)={false};
            data(cc).plotProperties(ind,1)={true};
            data(cc).show=true;
            data(cc).plot(pos,'classif');

            
        else
%             n=numel(dataout);
%             if n==1 & numel(dataout.data)==0
%                 cc=1; % replace empty dataset
%             else
%                 cc=numel(dataout)+1;
%             end
        end
end

figure(hroi);

end

function plotsettings(handles, event, obj,him,hp,classif,h)

data=obj.data; 
DataPlotGUI(data,obj);

end

function correctionMode(handles, event,obj, him,hp,classif,mode)

h=findobj('Tag',['ROI' obj.id]);

ha=findobj('Tag',['Correction' num2str(mode)]);

if numel(ha)
    if strcmp(ha.Checked,'on')
        set(ha,'Checked','off');
        h.UserData.correctionMode='off';
    else
        set(ha,'Checked','on');
        h.UserData.correctionMode=num2str(mode);

        ha=findobj('Tag',['Correction' num2str(2-mode+1)]);
        set(ha,'Checked','off');

        if mode==2 % sort frames
            if isfield(obj.train,classif.strid)
                if numel(obj.train.(classif.strid).id)>0
                    if isfield(obj.results,classif.strid)
                        if numel(obj.results.(classif.strid).id)>0
                            [aa2,pix]=sort(obj.train.(classif.strid).id);
                            h.UserData.correctionSort=pix;
                        end
                    end
                end
            end
        end
    end
end

updatedisplay(obj,him,hp,classif)
% HERE :
end

function setclassitextflag(handles, event,obj, him,hp,classif)

h=findobj('Tag',['ROI' obj.id]);

ha=findobj('Tag','classitextflag');

if numel(ha)
    if strcmp(ha.Checked,'on')
        set(ha,'Checked','off');
    else
        set(ha,'Checked','on');
    end
end

updatedisplay(obj,him,hp,classif)
% HERE :
end

function drawObject(handles, event,obj)

cha=1;
answer = inputdlg({'Channel id on which to draw ?'},'Draw',1,{num2str(cha)});

if numel(answer)==0
    return;
end

h=findobj('Tag',['ROI' obj.id]);

hp=findobj(h,'Tag','AxeROI1');

xc=size(obj.image,2)/2;
yc=size(obj.image,1)/2;
sizx=40;
sizy=30;

windo=[xc-sizx yc-sizy 2*sizx 2*sizy];
roi = imellipse(hp,windo);
inputpoly = wait(roi);
delete(roi);

BW=poly2mask(inputpoly(:,1),inputpoly(:,2),size(obj.image,1),size(obj.image,2));
BW=repmat(BW,[1 1 1 size(obj.image,4)]);

obj.image(:,:,str2num(answer{1}),:)=uint16(obj.image(:,:,str2num(answer{1}),:) | BW);
%h=findobj('Tag',['ROI' obj.id]);
%close(h);
obj.view;
end


function pedigree(handles, event,h,hpaint,obj,ccpedigree,hp,classif)

cp = hpaint.CurrentPoint;

xinit = cp(1,1);
yinit = cp(1,2);

im=obj.image(:,:,ccpedigree,obj.display.frame);

daughter=0;
% find object if any is selected
if yinit>0 && xinit>0 && xinit< size(im,2)+1 && yinit<size(im,1)+1
    daughter= im(round(yinit),round(xinit));
end

if daughter==0
    return;
end

bw=im==daughter;
stat=regionprops(bw,'Centroid');

xinit=stat(1).Centroid(1);
yinit=stat(1).Centroid(2);

hl = line('XData',[xinit xinit],'YData',[yinit yinit], 'Marker','p','color','w','LineWidth',3);

%hl= annotation('arrow',[xinit xinit],[yinit yinit],'Color',[1 1 1],'Units','pixels');
% hl = line('XData',xinit,'YData',yinit,...
% 'Marker','p','color','b');
handles.WindowButtonMotionFcn = {@wmp,1};
handles.WindowButtonUpFcn = @wup;

x=1;
y=1;


    function wmp(src,event,bsize)
        cp = hpaint.CurrentPoint;

        x = cp(1,1);
        y = cp(1,2);

        set(hl,'XData',[xinit x],'YData',[yinit y]);
        %hl.X=[xinit x];
        %hl.Y=[xinit y];
    end

    function wup(src,callbackdata)
        last_seltype = src.SelectionType;
        src.Pointer = 'arrow';
        src.WindowButtonMotionFcn = '';
        src.WindowButtonUpFcn = '';

        if ishandle(hl)
            delete(hl);
        end

        mother= im(round(y),round(x));

        % if mother==0
        %
        %  return;
        % end

        %             bw=im==mother;
        %             stat=regionprops(bw,'Centroid');
        %
        %             xinit=stat(1).Centroid(1);
        %             yinit=stat(1).Centroid(2);
        %mother,daughter
        str=hpaint.UserData;

        %pix=find(
        obj.train.(str).mother(daughter)=mother;


        if numel(obj.train.(str).mother)>=mother & mother>0
            if obj.train.(str).mother(mother)==daughter
                obj.train.(str).mother(mother)=0;
            end
        end
        %pix=find(
        %obj.train.(str).mother(mother)=mother;

        plotLinks(obj,hp,classif)
    end
end

function classesMenuFcn(handles, event, h,obj,impaint1,impaint2,hpaint,classif,userprefs)

if strcmp(handles.Checked,'off')

    for i=1:numel(classif.classes)
        ha=findobj('Tag',['classes_' num2str(i)]);

        if numel(ha)
            ha.Checked='off';
        end
    end

    handles.Checked='on';
    %aa=handles.Tag
    %str=replace(handles.Tag,'classes_','');
    %colo=str2num(str);

    tz=zoom(h);
    tp=pan(h);

    if strcmp(tz.Enable,'on')  || strcmp(tp.Enable,'on')
        %  disp('not available,  set zoom and pan will be set off');
        tz.Enable='off';
        tp.Enable='off';
        % return;
    end

    handles.Checked='on';


    % set pixel painting mode
    if strcmp(classif.category{1},'Pixel')
        set(h,'WindowButtonDownFcn',{@wbdcb,obj,impaint1,impaint2,hpaint,classif,h,userprefs});
    end

    if strcmp(classif.category{1},'Object') % | strcmp(classif.category{1},'Delta')
        set(h,'WindowButtonDownFcn',{@wbdcb2,impaint1,impaint2,h});
    end

    %ah = hp(1); %axes('SortMethod','childorder');
else

    handles.Checked='off';
    str=handles.Tag;

    h.WindowButtonDownFcn='';
    h.Pointer = 'arrow';
    h.WindowButtonMotionFcn = '';
    h.WindowButtonUpFcn = '';
    figure(h); % set focus
end

%[him hp]=draw(obj,h,classif);


% nested function, good luck ;-) ....

end






function regression(handles,event,h,obj,him,hp,classif)

cp = get(hp,'CurrentPoint');

xinit = cp(1,1);
yinit = cp(1,2);

%         im=obj.image(:,:,ccpedigree,obj.display.frame);
%
%         daughter=0;
%         % find object if any is selected
%         if yinit>0 && xinit>0 && xinit< size(im,2)+1 && yinit<size(im,1)+1
%             daughter= im(round(yinit),round(xinit));
%         end
%
%         if daughter==0
%             return;
%         end
%
%         bw=im==daughter;
%         stat=regionprops(bw,'Centroid');
%
%         xinit=stat(1).Centroid(1);
%         yinit=stat(1).Centroid(2);

hl = line('XData',[xinit xinit],'YData',[yinit yinit], 'Marker','p','color','w','LineWidth',3);

%hl= annotation('arrow',[xinit xinit],[yinit yinit],'Color',[1 1 1],'Units','pixels');
% hl = line('XData',xinit,'YData',yinit,...
% 'Marker','p','color','b');
handles.WindowButtonMotionFcn = {@wmp,1};
handles.WindowButtonUpFcn = @wup;

x=1;
y=1;

    function wmp(src,event,bsize)
        % cp = hpaint.CurrentPoint;
        cp = get(hp,'CurrentPoint');

        x = cp(1,1);
        y = cp(1,2);

        set(hl,'XData',[xinit x],'YData',[yinit y]);
        %hl.X=[xinit x];
        %hl.Y=[xinit y];
    end

    function wup(src,callbackdata)
        last_seltype = src.SelectionType;
        src.Pointer = 'arrow';
        src.WindowButtonMotionFcn = '';
        src.WindowButtonUpFcn = '';


        if ishandle(hl)

            ax=hl.XData;
            ay=hl.YData;

            delete(hl);
        end

        dist=sqrt((ax(2)-ax(1)).^2+(ay(2)-ay(1)).^2);
        %mother= im(round(y),round(x));

        %            str=hpaint.UserData;

        obj.train.(classif.strid).id(obj.display.frame)=floor(dist);

        updatedisplay(obj,him,hp,classif)
        %             if numel(obj.train.(str).mother)>=mother & mother>0
        %                 if obj.train.(str).mother(mother)==daughter
        %                     obj.train.(str).mother(mother)=0;
        %                 end
        %             end
        %pix=find(
        %obj.train.(str).mother(mother)=mother;

        % plotLinks(obj,hp,classif)
    end
end

function displayMenuFcn(handles, event, obj,h,classif)

if strcmp(handles.Checked,'off')
    handles.Checked='on';
    str=handles.Tag;
    i = str2num(replace(str,'channel_',''));
    pix=find(obj.channelid==i); % find matrix index associated with channel
    pix=pix(1); % there may be several items in case of a   multi-array channel

    obj.display.selectedchannel(i)=1;
    % aa=obj.display.selectedchannel(i)
else

    if numel(find(obj.display.selectedchannel))==1 % quit if only one channel was selected
        return;
    end

    handles.Checked='off';
    str=handles.Tag;
    i = str2num(replace(str,'channel_',''));

    pix=find(obj.channelid==i); % find matrix index associated with channel
    pix=pix(1); % there may be several items in case of a   multi-array channel

    obj.display.selectedchannel(i)=0;
    %  bb=obj.display.selectedchannel(i)
end

clf
h.UserData=[];
[~, ~]=draw(obj,h,classif);
end



%return;
%axes(hp(1));

function plotLinks(obj,hp,classif)
mother=obj.train.(classif.strid).mother;

hmother=findobj('Tag','mothertag');
hmother2=findobj('Tag','mothertag2');

hpt=findobj(hp,'UserData',classif.strid);
hpt=findobj(hpt,'Type','Image');

imtmp=hpt.CData;
%imtmp=im(cc).data;

if numel(hmother)>0
    if ishandle(hmother)
        delete(hmother);
    end
end
if numel(hmother2)>0
    if ishandle(hmother2)
        delete(hmother2);
    end
end

for i=1:numel(mother)
    if mother(i)~=0

        bw=imtmp==i;
        bw2=imtmp==mother(i);

        stat=regionprops(bw,'Centroid');
        stat2=regionprops(bw2,'Centroid');

        if numel(stat)==1 && numel(stat2)==1
            x1=stat(1).Centroid(1);
            y1=stat(1).Centroid(2);

            x2=stat2(1).Centroid(1);
            y2=stat2(1).Centroid(2);

            hmother(i)=line([x1 x2],[y1 y2],'Color',[0.9 0.9 0.9],'Tag','mothertag','LineWidth',3);

            x=x2+0.8*(x1-x2);
            y=y2+0.8*(y1-y2);

            hmother2(i)=line([x x],[y y],'Color',[0.9 0.9 0.9],'Tag','mothertag2','LineWidth',3,'Marker','o','MarkerSize',10);
        end
        % HERE

    end
end
end

function plotLinksResults(obj,hp,strid)
mother=obj.results.(strid).mother;


hmother=findobj('Tag','mothertagresults');
hmother2=findobj('Tag','mothertagresults2');

%hpt=findobj(hp,'UserData',['results_' strid]);
hpt=findobj(hp,'UserData',[strid]);
hpt=findobj(hpt,'Type','Image');

imtmp=hpt.CData;
%imtmp=im(cc).data;

if numel(hmother)>0
    if ishandle(hmother)
        delete(hmother);
    end
end
if numel(hmother2)>0
    if ishandle(hmother2)
        delete(hmother2);
    end
end

for i=1:numel(mother)
    if mother(i)~=0
        bw=imtmp==i;
        bw2=imtmp==mother(i);
        stat=regionprops(bw,'Centroid');
        stat2=regionprops(bw2,'Centroid');

        if numel(stat)==1 && numel(stat2)==1
            x1=stat(1).Centroid(1);
            y1=stat(1).Centroid(2);
            x2=stat2(1).Centroid(1);
            y2=stat2(1).Centroid(2);

            hmother(i)=line([x1 x2],[y1 y2],'Color',[0.5 0.5 0.5],'Tag','mothertagresults','LineWidth',3);

            x=x2+0.8*(x1-x2);
            y=y2+0.8*(y1-y2);

            hmother2(i)=line([x x],[y y],'Color',[0.5 0.5 0.5],'Tag','mothertagresults2','LineWidth',3,'Marker','o','MarkerSize',10);
        end
        % HERE

    end
end
end


function setcell(handle,event,obj,hpaint,classif,him,hp )
to=findobj(handle,'Tag','celltext');
txt=str2num(to.String);
setcell_low(handle,event,obj,hpaint,classif,him,hp,txt );
end




function setframe(handle,event,obj,him,hp,classif )
frame=str2num(handle.String);
if frame<=size(obj.image,4) & frame > 0
    obj.display.frame=frame;
    updatedisplay(obj,him,hp,classif)
end
end


