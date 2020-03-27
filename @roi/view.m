function view(obj,frame,category)
% view for ROI objects
% category defines what kind of menu is displayed in order to perform the
% training on existing data 
% category== 'Image' : Image classification can be performed using keyboard
% category== 'Pixel' : Pixel classification can be performed using painting
% tool 


if numel(obj.image)==0
    obj.load
end

if nargin>=2
    obj.display.frame=frame;
end



frame=obj.display.frame;

%findobj('Tag',['Trap' num2str(obj.id)])

if numel(findobj('Tag',['ROI' obj.id])) % handle exists already
    h=findobj('Tag',['ROI' obj.id]);
    draw(obj,h);
    
    %hp=findobj(h,'Type','Axes');
    
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
    
    %him=h.UserData;
    
    %updatedisplay(obj,him,hp);
else
    %im=buildimage(obj); % returns a structure with all images to be displayed
    
    h=figure('Tag',['ROI' obj.id],'MenuBar','none','Toolbar','none');
    draw(obj,h);
    
    
    
    
    %draw(obj,h);
end
end



% hp(1)=subplot(2,2,1);
% set(hp(1),'Tag','Axe1');
%
% %aaa=hp(1).Tag
% axis equal square
%
% him.pixtraining=imshow(im.pixtraining);
% hold on
% him.pixtraining_raw=imshow(im.pixtraining_raw) ; % overlay raw gfp image to paint
% him.pixtraining_raw.AlphaData=0.7;
% hold off;
%
% title(['Pixel Training - Trap: ' num2str(obj.id) '- Frame:' num2str(obj.frame) ' - Int:' num2str(obj.intensity)]);
%
% hp(2)=subplot(2,2,2);
% set(hp(2),'Tag','Axe2');
% axis equal square
% him.pixclassif=imshow(im.pixclassif);
% title(['Pixel Classification - Trap: ' num2str(obj.id) '- Frame:' num2str(obj.frame)]);



%h.KeyPressFcn={@changeframe,obj,him,hp};

%paint(him.pixtraining,h,hp,obj); % launches the function for pixel training

% btnPaint = uicontrol('Style', 'togglebutton', 'String', 'Pixel Train',...
%         'Position', [20 20 50 20],...
%         'Callback', {@paint,him.pixtraining,h,hp,obj}) ;
%
% btnClassify = uicontrol('Style', 'pushbutton', 'String', 'Classify pixels',...
%         'Position', [120 20 80 20],...
%         'Callback', {@classify,obj,him,hp}) ;
%
% btnTrainObjects = uicontrol('Style', 'togglebutton', 'String', 'Objects train',...
%         'Position', [220 20 80 20],...
%         'Callback', {@trainobjects,h,hp,obj,him}) ;
%
% btnSetFrame = uicontrol('Style', 'edit', 'String', num2str(obj.frame),...
%         'Position', [320 20 80 20],...
%         'Callback', {@setframe,obj,him,hp},'Tag','frametext') ;
%
% btnSetDiv = uicontrol('Style', 'edit', 'String', 'No division',...
%         'Position', [450 20 80 20],...
%         'Callback', {},'Tag','divtext') ;
%
% % btnTrainObjects2 = uicontrol('Style', 'pushbutton', 'String', 'Classify objects',...
% %         'Position', [320 20 80 20],...
% %         'Callback', {@classify,obj,him,hp}) ;
%
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
%
% end

% function classify(handle,event,obj,him,hp)
%   obj.pixclassify(obj.frame);
%   updatedisplay(obj,him,hp)
%   % updates display
% end

function [him hp]=draw(obj,h)

handles=findobj('Tag','DisplayMenu');

if numel(handles)==0
m = uimenu(h,'Text','Display','Tag','DisplayMenu');
mitem=[];

