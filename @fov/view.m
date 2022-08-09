function view(obj,frame,option,callingApp)


if nargin>=2
    obj.display.frame=frame;
end

frame=obj.display.frame;

%findobj('Tag',['Trap' num2str(obj.id)])

if numel(obj.channel) ~= numel(obj.display.selectedchannel)
    obj.display.selectedchannel=ones(1,numel(obj.channel));
end

rebuild=0;

h=[];

if nargin>=3
    h=option;
    rebuild=1;
    %  'oki'
end

if nargin>=4
    h=[];
    rebuild=1;
end



if numel(findobj('Tag',['Fov' obj.id])) && rebuild==0% handle exists already
    h=findobj('Tag',['Fov' obj.id]);

    hp=findobj(h,'Type','Axes');

    him=h.UserData.handle;

else


    im=buildimage(obj); % returns a structure with all images to be displayed

    warning off all
    if numel(im.data)==0
        disp('Could not load image. Quitting...');
        return;
    end
    warning on all;


    if numel(h)==0
        %    'ok'
        h=figure('Tag',['Fov' obj.id],'Position',[100 100 800 600]);
       
        if nargin>=4
       h.UserData.callingApp=callingApp;
        else
h.UserData.callingApp=[];
        end
    end

    str={};

    mchannel = uimenu(h,'Text','Channels','Tag','ChannelMenu');

    cc=1;

    tot=sum( obj.display.selectedchannel);
    for i=1:obj.channels

        mitemch(i) = uimenu(mchannel,'Text',obj.channel{i},'Checked','on','Tag',['channel_' num2str(i)]);
        set(mitemch(i),'MenuSelectedFcn',{@displayMenuFcn,obj,h});

        if obj.display.selectedchannel(i)==1




            hp(cc)=subplot(1,tot,cc);

            him.image(cc)=imshow(im(i).data,[]);

            set(hp(cc),'Tag',['Axe' num2str(cc)]);

            %axis equal square

            title(hp(cc),[obj.channel{i} '-Intensity:' num2str(obj.display.intensity(i))],'Interpreter','None');

            str{cc}=[obj.channel{i}];

            cc=cc+1;
        else
            set(mitemch(i),'Checked','off');
        end
    end

    linkaxes(hp);


    % create display menu


    %creat zoom callbackas
    hCMZ = uicontextmenu;
    hZMenu = uimenu('Parent',hCMZ,'Label','Reset Zoom',...
        'Callback',{@resetZoom,obj,him,hp});
    hZMenu = uimenu('Parent',hCMZ,'Label','Switch to pan',...
        'Callback','pan(gcbf,''on'')');
    hZMenu = uimenu('Parent',hCMZ,'Label','Add current ROI',...
        'Callback',{@addROI,obj,him,hp});
    hZMenu = uimenu('Parent',hCMZ,'Label','Adjust current zoom...',...
        'Callback',{@setROIValue,obj,him,hp,0});


    hZoom = zoom(h);
    hZoom.UIContextMenu = hCMZ;
    hZoom.ActionPostCallback={@adjustROI,hp};

    hPan=pan(h);
    hPan.UIContextMenu = hCMZ;
    hPan.ActionPostCallback={@adjustROI,hp};




    h.Position(3)=600*obj.channels;
    h.Position(4)=600;

    h.UserData.handle=him;

    h.KeyPressFcn={@changeframe,obj,him,hp};

    h.WindowButtonDownFcn={@deselectROI,obj,him,hp};

    h.Name= ['FOV ' obj.id];

    %     btnSetFrame = uicontrol('Style', 'text','FontSize',18, 'String',  ,...
    %         'Position', [50 550 200 20],'HorizontalAlignment','left', ...
    %         'Tag','frametexttitle') ;

    btnSetFrame = uicontrol('Style', 'text','FontSize',10, 'String', 'Set frame, or use arrows <- ->',...
        'Position', [20 100 200 20],'HorizontalAlignment','left', ...
        'Tag','frametexttitle') ;

    btnSetFrame = uicontrol('Style', 'edit','FontSize',10, 'String', num2str(obj.display.frame),...
        'Position', [20 70 50 20],...
        'Callback', {@setframe,obj,him,hp},'Tag','frametext') ;


   btnSetROI = uicontrol('Style', 'pushbutton','FontSize',9, 'String','Zoom to set ROI',...
       'Position', [20 300 100 40],...
        'Callback','zoom(gcbf,''on'')','Tag','roitext','Tooltip','Press this button to zoom on the image before setting an ROI') ;

      btnSetROI = uicontrol('Style', 'pushbutton','FontSize',9, 'String','Set ROI',...
       'Position', [20 250 100 40],...
        'Callback',{@addROI,obj,him,hp},'Tag','roitext','Tooltip','Press this button to set a new ROI based on the current filed of view') ;

       btnSetROI = uicontrol('Style', 'pushbutton','FontSize',8, 'String','Set ROI as ref pattern',...
       'Position', [20 200 100 40],...
        'Callback',{@selectPattern,obj,him,hp,1},'Tag','roitext','Tooltip','Press this button to set the selected ROI as a reference pattern for automated ROI detection') ;

     btnSetROI = uicontrol('Style', 'pushbutton','FontSize',8, 'String','Close',...
       'Position', [20 150 100 40],...
        'Callback',{@closeWindow,h},'Tag','roitext','Tooltip','Press this button to close the window') ;

     %  btnSetROI = uicontrol('Style', 'pushbutton','FontSize',10, 'String','Set ROI',...
    %   'Position', [20 150 100 40],...
    %    'Callback',{@addROI,obj,him,hp},'Tag','roitext') ;

    %         btnSetCrop = uicontrol('Style', 'pushbutton','FontSize',14, 'String', 'set crop',...
    %         'Position', [50 80 80 20],...
    %         'Callback', {@setCrop,obj,him,hp},'Tag','setCrop') ;


    %         hZMenu = uimenu('Parent',hCMZ,'Label','Set cropping area',...
    %     'Callback',{@setCrop,obj,him,hp});


    A = cell(1,2);
    A{1,1} = 'Intensity adjust using';
    A{1,2} = 'up and down arrow keys for channel:';
    mls = sprintf('%s\n%s',A{1,1},A{1,2});

    btnSetFrame = uicontrol('Style', 'text','FontSize',10, 'String', mls,...
        'Position', [20 40 200 20],'HorizontalAlignment','left', ...
        'Tag','frametexttitle') ;

    btnSetFrame = uicontrol('Style', 'popupmenu','FontSize',10, 'String', str, 'Value',1,...
        'Position', [20 10 200 20],...
        'Callback', {@setchannel,obj,him,hp},'Tag','channelmenu') ;


    m = uimenu(h,'Text','Display options','Tag','DisplayROIMenu');

    mitem = uimenu(m,'Text','Display ROIs','Checked','on','Tag','drawROIs');

    set(mitem,'MenuSelectedFcn',{@displayROI,obj,him,hp});

    mitem2 = uimenu(m,'Text','Set/Show cropping area to exclude ROIs','Tag','setCrop','Separator','on');

    set(mitem2,'MenuSelectedFcn',{@setCrop,obj,him,hp});

    hZMenu = uimenu(m,'Label','Reset Zoom to default',...
        'Callback',{@resetZoom,obj,him,hp},'Separator','on');

    hZMenu = uimenu(m,'Label','Switch to pan mode',...
        'Callback','pan(gcbf,''on'')');

    hZMenu = uimenu(m,'Label','Switch to zoom mode',...
        'Callback','zoom(gcbf,''on'')');

    hZMenu = uimenu(m,'Label','Adjust current zoom',...
        'Callback',{@setROIValue,obj,him,hp,0});

    hZMenu = uimenu(m,'Label','Add ROI for current window',...
        'Callback',{@addROI,obj,him,hp},'Separator','on');

    hZMenu = uimenu(m,'Label','Clear all ROIs',...
        'Callback',{@clearROI,obj,him,hp});

    hZMenuO(1) = uimenu(m,'Label','Original orientation',...
        'Callback',{@rotateFOV,obj,him,hp,0}, 'Checked','off','Separator','on','Tag','rotate_0');

    hZMenuO(2) = uimenu(m,'Label','Rotate by 90 degrees clockwise',...
        'Callback',{@rotateFOV,obj,him,hp,90}, 'Checked','off','Tag','rotate_90');

    hZMenuO(3) = uimenu(m,'Label','Rotate by 180 degrees clockwise',...
        'Callback',{@rotateFOV,obj,him,hp,180}, 'Checked','off','Tag','rotate_180');

    hZMenuO(4) = uimenu(m,'Label','Rotate by 270 degrees clockwise',...
        'Callback',{@rotateFOV,obj,him,hp,270}, 'Checked','off','Tag','rotate_270');

    arr=[0 90 180 270];
    pix=find(arr==obj.orientation);
    if numel(pix)
        set(hZMenuO(pix), 'Checked','on');
    end

    m = uimenu(h,'Text','Export','Tag','ExportMenu');

    mitem = uimenu(m,'Text','Export Movie...','Tag','Movie');
    set(mitem,'MenuSelectedFcn',{@exportMovie,obj,him,hp});

    updatedisplay(obj,him,hp);


