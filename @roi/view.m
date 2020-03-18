function view(obj,frame)


if nargin==2
obj.frame=frame;    
end

frame=obj.frame;

%findobj('Tag',['Trap' num2str(obj.id)])

if numel(findobj('Tag',['Trap' obj.id])) % handle exists already
    h=findobj('Tag',['Trap' obj.id]);
    
    %h.Children(5).Tag
    
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
    updatedisplay(obj,him,hp);
else
im=buildimage(obj); % returns a structure with all images to be displayed

h=figure('Tag',['Trap' obj.id]);
hp(1)=subplot(2,2,1);
set(hp(1),'Tag','Axe1');

%aaa=hp(1).Tag
axis equal square

him.pixtraining=imshow(im.pixtraining);
hold on
him.pixtraining_raw=imshow(im.pixtraining_raw) ; % overlay raw gfp image to paint
him.pixtraining_raw.AlphaData=0.7;
hold off;

title(['Pixel Training - Trap: ' num2str(obj.id) '- Frame:' num2str(obj.frame) ' - Int:' num2str(obj.intensity)]);

hp(2)=subplot(2,2,2);
set(hp(2),'Tag','Axe2');
axis equal square
him.pixclassif=imshow(im.pixclassif);
title(['Pixel Classification - Trap: ' num2str(obj.id) '- Frame:' num2str(obj.frame)]);

hp(3)=subplot(2,2,3);
set(hp(3),'Tag','Axe3');
axis equal square

him.trackclassif=imshow(im.trackclassif,[]);

%hold on
%him.trackclassif=imshow(im.trackclassif) ; % overlay raw gfp image to paint
%him.trackclassif.AlphaData=0.1;
%hold off;

title(['Tracking Classification - Trap: ' num2str(obj.id) '- Frame:' num2str(obj.frame)]);

hp(4)=subplot(2,2,4);
set(hp(4),'Tag','Axe4');
axis equal square
him.overlay=imshow(im.overlay);
title('--');
%title(['Raw image - Trap: ' num2str(obj.id) '- Frame:' num2str(obj.frame) ' - Int:' num2str(obj.intensity)]);

%himage=imshow(display(obj,hp));

h.Position(3)=800;
h.Position(4)=800;

h.UserData=him;

h.KeyPressFcn={@changeframe,obj,him,hp};

%paint(him.pixtraining,h,hp,obj); % launches the function for pixel training

btnPaint = uicontrol('Style', 'togglebutton', 'String', 'Pixel Train',...
        'Position', [20 20 50 20],...
        'Callback', {@paint,him.pixtraining,h,hp,obj}) ;
    
btnClassify = uicontrol('Style', 'pushbutton', 'String', 'Classify pixels',...
        'Position', [120 20 80 20],...
        'Callback', {@classify,obj,him,hp}) ;
    
btnTrainObjects = uicontrol('Style', 'togglebutton', 'String', 'Objects train',...
        'Position', [220 20 80 20],...
        'Callback', {@trainobjects,h,hp,obj,him}) ;
    
btnSetFrame = uicontrol('Style', 'edit', 'String', num2str(obj.frame),...
        'Position', [320 20 80 20],...
        'Callback', {@setframe,obj,him,hp},'Tag','frametext') ;
    
btnSetDiv = uicontrol('Style', 'edit', 'String', 'No division',...
        'Position', [450 20 80 20],...
        'Callback', {},'Tag','divtext') ;
    
% btnTrainObjects2 = uicontrol('Style', 'pushbutton', 'String', 'Classify objects',...
%         'Position', [320 20 80 20],...
%         'Callback', {@classify,obj,him,hp}) ;

 if ~isfield(obj.div,'deep')
      obj.div.deep=[];  
      obj.div.deep=-ones(1,size(obj.gfp,3));
 end
 if ~isfield(obj.div,'deepCNN')
      obj.div.deepCNN=[];  
      obj.div.deepCNN=-ones(1,size(obj.gfp,3));
 end 
 if ~isfield(obj.div,'deepLSTM')
      obj.div.deepLSTM=[];  
      obj.div.deepLSTM=-ones(1,size(obj.gfp,3));
 end
    
end   
end

function classify(handle,event,obj,him,hp)
  obj.pixclassify(obj.frame);
  updatedisplay(obj,him,hp)
  % updates display
