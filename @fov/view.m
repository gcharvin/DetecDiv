function view(obj,frame)


if nargin==2
    obj.display.frame=frame;
end

frame=obj.display.frame;

%findobj('Tag',['Trap' num2str(obj.id)])

if numel(findobj('Tag',['Fov' obj.id])) % handle exists already
    h=findobj('Tag',['Fov' obj.id]);
    
    hp=findobj(h,'Type','Axes');
    
    %     hp(1)=findobj(h,'Tag','Axe1');
    %     hp(2)=findobj(h,'Tag','Axe2');
    %     hp(3)=findobj(h,'Tag','Axe3');
    %     hp(4)=findobj(h,'Tag','Axe4');
    
    % hp=h.Children
    %
    % if strcmp(h.Children(1).Units,'normalized')
    % hp(1:4)=h.Children(1:4);
    % else
    % hp(1:4)=h.Children(5:8);
    % end
    
    him=h.UserData;
    %updatedisplay(obj,him,hp);
else
    
    
    im=buildimage(obj); % returns a structure with all images to be displayed
   
    if numel(im.data)==0
        disp('Could not load image. Quitting...');
        return;
    end
    
    h=figure('Tag',['Fov' obj.id],'Position',[100 100 1000 600]);
    
    str={};
    for i=1:obj.channels
        
        hp(i)=subplot(1,obj.channels,i);
        
        him.image(i)=imshow(im(i).data,[]);
        
        set(hp(i),'Tag',['Axe' num2str(i)]);
        
        %axis equal square
        
        title(hp(i),['Channel ' num2str(i) ' -Intensity:' num2str(obj.display.intensity(i))]);
        
        str{i}=['Channel ' num2str(i)];
    end
    
    linkaxes(hp);
    