for i=1:numel(obj.display.channel)
    mitem(i) = uimenu(m,'Text',obj.display.channel{i},'Checked','on','Tag',['channel_' num2str(i)]);
    set(mitem(i),'MenuSelectedFcn',{@displayMenu,obj,h});
    
    if obj.display.selectedchannel(i)==1
        set(mitem(i),'Checked','on');
    else
        set(mitem(i),'Checked','off');
    end
end
end

cd=0;
for i=1:numel(obj.display.channel)
    if obj.display.selectedchannel(i)==1
        cd=cd+1;
    end
end

im=buildimage(obj);

cc=1;
him=[];
hp=[];

pos=h.Position;


for i=1:numel(obj.display.channel)
    
    if obj.display.selectedchannel(i)==1
        hp(cc)=subplot(1,cd,cc);
        him.image(cc)=imshow(im(cc).data,[]);
        
        set(hp(cc),'Tag',['Axe' num2str(cc)]);
        
        %axis equal square
        tt=obj.display.intensity(i,:);
        title(hp(cc),[obj.display.channel{i} ' -Intensity:' num2str(tt)]);
        
        cc=cc+1;
    end
end

if cd>0
    linkaxes(hp);
end

h.Position(1:2)=pos(1:2);
h.Position(3)=800;
h.Position(4)=800;

h.UserData=him;

h.KeyPressFcn={@changeframe,obj,him,hp};

handles=findobj('Tag','frametexttitle');
if numel(handles)==0
    btnSetFrame = uicontrol('Style', 'text','FontSize',14, 'String', 'Enter frame number here, or use arrows <- ->',...
        'Position', [50 50 300 20],'HorizontalAlignment','left', ...
        'Tag','frametexttitle') ;
end

handles=findobj('Tag','frametext');
if numel(handles)==0
    btnSetFrame = uicontrol('Style', 'edit','FontSize',14, 'String', num2str(obj.display.frame),...
        'Position', [50 20 80 20],...
        'Callback', {@setframe,obj,him,hp},'Tag','frametext') ;
else
    handles.Callback=  {@setframe,obj,him,hp};
end


end

function displayMenu(handles, event, obj,h)

if strcmp(handles.Checked,'off')
    handles.Checked='on';
    str=handles.Tag;
    i = str2num(replace(str,'channel_',''));
    obj.display.selectedchannel(i)=1;
else
    
    handles.Checked='off';
    str=handles.Tag;
    i = str2num(replace(str,'channel_',''));
    obj.display.selectedchannel(i)=0;
end

[him hp]=draw(obj,h);

end

function im=buildimage(obj)

% outputs a structure containing all displayed images
im=[];
im.data=[];

frame=obj.display.frame;

cc=1;
for i=1:numel(obj.display.channel)
    
    if obj.display.selectedchannel(i)==1
        
        % get the righ data: there may be several matrices for one single
        % channel in case of RGB images
        
        pix=find(obj.channelid==i);
        src=obj.image;
        
        % for each channel perform normalization
        %pix
        if numel(pix)==1
            tmp=src(:,:,pix,:);
            meangfp=0.5*double(mean(tmp(:)));
            it=obj.display.intensity(pix,i);
            maxgfp=double(meangfp+it*(max(tmp(:))-meangfp));
            imout=obj.image(:,:,pix,frame);
            imout=imadjust(imout,[meangfp/65535 maxgfp/65535],[0 1]);
            imout =repmat(imout,[1 1 3]);
            for k=1:3
                imout(:,:,k)=imout(:,:,k).*obj.display.rgb(i,k);
            end
        else
            imout=uint16(zeros(size(obj.image,1),size(obj.image,2),3));
            
           % size(imout)
            %i
            
            for j=1:numel(pix)
               % i,j,pix(j)
                tmp=src(:,:,pix(j),:);
                meangfp=0.5*double(mean(tmp(:)));
                it=obj.display.intensity(i,j);
                maxgfp=double(meangfp+it*(max(tmp(:))-meangfp));
                imtemp=obj.image(:,:,pix(j),frame);
                %size(imtemp)
                if meangfp>0 && maxgfp>0
                imtemp = imadjust(imtemp,[meangfp/65535 maxgfp/65535],[0 1]);
                end
                imout(:,:,j)=imtemp.*obj.display.rgb(i,j);
            end
        end
        im(cc).data=imout;
        cc=cc+1;
    end
    
    %   cc=cc+1;