end

function im=buildimage(obj)

% outputs a structure containing all displayed images
im=[];

frame=obj.frame;

%obj.gfp

if numel(obj.gfp)==0
    obj.load
end

%aaa=obj.gfpchannel

rawphc=obj.gfp(:,:,frame,obj.phasechannel);

if frame>1
rawphc2=obj.gfp(:,:,frame-1,obj.phasechannel);
else
rawphc2=rawphc;    
end

if frame<size(obj.gfp,3)
rawphc3=obj.gfp(:,:,frame+1,1);
else
rawphc3=rawphc;    
end    

%difftmp=diff(double(obj.gfp(:,:,:,obj.phasechannel)),5,3);

%difftmp=difftmp(:,:,frame);
%difftmp(difftmp>0)=0; 
%difftmp=abs(difftmp);


%rawphc4=(double(rawphc3)-double(rawphc))-(double(rawphc)-double(rawphc2));
    
%figure, imshow(rawphc4,[])

rawgfp=obj.gfp(:,:,frame,obj.gfpchannel);

totgfp=obj.gfp(:,:,:,obj.gfpchannel);


meangfp=0.95*double(mean(totgfp(:)));
maxgfp=double(meangfp+obj.intensity*(max(totgfp(:))-meangfp));
maxgfp2=double(meangfp+obj.intensity*(max(totgfp(:))-meangfp));

totphc=obj.gfp(:,:,:,obj.phasechannel);
meanphc=0.5*double(mean(totphc(:)));
maxphc=double(meanphc+0.7*(max(totphc(:))-meanphc));


%figure, imshow(rawphc,[]);

train=obj.train(:,:,:,frame);
classi=obj.classi(:,:,:,frame);

track=obj.classi(:,:,2,frame); % get the segmentation from pixel classification

tracktrain=obj.traintrack(:,:,:,frame);%+128*temp; % get the manual object training

% pix training image


%limi=stretchlim(rawgfp,[0.1 obj.intensity]);
%limi(2)=max(limi(2),1.2*limi(1));

temp = imadjust(rawgfp,[meangfp/65535 maxgfp/65535],[0 1]);

%temp = imadjust(rawgfp,[limi(1) limi(2)],[0 1]);

imrgb=cat(3,temp,temp,temp);

%figure, imshow(imrgb,[])

impaint=train;

%impaint=cat(4,impaint,impaint);

im.pixtraining=impaint; % display RGB image of raw data to paint
im.pixtraining_raw=temp;

%  pix classification results
im.pixclassif=classi;

%  tracking classification results

im.trackclassif=tracktrain;

%  overlay
temp = imadjust(rawgfp,[meangfp/65535 maxgfp2/65535],[0 1]);
%temp = imadjust(rawgfp,[limi(1) limi(2)],[0 1]);

%di=16384+uint16(difftmp);%+16384;

%di2=uint16(16384+rawphc4);

rawphc = imadjust(rawphc,[meanphc/65535 maxphc/65535],[0 1]);

rawphc2 = imadjust(rawphc2,[meanphc/65535 maxphc/65535],[0 1]);

rawphc3 = imadjust(rawphc3,[meanphc/65535 maxphc/65535],[0 1]);

%imphc= uint16(cat(3,zeros(size(rawphc)),zeros(size(rawphc)),rawphc));

imphc=uint16(cat(3,zeros(size(rawphc)),zeros(size(rawphc)),zeros(size(rawphc))));

%di=uint16(di);
%max(max(di))
%mean2(di)

%min(min(di2))
%max(max(di2))

%di = imadjust(di,[double(min(min(di)))/65535 0.2*(double(max(max(di)))-double(min(min(di))))/65535+double(min(min(di))+1)/65535],[0 1]);

%di2 = imadjust(di2,[double(min(min(di2)))/65535 0.9*(double(max(max(di2)))-double(min(min(di2))))/65535+double(min(min(di2))+1)/65535],[0 1]);

%di2 = imadjust(di2,[0.2 0.35],[0 1]);


imphc(:,:,1)=rawphc;%2;

imphc(:,:,2)=rawphc;

imphc(:,:,3)=rawphc;%3;

