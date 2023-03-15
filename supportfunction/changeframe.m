function changeframe(handle,event,obj,him,hp,keys,classif,specialkeys,userprefs,impaint1,impaint2,hpaint)

%hpaint.Children(1),hcopy.Children(1)

ok=0;
h=findobj('Tag',['ROI' obj.id]);

% if strcmp(event.Key,'uparrow')
% val=str2num(handle.Tag(5:end));
% han=findobj(0,'tag','movi')
% han.trap(val-1).view;
% delete(handle);
% end

str=event.Key; str2=strfind(str,'numpad');
if numel(str2) % user pressed
    val=str2num(str(end)); % key that was pressed
    siz=size(him.image(1).CData);

    if val~=0
        cutt= {[3 1], [3 2], [3 3], [2 1],[2 2],[2 3], [1 1], [1 2], [1 3]};



        xl= [(cutt{val}(2)-1)*siz(2)/3-10 cutt{val}(2)*siz(2)/3 ];
        yl= [(cutt{val}(1)-1)*siz(1)/3-10 cutt{val}(1)*siz(1)/3 ];
    else
        xl=[0 siz(2)];
        yl=[0 siz(1)];
    end

    set(hp(1),'XLim',xl);
    set(hp(1),'YLim',yl);


end

if strcmp(event.Key,'rightarrow')
    if obj.display.frame+1>size(obj.image,4)
        return;
    end

    obj.display.frame=obj.display.frame+1;
    frame=obj.display.frame+1;
    ok=1;
end

if strcmp(event.Key,specialkeys{3}{2}) % move by 10 frames rights
    if obj.display.frame+10>size(obj.image,4)
        return;
    end

    obj.display.frame=obj.display.frame+10;
    frame=obj.display.frame+10;
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

if strcmp(event.Key,specialkeys{3}{1}) % move by 10 frames right
    if obj.display.frame-10<1
        return;
    end

    obj.display.frame=obj.display.frame-10;
    frame=obj.display.frame-10;
    ok=1;
end

if nargin>9 % only if painting is allowed
    if strcmp(event.Key,specialkeys{4}{1}) % fill up painted contours
        hmenu = findobj('Tag','TrainingClassesMenu');
        hclass=findobj(hmenu,'Checked','on');
        if numel(hclass)==0
            disp('first make sure that a given class is checked !');
            return;
        end

        strcolo=replace(hclass.Tag,'classes_','');
        colo=str2num(strcolo);
        pix= impaint2.CData==colo;
        imend=imfill(pix,'holes');
        impaint1.CData(imend)= colo;
        impaint2.CData(imend)= colo;
        pixelchannel=obj.findChannelID(classif.strid);
        %   pix=find(obj.channelid==pixelchannel)
        obj.image(:,:,pixelchannel,obj.display.frame)=impaint2.CData;
        ok=1;
    end
end

if numel(classif)
if  strcmp(classif.category{1},'Pixel') | strcmp(classif.category{1},'Object')  | strcmp(classif.category{1},'Delta')  | strcmp(classif.category{1},'Pedigree')
%if nargin>9 % only if painting is allowed
    if strcmp(event.Key,'uparrow')  || strcmp(event.Key,specialkeys{5}{2}) %
        disp('Increase painting image contrast')
                warning off all
        ax=findobj('Tag',classif.strid);
        tm=findobj(ax,'Type','Image');
        al=tm.AlphaData;
        tm.AlphaData=min(al+0.1,1);
        warning on all

        %obj.display.intensity(obj.display.selectedchannel)=max(0.01,obj.display.intensity(obj.display.selectedchannel)-0.01);
        ok=1;
    end

    if strcmp(event.Key,'downarrow')  || strcmp(event.Key,specialkeys{5}{1})  % TO BE IMPLEMENTED
       disp('Decrease painting image contrast')
        warning off all
        ax=findobj('Tag',classif.strid);
        tm=findobj(ax,'Type','Image');
        al=tm.AlphaData;
        tm.AlphaData=max(al-0.1,0);
        warning on all
        % obj.display.intensity(obj.display.selectedchannel)=min(1,obj.display.intensity(obj.display.selectedchannel)+0.01);
        ok=1;
    end
end
end

