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