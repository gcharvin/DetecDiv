function view(obj,frame,option)


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

if nargin==3
    h=option;
    rebuild=1;
  %  'oki'
end

if numel(findobj('Tag',['Fov' obj.id])) && rebuild==0% handle exists already
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

else
    
    
    im=buildimage(obj); % returns a structure with all images to be displayed
   
    warning off all
    if numel(im.data)==0
        disp('Could not load image. Quitting...');
        return;
    end
    warning on all;
    
  %  h
    if numel(h)==0
    %    'ok'
    h=figure('Tag',['Fov' obj.id],'Position',[100 100 800 600]);
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
    
%        if numel(obj.crop) % cropping area exists
%         axes(hp(1);
%         drawpolygon('Position',obj.crop);
%        end
    
    %%%
    
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
    
    h.UserData=him;
    
    h.KeyPressFcn={@changeframe,obj,him,hp};
    
    h.WindowButtonDownFcn={@deselectROI,obj,him,hp};
    
    h.Name= ['FOV ' obj.id];
    
%     btnSetFrame = uicontrol('Style', 'text','FontSize',18, 'String',  ,...
%         'Position', [50 550 200 20],'HorizontalAlignment','left', ...
%         'Tag','frametexttitle') ;
    
    btnSetFrame = uicontrol('Style', 'text','FontSize',12, 'String', 'Enter frame number here, or use arrows <- ->',...
        'Position', [50 50 350 20],'HorizontalAlignment','left', ...
        'Tag','frametexttitle') ;
    
    btnSetFrame = uicontrol('Style', 'edit','FontSize',12, 'String', num2str(obj.display.frame),...
        'Position', [50 20 80 20],...
        'Callback', {@setframe,obj,him,hp},'Tag','frametext') ;
    
%         btnSetCrop = uicontrol('Style', 'pushbutton','FontSize',14, 'String', 'set crop',...
%         'Position', [50 80 80 20],...
%         'Callback', {@setCrop,obj,him,hp},'Tag','setCrop') ;
    
    
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
    
%     btnSetFrame = uicontrol('Style', 'text','FontSize',14, 'String', 'ROIs',...
%         'Position', [400 550 150 20],'HorizontalAlignment','left', ...
%         'Tag','frametexttitle') ;
    
    
%     str={''};
%     for i=1:numel(obj.roi)
%         if numel(obj.roi(1).id)~=0
%             str{i,1}=num2str(obj.roi(i).value);
%         end
%     end
    
    
%     btnSetFrame = uicontrol('Style', 'popupmenu','FontSize',14, 'String', str, 'Value',1,...
%         'Position', [400 530 250 20],...
%         'Callback', {@setROI,obj},'Tag','roimenu') ;
%     
%     btnSetFrame = uicontrol('Style', 'text','FontSize',14, 'String', 'Current ROI',...
%         'Position', [200 550 150 20],'HorizontalAlignment','left', ...
%         'Tag','frametexttitle') ;
%     
%     xl=round(xlim(gca));
%     yl=round(xlim(gca));
%     
%     btnSetFrame = uicontrol('Style', 'edit','FontSize',14, 'String', num2str([xl(1) yl(1) xl(2)-xl(1) yl(2)-yl(1)]), 'Value',1,...
%         'Position', [200 530 150 20],...
%         'Callback', {@setROIValue,obj,him,hp},'Tag','roivalue') ;
    
    
 %   hmenu=findobj(h,'Tag','DisplayMenu')
%if numel(hmenu)==0

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
    
  hZMenu = uimenu(m,'Label','Original orientation',...
        'Callback',{@rotateFOV,obj,him,hp,0}, 'Checked','on','Separator','on','Tag','rotate_0');
    
  hZMenu = uimenu(m,'Label','Rotate by 90 degrees clockwise',...
        'Callback',{@rotateFOV,obj,him,hp,90}, 'Checked','off','Tag','rotate_90');
    
      hZMenu = uimenu(m,'Label','Rotate by 180 degrees clockwise',...
        'Callback',{@rotateFOV,obj,him,hp,180}, 'Checked','off','Tag','rotate_180');
    
       hZMenu = uimenu(m,'Label','Rotate by 270 degrees clockwise',...
        'Callback',{@rotateFOV,obj,him,hp,270}, 'Checked','off','Tag','rotate_270');
    
    % HERE orientation 
 
        
       
%       mroi = uimenu(h,'Text','ROIs','Tag','ROIMenu');
%       mroi_menu=[];
%       
%       cc=1;
%          for i=1:numel(obj.roi)
%         if numel(obj.roi(1).id)~=0
%             mroi_menu(i) = uimenu(mroi,'Text',[num2str(cc) '-' obj.roi(i).id ],'Checked','on','Tag','ROIs');
%           %  str{i,1}=num2str(obj.roi(i).value);
%             cc=cc+1;
%         end
%     end
        
%end


    updatedisplay(obj,him,hp);
    
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
val=handle.UserData;

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

function addROI(handle,event,obj,him,hp)
% function in the context menu to add custom ROI

xl=round(xlim(hp(1)));
yl=round(ylim(hp(1)));

roival=[xl(1) yl(1) xl(2)-xl(1) yl(2)-yl(1)];

% htext=findobj('Tag','roivalue')
% te=htext.String
% roi=str2num(te)

%roi2=roi2;

% htext=findobj('Tag','roimenu');
% tmp=htext.String;
% 
% if numel(tmp)==1 & numel(tmp{1})~=0
% tmp{end+1}=te;
% else
% tmp{1}=te;    
% end

% htext.String=tmp;
% htext.Value=numel(tmp);

obj.addROI(roival,obj.id);
updatedisplay(obj,him,hp);
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
    
    han=findobj('Tag','channelmenu');
    str=han.Value;
    obj.display.intensity(str)=max(0.01,obj.display.intensity(str)-0.1);
   % if numel(hp)>=str
   % set(hp(str).Title,'String',[obj.channel{str} ' - Intensity : ' 
    ok=1;
end

if strcmp(event.Key,'downarrow')
    han=findobj('Tag','channelmenu');
    str=han.Value;
  
    obj.display.intensity(str)=min(1,obj.display.intensity(str)+0.1);
    ok=1;
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
   
%    h=findobj('Tag','roimenu');
%    h.Value=val;
   
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
        h.UserData=[];
        
        obj.view(obj.display.frame,h);
     end
    