end

end

function resetZoom(handle,event, obj,him,hp)
zoom out
zoom off


xlim([1 size(him.image(1).CData,2)]);
ylim([1 size(him.image(1).CData,1)]);
%'ok'
updatedisplay(obj,him,hp);
end

function im=buildimage(obj)

% outputs a structure containing all displayed images
im=[];
im.data=[];

frame=obj.display.frame;

for i=1:obj.channels


    tmp=uint16(readImage(obj,frame,i));

    if numel(tmp)==0
        return;
    end

    tmp=imresize(tmp,obj.display.binning(i)/obj.display.binning(1));

    meangfp=0.5*double(mean(tmp(:)));


    maxgfp=double(meangfp+obj.display.intensity(i)*(max(tmp(:))-meangfp));
    % maxgfp2=double(meangfp+obj.intensity*(max(totgfp(:))-meangfp));

    tmp = imadjust(tmp,[meangfp/65535 maxgfp/65535],[0 1]);

    im(i).data=tmp; %=uint16(cat(3,zeros(size(rawphc)),zeros(size(rawphc)),zeros(size(rawphc))));

    % size(tmp)
    %imphc(:,:,1)=rawphc;
    %imphc(:,:,2)=rawphc;
    %imphc(:,:,3)=rawphc;

    %imgfp=uint16(zeros(size(imphc)));
    %imgfp(:,:,2)=temp;
    %im.overlay=imphc; %imgfp+imphc;
