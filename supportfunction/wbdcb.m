function wbdcb(src,event,obj,impaint1,impaint2,hpaint,classif,h,userprefs)
% function used to paint pixels on image
seltype = src.SelectionType;
ma=zeros(size(obj.image,1),size(obj.image,2));


if strcmp(seltype,'normal') % paint with middle sized brush
    src.Pointer = 'cross';

    cp = hpaint.CurrentPoint;

    xinit = cp(1,1);
    yinit = cp(1,2);

    % hl = line('XData',xinit,'YData',yinit,...
    % 'Marker','p','color','b');
    src.WindowButtonMotionFcn = {@wbmcb,1};
    src.WindowButtonUpFcn = @wbucb;

end
if strcmp(seltype,'alt') % paint with middle small brush
    src.Pointer = 'cross';
    cp = hpaint.CurrentPoint;
    xinit = cp(1,1);
    yinit = cp(1,2);
    % hl = line('XData',xinit,'YData',yinit,...
    % 'Marker','p','color','b');
    src.WindowButtonMotionFcn = {@wbmcb,2};
    src.WindowButtonUpFcn = @wbucb;

end
if strcmp(seltype,'extend') % paint with middle large brush
    src.Pointer = 'cross';

    cp = hpaint.CurrentPoint;
    xinit = cp(1,1);
    yinit = cp(1,2);
    % hl = line('XData',xinit,'YData',yinit,...
    % 'Marker','p','color','b');
    src.WindowButtonMotionFcn = {@wbmcb,3};
    src.WindowButtonUpFcn = @wbucb;

end

if strcmp(seltype,'open') % paint whole connected area into the selected class color
    % double click


    % find the color to paint in
    hmenu = findobj('Tag','TrainingClassesMenu');
    hclass=findobj(hmenu,'Checked','on');
    strcolo=replace(hclass.Tag,'classes_','');
    colo=str2num(strcolo);

    % get the pointed pixel
    cp = hpaint.CurrentPoint;
    xinit = uint16(round(cp(1,1)));
    yinit = uint16(round(cp(1,2)));

    %gather the list of pixel to paint

    if xinit>size(impaint1.CData,2)
        return
    end
    if yinit>size(impaint1.CData,1)
        return
    end

    val=impaint1.CData(yinit,xinit); %

    [L nlab]=bwlabel(impaint1.CData==val);

    for j=1:nlab
        bwtemp=L==j;
        if bwtemp(yinit,xinit)==1 % found the connected to which the init pixel belongs

            BW=~bwtemp;

            imdist=bwdist(BW);
            imdist = imclose(imdist, strel('disk',2));
            imdist = imhmax(imdist,1);

            sous=- imdist;

            %figure, imshow(BW,[]);

            labels = double(watershed(sous,8)).* ~BW; % do a watershed to cut objects

            for k=1:max(labels(:))
                bwtemp2=labels==k;

                if bwtemp2(yinit,xinit)==1
                    impaint1.CData(bwtemp2)=colo;
                    impaint2.CData(bwtemp2)=colo;

                    %     pixelchannel=obj.findChannelID(classif.strid);
                    pix=obj.findChannelID(classif.strid);
                    %pix=find(obj.channelid==pixelchannel)

                    obj.image(:,:,pix,obj.display.frame)=impaint2.CData;

                    drawnow
                    break
                end
            end
        end
    end
end

    function wbmcb(src,event,bsize) % paint pixels while pressing left or right button
        cp = hpaint.CurrentPoint;
        % For R2014a and earlier:
        % cp = get(ah,'CurrentPoint');

        %xdat = [xinit,cp(1,1)]
        %ydat = [yinit,cp(1,2)]

        tz=zoom(h);
        tp=pan(h);

        if strcmp(tz.Enable,'on')  || strcmp(tp.Enable,'on')
            %  disp('not available,  set zoom and pan will be set off');

            %    disp('nogood')
            return;
        end


        switch bsize
            case 2 % fine brush

                si=round(sqrt(userprefs.painting_small_brush_size));
                mix=max(1,cp(1,2)-(si-1));
                miy=max(1,cp(1,1)-(si-1));
                mux=min(size(ma,1),cp(1,2)+(si-1));
                muy=min(size(ma,2),cp(1,1)+(si-1));

            case 1 % large brush

                si=round(sqrt(userprefs.painting_large_brush_size));
                mix=max(1,cp(1,2)-(si-1));
                miy=max(1,cp(1,1)-(si-1));
                mux=min(size(ma,1),cp(1,2)+(si-1));
                muy=min(size(ma,2),cp(1,1)+(si-1));

                %ma(mix:mux,miy:muy)=1;
                % pis=ma>0;

            case 3 % huge brush

                si=round(sqrt(userprefs.painting_huge_brush_size));
                mix=max(1,cp(1,2)-(si-1));
                miy=max(1,cp(1,1)-(si-1));
                mux=min(size(ma,1),cp(1,2)+(si-1));
                muy=min(size(ma,2),cp(1,1)+(si-1));

                %ma(mix:mux,miy:muy)=1;
                %pis=ma>0;
                % HERE
        end

        ma(round(mix):round(mux),round(miy):round(muy))=1;
        pis=ma>0;

        % find the right color
        hmenu = findobj('Tag','TrainingClassesMenu');
        hclass=findobj(hmenu,'Checked','on');
        strcolo=replace(hclass.Tag,'classes_','');
        colo=str2num(strcolo);

        if numel(pis)>=0

            %imtemp=imobj.CData;

            sz=size(obj.image);
            sz=sz(1:2);

            % impaint1.CData(linearInd)=colo;
            % impaint2.CData(linearInd)=colo;

            impaint1.CData(pis)=colo;
            impaint2.CData(pis)=colo;


            % dave data in obj.image object

            %                 pix = strfind(obj.display.channel, classif.strid);
            %
            %                 %                first find the right channel
            %                 cc=[];
            %                 for k=1:numel(pix)
            %                     if numel(pix{k})~=0
            %                         cc=k;
            %
            %                         break
            %                     end
            %                 end

            %     pixelchannel=obj.findChannelID(classif.strid);
            pix=obj.findChannelID(classif.strid);
            %pix=find(obj.channelid==pixelchannel)

            obj.image(:,:,pix,obj.display.frame)=impaint2.CData;

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