end

end


function setframe(handle,event,obj,him,hp)

frame=str2num(handle.String);

if frame<=size(obj.image,4) & frame > 0
    obj.display.frame=frame;
    updatedisplay(obj,him,hp)
end
end


function changeframe(handle,event,obj,him,hp)

ok=0;
h=findobj('Tag',['ROI' obj.id]);

% if strcmp(event.Key,'uparrow')
% val=str2num(handle.Tag(5:end));
% han=findobj(0,'tag','movi')
% han.trap(val-1).view;
% delete(handle);
% end

if strcmp(event.Key,'rightarrow')
    if obj.display.frame+1>size(obj.image,4)
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

if strcmp(event.Key,'uparrow') % TO BE IMPLEMENTED
    
     %obj.display.intensity(obj.display.selectedchannel)=max(0.01,obj.display.intensity(obj.display.selectedchannel)-0.01);
    ok=1;
end

if strcmp(event.Key,'downarrow') % TO BE IMPLEMENTED
    % obj.display.intensity(obj.display.selectedchannel)=min(1,obj.display.intensity(obj.display.selectedchannel)+0.01);
    ok=1;
end

if ok==1
    
    updatedisplay(obj,him,hp)
    
end
end



%  if strcmp(event.Key,'r') || strcmp(event.Key,'d' ) % reject or dead divisions
%     if obj.frame>1
%        % 'ok'
%         if obj.div.raw(obj.frame-1)==1 % putative division
%           %  'ok'
%             if obj.div.reject(obj.frame-1)==0 % frame is not rejected
%              %   'ok'
%
%              if strcmp(event.Key,'r')
%                 obj.div.reject(obj.frame-1)=1;
%              else
%
%                 obj.div.reject(obj.frame-1)=2;
%               %  aa=obj.div.reject(obj.frame-1)
%              end
%
% %                 hreject=findobj('Tag',['Rejectplot' num2str(obj.id)]);
% %                 hraw=findobj('Tag',['Rawplot' num2str(obj.id)]);
% %                 hreject.XData=[hreject.XData obj.frame-1];
% %                 hreject.YData=[hreject.YData hraw.YData(obj.frame-1)];
%             else
%                 obj.div.reject(obj.frame-1)=0;
%
%                 %hreject=findobj('Tag',['Rejectplot' num2str(obj.id)]);
%                 %hraw=findobj('Tag',['Rawplot' num2str(obj.id)]);
%
% %                 pix=find(hreject.XData==obj.frame-1);
% %
% %                 hreject.XData=hreject.XData( setxor(1:length(hreject.XData),pix));
% %                 hreject.YData=hreject.YData( setxor(1:length(hreject.YData),pix));
%             end
%
%             hr=findobj('Tag',['Traj' obj.id]);
%             if numel(hr)>0
%             delete(hr);
%             end
%
%             obj.traj;
%              h=findobj('Tag',['Trap' obj.id]);
%             figure(h);
%         end
%     end
%     ok=1;
%  end
%
%  if strcmp(event.Key,'l') % move left to previous division
%
%     if numel(obj.div.raw)>0
%     pix=find(obj.div.raw(1:obj.frame-2)==1,1,'last');
%
%     if numel(pix)
%
%         obj.frame=pix+1;
%     end
%
%     ok=1;
%     end
%  end
%  if strcmp(event.Key,'m') % move right to next division
%
%     if numel(obj.div.raw)>0
%     pix=find(obj.div.raw(obj.frame+1:end)==1,1,'first');
%
%     if numel(pix)
%         obj.frame=pix+obj.frame+1;
%     end
%
%     ok=1;
%     end
%  end
%
%    if strcmp(event.Key,'s') % stop training at given frame
%         if obj.frame==obj.div.stop
%             obj.div.stop=size(obj.gfp,3);
%         else
%             obj.div.stop=obj.frame;
%         end
%
%         hl=findobj('Tag',['Stopline' num2str(obj.id)]);
%             if numel(hl)>0
%                 hl.XData=[obj.div.stop obj.div.stop];
%             end
%
%         ok=1;
%      end
%
%
%
%
% if ok==1
%
% updatedisplay(obj,him,hp)
%
%  hl=findobj('Tag',['Trajline' obj.id]);
%     if numel(hl)>0
%     hl.XData=[obj.frame obj.frame];
%     end
% end
% end