%imgfp=uint16(zeros(size(imphc)));
%imgfp(:,:,2)=temp;
im.overlay=imphc; %imgfp+imphc;
end


function setframe(handle,event,obj,him,hp)

frame=str2num(handle.String);

if frame<size(obj.gfp,3) & frame > 0
    obj.frame=frame;
    updatedisplay(obj,him,hp)
    
    hl=findobj('Tag',['Trajline' obj.id]);
    if numel(hl)>0
    hl.XData=[obj.frame obj.frame];
    end
end
end


function changeframe(handle,event,obj,him,hp)

ok=0;
h=findobj('Tag',['Trap' obj.id]);

% if strcmp(event.Key,'uparrow')
% val=str2num(handle.Tag(5:end));
% han=findobj(0,'tag','movi')
% han.trap(val-1).view;
% delete(handle);
% end

if strcmp(event.Key,'rightarrow')
    if obj.frame+1>size(obj.gfp,3)
    return;
    end

    obj.frame=obj.frame+1;
    frame=obj.frame+1;
    ok=1;
end

if strcmp(event.Key,'leftarrow')
    if obj.frame-1<1
    return;
    end

    obj.frame=obj.frame-1;
    frame=obj.frame-1;
    ok=1;
end

if strcmp(event.Key,'uparrow')
    obj.intensity=max(0.01,obj.intensity-0.01);
    ok=1;
end

if strcmp(event.Key,'downarrow')
    obj.intensity=min(1,obj.intensity+0.01);
    ok=1;
end

if strcmp(event.Key,'u') % mark budding events for classification
    obj.div.deep(obj.frame)=0;
end

if strcmp(event.Key,'i') % mark budding events for classification
    obj.div.deep(obj.frame)=1;
end

if strcmp(event.Key,'o') % mark budding events for classification
    obj.div.deep(obj.frame)=2;
end

    %hp(4).title='budded';
%     if numel(obj.div.classi)==0
%         obj.div.classi=zeros(1,size(obj.gfp,3));
%         obj.div.raw=obj.div.classi; 
%         obj.div.reject=obj.div.classi;
%         
%         
%     else
%     
%     if obj.div.classi(obj.frame)==0
%     obj.div.classi(obj.frame)=1;
%     t=findobj(h,'Tag','divtext');
%     t.String='Divison';
%     else
%     obj.div.classi(obj.frame)=0;    
%     t=findobj(h,'Tag','divtext');
%     t.String='No divison';
%     end
%     
%     end
    
%end

 if strcmp(event.Key,'r') || strcmp(event.Key,'d' ) % reject or dead divisions
    if obj.frame>1
       % 'ok'
        if obj.div.raw(obj.frame-1)==1 % putative division
          %  'ok'
            if obj.div.reject(obj.frame-1)==0 % frame is not rejected
             %   'ok'
             
             if strcmp(event.Key,'r')
                obj.div.reject(obj.frame-1)=1;
             else
               
                obj.div.reject(obj.frame-1)=2;
              %  aa=obj.div.reject(obj.frame-1)
             end
                
%                 hreject=findobj('Tag',['Rejectplot' num2str(obj.id)]);
%                 hraw=findobj('Tag',['Rawplot' num2str(obj.id)]);
%                 hreject.XData=[hreject.XData obj.frame-1];
%                 hreject.YData=[hreject.YData hraw.YData(obj.frame-1)];
            else
                obj.div.reject(obj.frame-1)=0;
                
                %hreject=findobj('Tag',['Rejectplot' num2str(obj.id)]);
                %hraw=findobj('Tag',['Rawplot' num2str(obj.id)]);
                