end
end


function setframe(handle,event,obj,him,hp)

frame=str2num(handle.String);

if frame<numel(obj.srclist{1}) & frame > 0
    obj.display.frame=frame;
    updatedisplay(obj,him,hp)
end
end


function closeWindow(handles,event,h)
if numel(h.UserData.callingApp)
    uiresume(h.UserData.callingApp)
end
delete(h)
end

function setchannel(handle,event,obj,him,hp)

%obj.display.selectedchannel=handle.Value;
end

% function setROI(handle,event,obj)
% % function associated with ROI popu up menu
%
% h=findobj('Type','patch');
%  set(h,'FaceColor',[1 0 0]);
%
% %  for i=1:numel(obj.roi)
% %     h=findobj('Tag',['roitag_' num2str(i)]);
% %     set(h,'FaceColor',[1 0 0]);
% %  end
%
%  val=handle.Value;
%
%    h=findobj('Tag',['roitag_' num2str(val)]);
%
%    set(h,'FaceColor',[1 1 0]);
%
% end

function setROIValue(handle,event,obj,him,hp,option)
% ddefines a region of interest based on user input

%obj.display.selectedchannel=handle.Value;

if option==0 % zoom adjust
    xl=round(xlim(hp(1)));
    yl=round(ylim(hp(1)));

    def={[num2str(xl(1)) ' ' num2str(yl(1))  ' '  num2str(xl(2)-xl(1))   ' ' num2str(yl(2)-yl(1))]};
else
    %   handle
    val=handle.UserData;

    def={num2str(obj.roi(val).value)};

end

str=inputdlg('Enter current ROI parameters:', 'ROI adjustment',1,def);

if numel(str)==0
    return;