function updatedisplay(obj,him,hp)

% list=[];
% for i=1:numel(obj.display.settings)
%     handles=findobj('Tag',['channel_' num2str(i)]);
%     if strcmp(handles.Checked,'on')
%         list=[list i];
%     end
% end

im=buildimage(obj);

cc=1;
for i=1:numel(obj.display.channel)
    if obj.display.selectedchannel(i)==1
    him.image(cc).CData=im(cc).data;
    
    % title(hp(i),['Channel ' num2str(i) ' -Intensity:' num2str(obj.display.intensity(i))]);
    tt=obj.display.intensity(i,:);
    title(hp(cc),[obj.display.channel{i} ' -Intensity:' num2str(tt)]);
    cc=cc+1;
    end
end

htext=findobj('Tag','frametext');

htext.String=num2str(obj.display.frame);

axes(hp(1));

end


% function updatedisplay(obj,him,hp)
%
% im=buildimage(obj);
%
% him.overlay.CData=im.overlay;
% him.pixtraining.CData=im.pixtraining;
% him.pixtraining_raw.CData=im.pixtraining_raw;
% him.pixclassif.CData=im.pixclassif;
% him.trackclassif.CData=im.trackclassif;
% %him.trackclassif2.CData=im.trackclassif2;
%
%
% title(hp(1),['Pixel Training - Trap: ' obj.id '- Frame:' num2str(obj.frame) ' - Int:' num2str(obj.intensity)]);
% title(hp(2),['Pixel Classification - Trap: ' obj.id '- Frame:' num2str(obj.frame)]);
% title(hp(3),['Tracking Classification - Trap: ' obj.id '- Frame:' num2str(obj.frame)]);
% %title(hp(4),['Raw image - Trap: ' obj.id '- Frame:' num2str(obj.frame) ' - Int:' num2str(obj.intensity)]);
%
% if ~isfield(obj.div,'deep')
%       obj.div.deep=[];
% end
%     if numel(obj.div.deep)==0
%         obj.div.deep=zeros(1,size(obj.gfp,3));
%     end
%
%     if ~isfield(obj.div,'deepLSTM')
%       obj.div.deepLSTM=[];
% end
%     if numel(obj.div.deepLSTM)==0
%         obj.div.deepLSTM=zeros(1,size(obj.gfp,3));
%     end
%
%       if ~isfield(obj.div,'deepCNN')
%       obj.div.deepCNN=[];
% end
%     if numel(obj.div.deepCNN)==0
%         obj.div.deepCNN=zeros(1,size(obj.gfp,3));
%     end
%
% switch obj.div.deep(obj.frame)
%     case -1
%          str='- ';
%     case 0
%         str='unbud ';
%     case 1
%         str='small b ';
%     case 2
%         str='large b ';
% end
%
% switch obj.div.deepCNN(obj.frame)
%     case -1
%         str=[str 'CNN:- '];
%     case 0
%         str=[str 'CNN:unbud '];
%     case 1
%         str=[str 'CNN:small b '];
%     case 2
%         str=[str 'CNN:large b '];
% end
%
% switch obj.div.deepLSTM(obj.frame)
%     case -1
%         str=[str ' LSTM:- '];
%     case 0
%         str=[str ' LSTM:unbud '];
%     case 1
%         str=[str ' LSTM:small b '];
%     case 2
%         str=[str ' LSTM:large b '];
% end
%
%
% title(hp(4),str);%,'FontSize',20);
%
% h=findobj('Tag',['Trap' obj.id]);
%
% t=findobj(h,'Tag','frametext');
%
% t.String=num2str(obj.frame);
%
% t=findobj(h,'Tag','divtext');
% t.String='No divison';
%
% if numel(obj.div.raw)>0
% if obj.frame>1
% if obj.div.raw(obj.frame-1)==1
%   t.String='Division ?';
% end
%
% %tt=obj.div.classi
%
%  if obj.div.classi(obj.frame)==1
%
%    t.String='Division';
%  end
%
% % if obj.div.classi(obj.frame-1)==1
% %
% %   t.String='Division';
% % end
%
% if obj.div.reject(obj.frame-1)==1
%   t.String='Rejected division';
% end
%
% if obj.div.reject(obj.frame-1)==2
%   t.String='Dead division';
% end
%
% end
% end
%
% end


