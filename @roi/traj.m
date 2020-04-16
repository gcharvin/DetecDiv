function traj(obj,classistr)

% trajectory 

% classiid represents the strid of the classifier to be displayed


if numel(obj.results)==0
    disp('There is no result available for this position');
    return;
end

if ~isfield(obj.results,classistr)
    disp('There is no result available for this classification id');
    return;
end

% find class names

classes={};
cc=1;
for i=1:max(obj.results.(classistr).id)
    pix=find(obj.results.(classistr).id==i,1,'first');
    classes{cc}=char(obj.results.(classistr).labels(pix));
    cc=cc+1;
end
    
    
    
h=figure('Tag',['Traj' num2str(obj.id)],'Color','w','Position',[50 50 1000 500]);
set(gca,'FontSize',20);

x=1:numel(obj.results.(classistr).id);
y=obj.results.(classistr).id;

plot(x,y,'Color','k','LineWidth',2);
ylim([0 max(obj.results.(classistr).id)+1]);
set(gca,'YTick',1:max(obj.results.(classistr).id),'YTickLabel',classes,'Fontsize',14);

xlabel('Time (frames)');
ylabel('Classes');

title(

%ylabel('Budding state');
%set(gca,'YTick',[0 1 2],'YTickLabel',{'unbbuded','small b','large b'})

 %hp(2)=subplot(2,1,2);
 
 %obj.plotrls('plot','handle',hp(2));
 %xlim([0 x(end)])
 


%set(h,'WindowButtonDownFcn',{@wbdcb,xdiff,fluodiff,obj.div.raw,obj.div.classi});

%h.KeyPressFcn={@changeframe,obj};


function changeframe(handle,event,obj)

ok=0;

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

    obj.view(obj.frame+1);
    hl=findobj('Tag',['Trajline' num2str(obj.id)]);
    if numel(hl)>0
    hl.XData=[obj.frame obj.frame];
    end
   % ok=1;
end

if strcmp(event.Key,'leftarrow')
    if obj.frame-1<1
    return;
    end

    obj.view(obj.frame-1);
    hl=findobj('Tag',['Trajline' num2str(obj.id)]);
    if numel(hl)>0
    hl.XData=[obj.frame obj.frame];
    end
    %ok=1;
end

if strcmp(event.Key,'l') % move left to previous division
     
    if numel(obj.div.raw)>0
    pix=find(obj.div.raw(1:obj.frame-2)==1,1,'last');
    
    if numel(pix)
        
        obj.frame=pix+1;
        
        obj.view(obj.frame);
    hl=findobj('Tag',['Trajline' num2str(obj.id)]);
    if numel(hl)>0
    hl.XData=[obj.frame obj.frame];
    end
    
    end
    
    ok=1;
    end
 end
 if strcmp(event.Key,'m') % move right to next division
     
    if numel(obj.div.raw)>0
    pix=find(obj.div.raw(obj.frame+1:end)==1,1,'first');
    
    if numel(pix)
        obj.frame=pix+obj.frame+1;
        
        obj.view(obj.frame);
    hl=findobj('Tag',['Trajline' num2str(obj.id)]);
    if numel(hl)>0
    hl.XData=[obj.frame obj.frame];
    end
    
    end
    
    ok=1;
    end
 end


    
%     if strcmp(event.Key,'r') % reject divisions
%     if obj.frame>1
%        % 'ok'
%         if obj.div.raw(obj.frame-1)==1 % putative division
%           %  'ok'
%             if obj.div.reject(obj.frame-1)==0 % frame is not rejected
%              %   'ok'
%                 obj.div.reject(obj.frame-1)=1;
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
%             hr=findobj('Tag',['Traj' num2str(obj.id)]);
%             if numel(hr)>0
%             delete(hr);
%             end
%             
%             obj.traj;
%            %  h=findobj('Tag',['Trap' num2str(obj.id)]);
%            % figure(h);
%         end
%     end
%     ok=1;
%     end
    
     if strcmp(event.Key,'r') || strcmp(event.Key,'d' ) % reject divisions
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
            
            hr=findobj('Tag',['Traj' num2str(obj.id)]);
            if numel(hr)>0
            delete(hr);
            end
            
            obj.traj;
           %  h=findobj('Tag',['Trap' num2str(obj.id)]);
           % figure(h);
        end
    end
    ok=1;
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
    
    
end


function wbdcb(src,callbackdata,x,y,TF,TC)
     seltype = src.SelectionType;
   
     tmp=x(TF);
     
     if strcmp(seltype,'normal')
       % src.Pointer = 'circle';
        cp = hp(2).CurrentPoint;
       
        xinit = cp(1,1);
       % x
        yinit = cp(1,2);
        
        [d,idx] = min(abs(tmp-xinit));
        
        if d<10
       
         
        obj.view(tmp(idx));
        
        hl=findobj('Tag',['Trajline' num2str(obj.id)]);
        if numel(hl)>0
        hl.XData=[obj.frame obj.frame];
        end
            
        %plot(hp(2),x(idx),y(idx),'g*');
        end
     end
     
     if strcmp(seltype,'alt')
       % src.Pointer = 'circle';
        cp = hp(2).CurrentPoint;
       
        xinit = cp(1,1);
       % x
        yinit = cp(1,2);
        
        [d,idx] = min(abs(tmp-xinit));

        if d<10 % cursor must be less than 10 frames away from division position 
            
           % tmp(idx)
        if obj.div.reject(tmp(idx))==1
            obj.div.reject(tmp(idx))=0;
        else
            obj.div.reject(tmp(idx))=1;
        end

       % class(TF), class(obj.div.reject)
        
        plot(hp(2),x(TF),y(TF),'r*'); hold on;
        plot(hp(2),x(TC),y(TC),'g*'); hold on;
        plot(hp(2),x(obj.div.reject==1),y(obj.div.reject==1),'b*');
        end
     end
     
 end
end
     
     