%                 pix=find(hreject.XData==obj.frame-1);
%                 
%                 hreject.XData=hreject.XData( setxor(1:length(hreject.XData),pix));
%                 hreject.YData=hreject.YData( setxor(1:length(hreject.YData),pix));
            end
            
            hr=findobj('Tag',['Traj' obj.id]);
            if numel(hr)>0
            delete(hr);
            end
            
            obj.traj;
             h=findobj('Tag',['Trap' obj.id]);
            figure(h);
        end
    end
    ok=1;
 end
 
 if strcmp(event.Key,'l') % move left to previous division
     
    if numel(obj.div.raw)>0
    pix=find(obj.div.raw(1:obj.frame-2)==1,1,'last');
    
    if numel(pix)
        
        obj.frame=pix+1;
    end
    
    ok=1;
    end
 end
 if strcmp(event.Key,'m') % move right to next division
     
    if numel(obj.div.raw)>0
    pix=find(obj.div.raw(obj.frame+1:end)==1,1,'first');
    
    if numel(pix)
        obj.frame=pix+obj.frame+1;
    end
    
    ok=1;
    end
 end
 
   if strcmp(event.Key,'s') % stop training at given frame
        if obj.frame==obj.div.stop
            obj.div.stop=size(obj.gfp,3);
        else
            obj.div.stop=obj.frame;
        end
        
        hl=findobj('Tag',['Stopline' num2str(obj.id)]);
            if numel(hl)>0
                hl.XData=[obj.div.stop obj.div.stop];
            end
            
        ok=1;
     end
 
 


if ok==1

updatedisplay(obj,him,hp)

 hl=findobj('Tag',['Trajline' obj.id]);
    if numel(hl)>0
    hl.XData=[obj.frame obj.frame];
    end  
end
end

function updatedisplay(obj,him,hp)

im=buildimage(obj);

him.overlay.CData=im.overlay;
him.pixtraining.CData=im.pixtraining;
him.pixtraining_raw.CData=im.pixtraining_raw;
him.pixclassif.CData=im.pixclassif;
him.trackclassif.CData=im.trackclassif;
%him.trackclassif2.CData=im.trackclassif2;


title(hp(1),['Pixel Training - Trap: ' obj.id '- Frame:' num2str(obj.frame) ' - Int:' num2str(obj.intensity)]);
title(hp(2),['Pixel Classification - Trap: ' obj.id '- Frame:' num2str(obj.frame)]);
title(hp(3),['Tracking Classification - Trap: ' obj.id '- Frame:' num2str(obj.frame)]);
%title(hp(4),['Raw image - Trap: ' obj.id '- Frame:' num2str(obj.frame) ' - Int:' num2str(obj.intensity)]);

if ~isfield(obj.div,'deep')
      obj.div.deep=[]; 
end
    if numel(obj.div.deep)==0
        obj.div.deep=zeros(1,size(obj.gfp,3));
    end
    
    if ~isfield(obj.div,'deepLSTM')
      obj.div.deepLSTM=[]; 
end
    if numel(obj.div.deepLSTM)==0
        obj.div.deepLSTM=zeros(1,size(obj.gfp,3));
    end

      if ~isfield(obj.div,'deepCNN')
      obj.div.deepCNN=[]; 
end
    if numel(obj.div.deepCNN)==0
        obj.div.deepCNN=zeros(1,size(obj.gfp,3));
    end
 
switch obj.div.deep(obj.frame)
    case -1 
         str='- ';
    case 0
        str='unbud ';
    case 1
        str='small b ';
    case 2
        str='large b ';
end

switch obj.div.deepCNN(obj.frame)
    case -1
        str=[str 'CNN:- '];
    case 0
        str=[str 'CNN:unbud '];
    case 1
        str=[str 'CNN:small b '];
    case 2
        str=[str 'CNN:large b '];
end

switch obj.div.deepLSTM(obj.frame)
    case -1
        str=[str ' LSTM:- '];
    case 0
        str=[str ' LSTM:unbud '];
    case 1
        str=[str ' LSTM:small b '];
    case 2
        str=[str ' LSTM:large b '];
end


title(hp(4),str);%,'FontSize',20);

h=findobj('Tag',['Trap' obj.id]);
    
t=findobj(h,'Tag','frametext');

t.String=num2str(obj.frame);

t=findobj(h,'Tag','divtext');
t.String='No divison';

if numel(obj.div.raw)>0
if obj.frame>1
if obj.div.raw(obj.frame-1)==1
  t.String='Division ?';
end

%tt=obj.div.classi

 if obj.div.classi(obj.frame)==1
 
   t.String='Division';
 end

% if obj.div.classi(obj.frame-1)==1
% 
%   t.String='Division';
% end

if obj.div.reject(obj.frame-1)==1
  t.String='Rejected division';
end

if obj.div.reject(obj.frame-1)==2
  t.String='Dead division';
end

end
end

end


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