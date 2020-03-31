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

if nargin<3 
   category=[]; 
end
    
frame=obj.display.frame;

if numel(findobj('Tag',['ROI' obj.id])) % handle exists already
    h=findobj('Tag',['ROI' obj.id]);
else
    h=figure('Tag',['ROI' obj.id],'MenuBar','none','Toolbar','none');
end
 draw(obj,h,category);
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