function paint(handle,event,imobj,figh,hp,obj)

if handle.Value==1
    
    set(figh,'WindowButtonDownFcn',@wbdcb);
    
    ah = hp(1); %axes('SortMethod','childorder');
    % axis ([1 10 1 10])
    %title('Click and drag')
else
    figh.WindowButtonDownFcn='';
    figh.Pointer = 'arrow';
    figh.WindowButtonMotionFcn = '';
    figh.WindowButtonUpFcn = '';
    figure(figh); % set focus
end

    function wbdcb(src,callbackdata)
        seltype = src.SelectionType;
        
        if strcmp(seltype,'normal')
            src.Pointer = 'circle';
            cp = ah.CurrentPoint;
            
            xinit = cp(1,1);
            yinit = cp(1,2);
            
            % hl = line('XData',xinit,'YData',yinit,...
            % 'Marker','p','color','b');
            src.WindowButtonMotionFcn = {@wbmcb,2};
            src.WindowButtonUpFcn = @wbucb;
            
            
        end
        if strcmp(seltype,'alt')
            src.Pointer = 'circle';
            cp = ah.CurrentPoint;
            xinit = cp(1,1);
            yinit = cp(1,2);
            % hl = line('XData',xinit,'YData',yinit,...
            % 'Marker','p','color','b');
            src.WindowButtonMotionFcn = {@wbmcb,1};
            src.WindowButtonUpFcn = @wbucb;
            
        end
        
        
        function wbmcb(src,event,colortype)
            cp = ah.CurrentPoint;
            % For R2014a and earlier:
            % cp = get(ah,'CurrentPoint');
            
            
            
            %xdat = [xinit,cp(1,1)]
            %ydat = [yinit,cp(1,2)]
            if obj.brushSize<3
                xdat = [cp(1,1) ];
                ydat = [cp(1,2) ];
            else
                
                
                xdat = [cp(1,1) cp(1,1)+1 cp(1,1)-1 cp(1,1)+1 cp(1,1)-1 cp(1,1) cp(1,1) cp(1,1)+1 cp(1,1)-1];
                ydat = [cp(1,2) cp(1,2)+1 cp(1,2)-1 cp(1,2)-1 cp(1,2)+1 cp(1,2)+1 cp(1,2)-1 cp(1,2) cp(1,2)];
            end
            
            % enlarge pixel size
            
            %hl.XData = xdat;
            %hl.YData = ydat;
            % For R2014a and earlier:
            % set(hl,'XData',xdat);
            % set(hl,'YData',ydat);
            
            % interpolate results
            
            finalX=xdat;
            finalY=ydat;
            
            in=finalX<=size(obj.train,2) & finalY<=size(obj.train,1) & finalX>0 & finalY>0;
            
            finalX=finalX(in);
            finalY=finalY(in);
            
            if numel(finalX)>=0
                
                imtemp=imobj.CData;
                
                % size(imtemp)
                % int32(finalY)
                % int32(finalX)
                %colortype*ones(1,length(finalX));
                
                linearInd = sub2ind(size(imtemp), int32(finalY), int32(finalX),colortype*ones(1,length(finalX)));
                imobj.CData(linearInd)=255;
                
                swi=3-colortype;
                linearInd = sub2ind(size(imtemp), int32(finalY), int32(finalX),swi*ones(1,length(finalX)));
                imobj.CData(linearInd)=0;
                
                obj.train(:,:,:,obj.frame)=imobj.CData;
                % hl.XData = xdat;
                % hl.YData = ydat;
                
                drawnow
            end
        end
        
        function wbucb(src,callbackdata)
            last_seltype = src.SelectionType;
            % For R2014a and earlier:
            % last_seltype = get(src,'SelectionType');
            %if strcmp(last_seltype,'alt')
            src.Pointer = 'arrow';
            src.WindowButtonMotionFcn = '';
            src.WindowButtonUpFcn = '';
            % For R2014a and earlier:
            % set(src,'Pointer','arrow');
            % set(src,'WindowButtonMotionFcn','');
            % set(src,'WindowButtonUpFcn','');
            % else
            %    return
            %end
        end
    end