end

value=str2num(str{1});

if option==0 % zoom adjust
    xlim(hp(1),[value(1) value(1)+value(3)]);
    ylim(hp(1),[value(2) value(2)+value(4)]);
else
    obj.roi(val).value=[value(1) value(2) value(3) value(4)];
    updatedisplay(obj,him,hp);
    %    xlim(hp(1),[value(1) value(1)+value(3)]);
    %   ylim(hp(1),[value(2) value(2)+value(4)]);
end

end



function selectPattern(handle,event,obj,him,hp,option)
% ddefines a region of interest based on user input

%obj.display.selectedchannel=handle.Value;
val=handle.UserData

if numel(val)==0
hmenu=findobj('Tag','DisplayROIMenu');
val=hmenu.UserData;
end

if numel(val)==0
    disp('unable to set pattern; First select a ROI!')
    return
end

tmp= obj.roi(val).proc;

if numel(tmp)
    for i=1:numel(obj.roi)
        obj.roi(i).proc=[];
    end
else
    for i=1:numel(obj.roi)
        obj.roi(i).proc=[];
    end
    obj.roi(val).proc=1;
end

% if numel(tmp)


updatedisplay(obj,him,hp)
end


function adjustROI(handle,event,hp)
% adjusts ROI value in user input field when playing with zoom

xl=round(xlim(hp(1)));
yl=round(ylim(hp(1)));
%

%htext=findobj('Tag','roivalue');

htext=findobj('Tag','Axe1');

str='Currently selected ROI: ';
%

str=[str num2str([xl(1) yl(1) xl(2)-xl(1) yl(2)-yl(1)])];
set(htext.Title,'String',str);

end



function ROIgrid(handle,event,obj,him,hp,option)
% function in the context menu to add custom ROI
% adds a grid of ROIs starting with one selected ROI


prompt = {'Number of columns',...
    'Column spacing (pixels)',...
    'Number of rows',...
    'Row spacing (pixels)'};

dlgtitle = 'Enter grid parameters';

dims = [1 100];

definput = {'2','200','1','200'};%, num2str(inte)};
answer = inputdlg(prompt,dlgtitle,dims,definput);

if numel(answer)==0
    return;
end


ind=handle.UserData;
roistart=obj.roi(ind);

xstart=roistart.value(1);
ystart=roistart.value(2);



imax=str2num(answer{1});
jmax=str2num(answer{3});

for i=1:imax
    for j=1:jmax
        if i==1 && j==1
            continue
        end

        roival=[xstart+(i-1)*str2num(answer{2}) ystart+(j-1)*str2num(answer{4}) roistart.value(3) roistart.value(4)];
        obj.addROI(roival,obj.id);
    end
end

updatedisplay(obj,him,hp);
end


function addROI(handle,event,obj,him,hp)
% function in the context menu to add custom ROI

xl=round(xlim(hp(1)));
yl=round(ylim(hp(1)));

roival=[xl(1) yl(1) xl(2)-xl(1) yl(2)-yl(1)];

obj.addROI(roival,obj.id);

updatedisplay(obj,him,hp);

resetZoom(handle,event,obj,him,hp)
end

function clearROI(handle,event,obj,him,hp)
% function in the context menu to add custom ROI

obj.removeROI;
updatedisplay(obj,him,hp);


end

function rotateFOV(handle,event,obj,him,hp,angle)
% function in the context menu to add custom ROI

if  ~isfield(obj,'orientation')
    obj.orientation=0;
end

obj.orientation=angle;

val=setxor([0 90 180 270],angle);
for i=val
    h=findobj('Tag',['rotate_' num2str(i)]);
    set(h,'Checked','off');
end

h=findobj('Tag',['rotate_' num2str(angle)]);
set(h,'Checked','on');

updatedisplay(obj,him,hp);
end


function setCrop(handle,event,obj,him,hp)
% function in the context menu to add custom ROI
%htext=findobj('Tag','roivalue');
%te=htext.String;
%roi=str2num(te);

%roi2=roi2;