if numel(classif)>0
    if  strcmp(classif.category{1},'Image')  || strcmp(classif.category{1},'LSTM')% if image classification, assign class to keypress even
        if ~isfield(obj.train.(classif.strid),'bounds')
            obj.train.(classif.strid).bounds=[0 0];
        else
            if strcmp(event.Key,specialkeys{2}{1}) 
                obj.train.(classif.strid).bounds(1)=obj.display.frame;
            end
            if strcmp(event.Key,specialkeys{2}{2}) 
                obj.train.(classif.strid).bounds(2)=obj.display.frame;
            end
        end

        if strcmp(event.Key,'k')
            if strcmp(h.UserData.correctionMode,'1')
                if isfield(obj.train,classif.strid)
                    if numel(obj.train.(classif.strid).id)>0
                        if isfield(obj.results,classif.strid)
                            if numel(obj.results.(classif.strid).id)>0
                                if obj.display.frame<size(obj.image,4)
                                    aa1=obj.results.(classif.strid).id(obj.display.frame+1:end);
                                    aa2=obj.train.(classif.strid).id(obj.display.frame+1:end);

                                    pix1=find( aa1-aa2~=0,1,'first');
                                    obj.display.frame=obj.display.frame+pix1;
                                end
                            end
                        end
                    end
                end
            end
            if strcmp(h.UserData.correctionMode,'2')
                if isfield(obj.train,classif.strid)
                    if numel(obj.train.(classif.strid).id)>0
                        if isfield(obj.results,classif.strid)
                            if numel(obj.results.(classif.strid).id)>0

                                pix=h.UserData.correctionSort;
                                xx=find(pix==obj.display.frame);
                                if xx+1<size(obj.image,4)
                                    obj.display.frame=pix(xx+1);
                                end
                            end
                        end
                    end
                end
            end
        end
        if strcmp(event.Key,'j')
            if strcmp(h.UserData.correctionMode,'1')
                if isfield(obj.train,classif.strid)
                    if numel(obj.train.(classif.strid).id)>0
                        if isfield(obj.results,classif.strid)
                            if numel(obj.results.(classif.strid).id)>0
                                if obj.display.frame>1
                                    aa1=obj.results.(classif.strid).id(1:obj.display.frame-1);
                                    aa2=obj.train.(classif.strid).id(1:obj.display.frame-1);

                                    pix1=obj.display.frame-find( aa1-aa2~=0,1,'last');
                                    obj.display.frame=obj.display.frame-pix1;
                                end
                            end
                        end
                    end
                end
            end
            if strcmp(h.UserData.correctionMode,'2')
                if isfield(obj.train,classif.strid)
                    if numel(obj.train.(classif.strid).id)>0
                        if isfield(obj.results,classif.strid)
                            if numel(obj.results.(classif.strid).id)>0

                                pix=h.UserData.correctionSort;
                                xx=find(pix==obj.display.frame);
                                if xx-1>0
                                    obj.display.frame=pix(xx-1);
                                end
                            end
                        end
                    end
                end
            end
        end

        ok=1;
    end
end

for i=1:numel(keys) % display the selected class for the current image
    if i>numel(obj.classes)
        break
    end

    if strcmp(event.Key,keys{i})
        if numel(classif)>0
            if  strcmp(classif.category{1},'Image') || strcmp(classif.category{1},'LSTM')% if image classification, assign class to keypress event
                obj.train.(classif.strid).id(obj.display.frame)=i;
                ok=1;
            end


            if strcmp(classif.category{1},'Pixel') | strcmp(classif.category{1},'Object') % for pixel classification enable painting function for the given class
                for j=1:numel(classif.classes)
                    ha=findobj('Tag',['classes_' num2str(j)]);
                    if numel(ha)
                        if j~=i
                            ha.Checked='off';
                        else
                            % if strcmp(ha.Checked,'off')
                            ha.Checked='on';

                            tz=zoom(gcf);
                            tp=pan(gcf);

                            if strcmp(tz.Enable,'on') || strcmp(tp.Enable,'on')
                                %  disp('not available,  set zoom and pan will be set off');
                                tz.Enable='off';
                                tp.Enable='off';
                                %    return;
                            end

                            % set pixel painting mode
                            if strcmp(classif.category{1},'Pixel')
                                set(h,'WindowButtonDownFcn',{@wbdcb,obj,impaint1,impaint2,hpaint,classif,h,userprefs});
                            end

                            if strcmp(classif.category{1},'Object')
                                set(h,'WindowButtonDownFcn',{@wbdcb2,impaint1,impaint2,h});
                            end
                            % else
                            % ha.Checked='off';
                            % h.WindowButtonDownFcn='';
                            % h.Pointer = 'arrow';
                            % h.WindowButtonMotionFcn = '';
                            % h.WindowButtonUpFcn = '';
                            %figure(h); % set focus
                            % end
                            %draw(obj,h);
                        end
                    end
                end
            end
        end
    end
end
if ok==1
    updatedisplay(obj,him,hp,classif)
end
end