%        if numel(obj.crop) % cropping area exists
%         axes(hp(1);
%         drawpolygon('Position',obj.crop);
%        end
    
    %%%
    %creat zoom callbackas
    hCMZ = uicontextmenu;
    hZMenu = uimenu('Parent',hCMZ,'Label','Reset Zoom',...
        'Callback',{@resetZoom,obj,him,hp});
    hZMenu = uimenu('Parent',hCMZ,'Label','Switch to pan',...
        'Callback','pan(gcbf,''on'')');
    hZMenu = uimenu('Parent',hCMZ,'Label','Add current ROI',...
        'Callback',{@addROI,obj,him,hp});
    
    
    hZoom = zoom(h);
    hZoom.UIContextMenu = hCMZ;
    hZoom.ActionPostCallback={@adjustROI,hp};
    
    hPan=pan(h);
    hPan.UIContextMenu = hCMZ;
    hPan.ActionPostCallback={@adjustROI,hp};
    
    
    obj.display.selectedchannel=1;
    
    h.Position(3)=600*obj.channels;
    h.Position(4)=600;
    
    h.UserData=him;
    
    h.KeyPressFcn={@changeframe,obj,him,hp};
    
    btnSetFrame = uicontrol('Style', 'text','FontSize',18, 'String', ['FOV ' obj.id] ,...
        'Position', [50 550 200 20],'HorizontalAlignment','left', ...
        'Tag','frametexttitle') ;
    
    btnSetFrame = uicontrol('Style', 'text','FontSize',14, 'String', 'Enter frame number here, or use arrows <- ->',...
        'Position', [50 50 300 20],'HorizontalAlignment','left', ...
        'Tag','frametexttitle') ;
    
    btnSetFrame = uicontrol('Style', 'edit','FontSize',14, 'String', num2str(obj.display.frame),...
        'Position', [50 20 80 20],...
        'Callback', {@setframe,obj,him,hp},'Tag','frametext') ;
    
        btnSetCrop = uicontrol('Style', 'pushbutton','FontSize',14, 'String', 'set crop',...
        'Position', [50 80 80 20],...
        'Callback', {@setCrop,obj,him,hp},'Tag','setCrop') ;
    
    
   %         hZMenu = uimenu('Parent',hCMZ,'Label','Set cropping area',...
   %     'Callback',{@setCrop,obj,him,hp});
    
    
    A = cell(1,2);
    A{1,1} = 'Intensity adjust using';
    A{1,2} = 'up and down arrow keys for channel:';
    mls = sprintf('%s\n%s',A{1,1},A{1,2});
    
    btnSetFrame = uicontrol('Style', 'text','FontSize',14, 'String', mls,...
        'Position', [400 50 300 40],'HorizontalAlignment','left', ...
        'Tag','frametexttitle') ;
    
    btnSetFrame = uicontrol('Style', 'popupmenu','FontSize',14, 'String', str, 'Value',1,...
        'Position', [400 20 150 20],...
        'Callback', {@setchannel,obj,him,hp},'Tag','channelmenu') ;
    
    btnSetFrame = uicontrol('Style', 'text','FontSize',14, 'String', 'ROIs',...
        'Position', [400 550 150 20],'HorizontalAlignment','left', ...
        'Tag','frametexttitle') ;
    
    
    str={''};
    for i=1:numel(obj.roi)
        if numel(obj.roi(1).id)~=0
            str{i,1}=num2str(obj.roi(i).value);
        end
    end
    
    
    btnSetFrame = uicontrol('Style', 'popupmenu','FontSize',14, 'String', str, 'Value',1,...
        'Position', [400 530 250 20],...
        'Callback', {@setROI,obj},'Tag','roimenu') ;
    
    btnSetFrame = uicontrol('Style', 'text','FontSize',14, 'String', 'Current ROI',...
        'Position', [200 550 150 20],'HorizontalAlignment','left', ...
        'Tag','frametexttitle') ;
    
    xl=round(xlim(gca));
    yl=round(xlim(gca));
    
    btnSetFrame = uicontrol('Style', 'edit','FontSize',14, 'String', num2str([xl(1) yl(1) xl(2)-xl(1) yl(2)-yl(1)]), 'Value',1,...
        'Position', [200 530 150 20],...
        'Callback', {@setROIValue,obj,him,hp},'Tag','roivalue') ;
    
    
    updatedisplay(obj,him,hp)
    
    % btnSetDiv = uicontrol('Style', 'edit', 'String', 'No division',...
    %         'Position', [450 20 80 20],...
    %         'Callback', {},'Tag','divtext') ;
    
    % btnTrainObjects2 = uicontrol('Style', 'pushbutton', 'String', 'Classify objects',...
    %         'Position', [320 20 80 20],...
    %         'Callback', {@classify,obj,him,hp}) ;
    
    %  if ~isfield(obj.div,'deep')
    %       obj.div.deep=[];
    %       obj.div.deep=-ones(1,size(obj.gfp,3));
    %  end
    %  if ~isfield(obj.div,'deepCNN')
    %       obj.div.deepCNN=[];
    %       obj.div.deepCNN=-ones(1,size(obj.gfp,3));
    %  end
    %  if ~isfield(obj.div,'deepLSTM')
    %       obj.div.deepLSTM=[];
    %       obj.div.deepLSTM=-ones(1,size(obj.gfp,3));
    %  end
    
end

end

function resetZoom(handle,event, obj,him,hp)
zoom out
zoom off
updatedisplay(obj,him,hp);
end

function im=buildimage(obj)

% outputs a structure containing all displayed images
im=[];
im.data=[];

frame=obj.display.frame;

for i=1:obj.channels
    
   
    tmp=readImage(obj,frame,i);
    
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


function setchannel(handle,event,obj,him,hp)

obj.display.selectedchannel=handle.Value;

end


function setROI(handle,event,obj)
% function associated with ROI popu up menu

 for i=1:numel(obj.roi)
    h=findobj('Tag',['roitag_' num2str(i)]);
    set(h,'FaceColor',[1 0 0]);
 end
 
 val=handle.Value;
 
   h=findobj('Tag',['roitag_' num2str(val)]);
   
   set(h,'FaceColor',[1 1 0]);
   

end

function setROIValue(handle,event,obj,him,hp)
% ddefines a region of interest based on user input

%obj.display.selectedchannel=handle.Value;
value=str2num(handle.String);
xlim(hp(1),[value(1) value(1)+value(3)]);
ylim(hp(1),[value(2) value(2)+value(4)]);
end

function adjustROI(handle,event,hp)
% adjusts ROI value in user input field when playing with zoom

xl=round(xlim(hp(1)));
yl=round(ylim(hp(1)));
%
htext=findobj('Tag','roivalue');
%
htext.String=num2str([xl(1) yl(1) xl(2)-xl(1) yl(2)-yl(1)]);
end

function addROI(handle,event,obj,him,hp)
% function in the context menu to add custom ROI
htext=findobj('Tag','roivalue');
te=htext.String;
roi=str2num(te);

%roi2=roi2;

htext=findobj('Tag','roimenu');
tmp=htext.String;

if numel(tmp)==1 & numel(tmp{1})~=0
tmp{end+1}=te;
else
tmp{1}=te;    
end

htext.String=tmp;
htext.Value=numel(tmp);

obj.addROI(roi,obj.id);
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
   temp=drawpolygon('Position',obj.crop); 
   temp.UserData.OnCleanup = onCleanup(@()destroy);
else
temp=drawpolygon;
  temp.UserData.OnCleanup = onCleanup(@()destroy);
end

addlistener(temp,'ROIMoved',@allevents);
obj.crop=temp.Position;

function allevents(src,evt)
    evname = evt.EventName;
    switch(evname)
        case{'ROIMoved'}
            obj.crop=src.Position;
             case{'ROIDeleted'}
    end
end

    function destroy
        obj.crop=[];
    end
end

function removeROI(handles,event,obj,him,hp)
  val=handles.UserData;
  obj.removeROI(val);
  h=findobj('Tag',['roitag_' num2str(val)])
  delete(h);
  h=findobj('Tag',['roitext_' num2str(val)])
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
    if obj.display.frame+1>numel(obj.srclist{1})
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
    
    obj.display.intensity(obj.display.selectedchannel)=max(0.01,obj.display.intensity(obj.display.selectedchannel)-0.01);
    ok=1;
end

if strcmp(event.Key,'downarrow')
    obj.display.intensity(obj.display.selectedchannel)=min(1,obj.display.intensity(obj.display.selectedchannel)+0.01);
    ok=1;
end

if ok==1
    
    updatedisplay(obj,him,hp)
    
end
fprintf('Done ! \n');
end

function updatedisplay(obj,him,hp)

im=buildimage(obj);

for i=1:obj.channels
    him.image(i).CData=im(i).data;
    title(hp(i),['Channel ' num2str(i) ' -Intensity:' num2str(obj.display.intensity(i))]);
end

htext=findobj('Tag','frametext');
%aa=obj.display.frame


set(htext,'String',num2str(obj.display.frame))

axes(hp(1))
for i=1:numel(obj.roi)
    if numel(obj.roi(i).id)==0
        continue
    end
    
    h=findobj('Tag',['roitag_' num2str(i)]);
    
    if numel(h)~=0
        delete(h);
    end
    roitmp=obj.roi(i).value;
    roitmp=[roitmp(1) roitmp(2) roitmp(1)+ roitmp(3) roitmp(2)+ roitmp(4)];
    h=patch([roitmp(1) roitmp(3) roitmp(3) roitmp(1) roitmp(1)],[roitmp(2) roitmp(2) roitmp(4) roitmp(4) roitmp(2)],[1 0 0],'FaceAlpha',0.3,'Tag',['roitag_' num2str(i)],'UserData',i);
    
    htext=text(roitmp(1),roitmp(2), num2str(i), 'Color','r','FontSize',10,'Tag',['roitext_' num2str(i)]);
    
    %h=patch([10 100 100 10 10],[10 10 100 100 10],[1 0 0],'FaceAlpha',0.3,'Tag',['roitag_' num2str(i) ]);
    
    hCMZ = uicontextmenu;
    hZMenu = uimenu('Parent',hCMZ,'Label','Remove ROI',...
        'Callback',{@removeROI,obj,him,hp},'UserData',i);
    %hZMenu = uimenu('Parent',hCMZ,'Label','Switch to pan',...
    %    'Callback','pan(gcbf,''on'')');
    %hZMenu = uimenu('Parent',hCMZ,'Label','Add current ROI',...
    %    'Callback',{@addROI,obj,hp});
 
    h.UIContextMenu = hCMZ;
    
    
    %h.Vertices
    h.ButtonDownFcn={@vie,obj};
end

str={''};
  
    for i=1:numel(obj.roi)
        if numel(obj.roi(1).id)~=0
            str{i,1}=num2str(obj.roi(i).value);
        end
    end
   
    htext=findobj('Tag','roimenu');
    htext.String=str;
    
    
end

function vie(handles,event,obj)

    for i=1:numel(obj.roi)
    h=findobj('Tag',['roitag_' num2str(i)]);
    set(h,'FaceColor',[1 0 0]);
    end
   set(handles,'FaceColor',[1 1 0]);
   val=handles.UserData;
   
   h=findobj('Tag','roimenu');
   h.Value=val;
end