%obj.crop=roi;
if numel(obj.crop)
    %   'ok'
    hCMZ = uicontextmenu;
    hZMenu = uimenu('Parent',hCMZ,'Label','Delete cropping area',...
        'Callback',@destroy);
    hZMenu2 = uimenu('Parent',hCMZ,'Label','Hide cropping area',...
        'Callback',@hidecrop);
    temp=drawpolygon('ContextMenu',hCMZ,'Tag','cropROI','Position',obj.crop);

    % temp.UserData.OnCleanup = onCleanup(@()destroy);
else
    hCMZ = uicontextmenu;
    hZMenu = uimenu('Parent',hCMZ,'Label','Delete cropping area',...
        'Callback',@destroy);
    hZMenu2 = uimenu('Parent',hCMZ,'Label','Hide cropping area',...
        'Callback',@hidecrop);
    temp=drawpolygon('ContextMenu',hCMZ,'Tag','cropROI');

    %temp.UserData.OnCleanup = onCleanup(@()destroy);
end

addlistener(temp,'ROIMoved',@allevents);
obj.crop=temp.Position;

    function allevents(src,evt)
        evname = evt.EventName;
        switch(evname)
            case{'ROIMoved'}
                obj.crop=src.Position;
        end
    end

    function destroy(src,event)
        if ishandle(temp)
            delete(temp)
        end
        obj.crop=[];
    end
    function hidecrop(src,event)
        if ishandle(temp)
            delete(temp)
        end
        %  obj.crop=[];
    end
end

function removeROI(handles,event,obj,him,hp)
val=handles.UserData;
obj.removeROI(val);
h=findobj('Tag',['roitag_' num2str(val)]);
delete(h);
h=findobj('Tag',['roitext_' num2str(val)]);
delete(h);



updatedisplay(obj,him,hp);
%delete(h);
end


function changeframe(handle,event,obj,him,hp)

disp('Loading new frame...');
ok=0;
h=findobj('Tag',['Fov' obj.id]);

% if strcmp(event.Key,'uparrow')
% val=str2num(handle.Tag(5:end));
% han=findobj(0,'tag','movi')
% han.trap(val-1).view;
% delete(handle);
% end

if strcmp(event.Key,'rightarrow')
    %   if obj.display.frame+1>numel(obj.srclist{1})
    if obj.display.frame+1>obj.frames
        return;
    end

    obj.display.frame=obj.display.frame+1;
    frame=obj.display.frame+1;
    ok=1;
end

if strcmp(event.Key,'leftarrow')
    if obj.display.frame-1<1
        return;
    end

    obj.display.frame=obj.display.frame-1;
    frame=obj.display.frame-1;
    ok=1;
end