end

function trainobjects(handle,event,figh,hp,obj,him)

if handle.Value==1
    
    set(figh,'WindowButtonDownFcn',@wbdcbobjects);
    
    % 'ok'
    ah = hp(3); %axes('SortMethod','childorder');
    % axis ([1 10 1 10])
    %title('Click and drag')
else
    figh.WindowButtonDownFcn='';
    figh.Pointer = 'arrow';
    figh.WindowButtonMotionFcn = '';
    figh.WindowButtonUpFcn = '';
    figure(figh); % set focus
end

    function wbdcbobjects(src,callbackdata)
        seltype = src.SelectionType;
        
        
        % src.Pointer = 'circle';
        cp = ah.CurrentPoint;
        
        xinit = round(cp(1,1));
        yinit = round(cp(1,2));
        
        if xinit>0 && yinit>0 && xinit<=size(him.pixclassif.CData,2) && yinit<=size(him.pixclassif.CData,1)
            
            
            im=him.pixclassif.CData(:,:,2);
            im(im>0)=1;
            im=bwlabel(im,4);
            
            %figure, imshow(im,[])
            
            val=im(yinit,xinit);
            if val>0 % make sure a real object is selescted
                
                if strcmp(seltype,'normal')
                    him.trackclassif.CData(:,:,3)=255*(im==val); % display different color depending whether objects are classified or trained
                    obj.traintrack(:,:,3,obj.frame)=255*(im==val);
                    
                    him.trackclassif.CData(:,:,1)=uint8(zeros(size(im)));
                    obj.traintrack(:,:,1,obj.frame)=uint8(zeros(size(im)));
                end
                
                if strcmp(seltype,'alt')
                    him.trackclassif.CData(:,:,3)=uint8(zeros(size(im)));
                    obj.traintrack(:,:,3,obj.frame)=uint8(zeros(size(im)));
                    
                    him.trackclassif.CData(:,:,1)=uint8(zeros(size(im)));
                    obj.traintrack(:,:,1,obj.frame)=uint8(zeros(size(im)));
                end
                
            end
            % hl = line('XData',xinit,'YData',yinit,...
            % 'Marker','p','color','b');
            % src.WindowButtonMotionFcn = {@wbmcb,2};
            % src.WindowButtonUpFcn = @wbucb;
            
            
            
        end
        %      if strcmp(seltype,'alt')
        %         src.Pointer = 'circle';
        %         cp = ah.CurrentPoint;
        %         xinit = cp(1,1);
        %         yinit = cp(1,2);
        %        % hl = line('XData',xinit,'YData',yinit,...
        %        % 'Marker','p','color','b');
        %         src.WindowButtonMotionFcn = {@wbmcb,1};
        %         src.WindowButtonUpFcn = @wbucb;
        %
        %      end
        
        
        
    end
end