if strcmp(event.Key,'uparrow')

    han=findobj('Tag','channelmenu')
    items=han.String;
    str=han.Value;
    chaname=items{str};
    pix=find(matches(obj.channel,chaname));
    obj.display.intensity(pix)=max(0.01,obj.display.intensity(pix)-0.1);

    % if numel(hp)>=str
    % set(hp(str).Title,'String',[obj.channel{str} ' - Intensity : '
    ok=1;
end

if strcmp(event.Key,'downarrow')
    han=findobj('Tag','channelmenu');
    items=han.String;
    str=han.Value;
    chaname=items{str};
    pix=find(matches(obj.channel,chaname));
    obj.display.intensity(pix)=max(0.01,obj.display.intensity(pix)+0.1);
    ok=1;
end

if strcmp(event.Key,'delete')
    h=findobj('Type','patch','FaceColor',[1 1 0]);

    if numel(h)
        %set(handles,'FaceColor',[1 1 0]);
        removeROI(h,event,obj,him,hp);
    end
end


if ok==1

    updatedisplay(obj,him,hp)

end
fprintf('Done ! \n');
end

function updatedisplay(obj,him,hp)

im=buildimage(obj);

cc=1;
for i=1:obj.channels
    if obj.display.selectedchannel(i)==1
        him.image(cc).CData=im(i).data;
        title(hp(cc),[obj.channel{i} ' -Intensity:' num2str(obj.display.intensity(i))],'Interpreter','None');
        cc=cc+1;
    end
end

htext=findobj('Tag','frametext');
%aa=obj.display.frame


set(htext,'String',num2str(obj.display.frame))

axes(hp(1))

hdisplaymenu=findobj('Tag','drawROIs');

h=findobj('Type','patch');

%     h=findobj('Tag',['roitag_' num2str(i)]);
%
if numel(h)~=0
    delete(h);
end
%

htext=findobj('Type','text');

%       htext=findobj('Tag',['roitext_' num2str(i)]);
%
if numel(htext)~=0
    delete(htext);
end


for i=1:numel(obj.roi)
    if numel(obj.roi(i).id)==0
        continue
    end


    if strcmp(hdisplaymenu.Checked,'on')
        roitmp=obj.roi(i).value;
        roitmp=[roitmp(1) roitmp(2) roitmp(1)+ roitmp(3) roitmp(2)+ roitmp(4)];


        if numel(obj.roi(i).proc) % roi has been set as pattern
            h=patch([roitmp(1) roitmp(3) roitmp(3) roitmp(1) roitmp(1)],[roitmp(2) roitmp(2) roitmp(4) roitmp(4) roitmp(2)],[1 0 0],'FaceAlpha',0.3,'Tag',['roitag_' num2str(i)],'UserData',i,'LineWidth',4);
        else
            h=patch([roitmp(1) roitmp(3) roitmp(3) roitmp(1) roitmp(1)],[roitmp(2) roitmp(2) roitmp(4) roitmp(4) roitmp(2)],[1 0 0],'FaceAlpha',0.3,'Tag',['roitag_' num2str(i)],'UserData',i);
        end

        htext=text(roitmp(1),roitmp(2), num2str(i), 'Color','r','FontSize',10,'Tag',['roitext_' num2str(i)]);


        %h=patch([10 100 100 10 10],[10 10 100 100 10],[1 0 0],'FaceAlpha',0.3,'Tag',['roitag_' num2str(i) ]);

        hCMZ = uicontextmenu;
        hZMenu = uimenu('Parent',hCMZ,'Label','Remove ROI',...
            'Callback',{@removeROI,obj,him,hp},'UserData',i);

        hZMenu = uimenu('Parent',hCMZ,'Label','Adjust ROI param...',...
            'Callback',{@setROIValue,obj,him,hp,1},'UserData',i);


        hZMenu = uimenu('Parent',hCMZ,'Label','Select/Deselect ROI as reference pattern.',...
            'Callback',{@selectPattern,obj,him,hp,1},'UserData',i);

        hZMenu = uimenu('Parent',hCMZ,'Label','Generate ROI grid...',...
            'Callback',{@ROIgrid,obj,him,hp,1},'UserData',i);


        %hZMenu = uimenu('Parent',hCMZ,'Label','Switch to pan',...
        %    'Callback','pan(gcbf,''on'')');
        %hZMenu = uimenu('Parent',hCMZ,'Label','Add current ROI',...
        %    'Callback',{@addROI,obj,hp});



        h.UIContextMenu = hCMZ;


        %h.Vertices
        h.ButtonDownFcn={@vie,obj};
    end
end

% str={''};
%
%     for i=1:numel(obj.roi)
%         if numel(obj.roi(1).id)~=0
%             str{i,1}=num2str(obj.roi(i).value);
%         end
%     end

%     htext=findobj('Tag','roimenu');
%     htext.String=str;


end

function vie(handles,event,obj)

%     for i=1:numel(obj.roi)
%     h=findobj('Tag',['roitag_' num2str(i)]);
%     set(h,'FaceColor',[1 0 0]);
%     end
h=findobj('Type','patch');
set(h,'FaceColor',[1 0 0]);

set(handles,'FaceColor',[1 1 0]);
val=handles.UserData;

    hh=findobj('Tag','DisplayROIMenu')
    hh.UserData=val;

ha=findobj('Tag','Axe1');

str=['Selected ROI: ' num2str(val) ' - ' obj.roi(val).id];
set(ha.Title,'String',str,'Interpreter','None');


end

function deselectROI(handles,event,obj,him,hp)
h=findobj('Type','patch');
set(h,'FaceColor',[1 0 0]);

%   set(handles,'FaceColor',[1 0 0]);

end


function displayROI(handles, event, obj,him,hp)


if strcmp(handles.Checked,'on')
    handles.Checked='off';
else
    handles.Checked='on';
end
updatedisplay(obj,him,hp)
end

function displayMenuFcn(handles, event, obj,h)

pan off
zoom off

if strcmp(handles.Checked,'off')
    handles.Checked='on';
    str=handles.Tag;
    i = str2num(replace(str,'channel_',''));
    %              pix=find(obj.channelid==i); % find matrix index associated with channel
    %              pix=pix(1); % there may be several items in case of a   multi-array channel
    %
    obj.display.selectedchannel(i)=1;
    %             % aa=obj.display.selectedchannel(i)
else

    handles.Checked='off';
    str=handles.Tag;
    i = str2num(replace(str,'channel_',''));
    %
    %             pix=find(obj.channelid==i); % find matrix index associated with channel
    %              pix=pix(1); % there may be several items in case of a   multi-array channel
    %
    obj.display.selectedchannel(i)=0;
    %             %  bb=obj.display.selectedchannel(i)
end

clf
h.UserData.handle=[];

obj.view(obj.display.frame,h);
end

function exportMovie(handles,event,obj,him,hp)
% h=findobj('Type','patch');
% set(h,'FaceColor',[1 0 0]);

%   set(handles,'FaceColor',[1 0 0]);

prompt = {'Frames:',...
    'Output Path/name (don t put the extension) :',...
    'Frame interval in experiment (min):',...
    'Frames per second:',...
    'FontSize',...
    'Draw ROIs (yes: 1; no : 0)',...
    'Correct Drift (yes: 1; no: 0)'};

dlgtitle = 'Input movie export parameters';

dims = [1 100];

fra=obj.frames(1);
pth=fullfile(obj.srcpath{1},'mymovie');
definput = {['1:' num2str(fra)],pth,'10','10','20','0','0'};%, num2str(inte)};
answer = inputdlg(prompt,dlgtitle,dims,definput);

if numel(answer)==0
    return;
end


%    [pth nme ext]=fileparts(answer{2});

arg={}; cc=1;
arg{cc}='Frames'; cc=cc+1;
arg{cc}=str2num(answer{1}); cc=cc+1;
arg{cc}='Name'; cc=cc+1;
arg{cc}=answer{2}; cc=cc+1;
arg{cc}='IPS'; cc=cc+1;
arg{cc}=str2num(answer{4}); cc=cc+1;
arg{cc}='Framerate'; cc=cc+1;
arg{cc}=str2num(answer{3}); cc=cc+1;
arg{cc}='FontSize'; cc=cc+1;
arg{cc}=str2num(answer{5}); cc=cc+1;
arg{cc}='DrawROIs'; cc=cc+1;
if str2num(answer{6})==1
    arg{cc}=[]; cc=cc+1;
else
    arg{cc}=0; cc=cc+1;
end

if str2num(answer{7})==1
    arg{cc}='Drift'; cc=cc+1;
end

% list  channels
cha=find(obj.display.selectedchannel==1);

arg{cc}='Channel'; cc=cc+1;
arg{cc}=cha; cc=cc+1;

% find levels
lev=obj.display.intensity(cha);

levels=[];
for i=1:numel(cha)
    tmp=uint16(readImage(obj,obj.display.frame,cha(i)));

    %figure, imshow(tmp,[]);
    meangfp=0.5*double(mean(tmp(:)));
    maxgfp=double(meangfp+lev(i)*(max(tmp(:))-meangfp));
    levels(i,1)=meangfp;
    levels(i,2)=maxgfp;
end
%   return;

arg{cc}='Levels'; cc=cc+1;
arg{cc}=levels; cc=cc+1;

% cropping factor
crop(1,:)=   round(hp(1).XLim);
crop(2,:)=   round(hp(1).YLim);

crop(1,1)=max(1,crop(1,1));
crop(2,1)=max(1,crop(2,1));
crop(1,2)=min(size(tmp,2),crop(1,2));
crop(2,2)=min(size(tmp,1),crop(2,2));

arg{cc}='Crop'; cc=cc+1;
arg{cc}=crop; cc=cc+1;
% crop

obj.export(arg{:});






end


