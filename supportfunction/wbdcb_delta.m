function wbdcb_delta(src,event,obj,impaint1,impaint2,hpaint,classif,him,hp)
% function used to assign a number to an object

seltype = src.SelectionType;


%src.Pointer = 'circle';
cp = hpaint.CurrentPoint;

xinit = cp(1,1);
yinit = cp(1,2);

if xinit>size(obj.image,2) | xinit<1 | yinit<1 | yinit>size(obj.image,1)
    return;
end

%     hmenu = findobj('Tag','TrainingClassesMenu');
%     hclass=findobj(hmenu,'Checked','on');
%     strcolo=replace(hclass.Tag,'classes_','');
%     colo=str2num(strcolo);

bw=impaint1.CData;

%   [l n]=bwlabel(bw>0);

val=bw(round(yinit),round(xinit));

if strcmp(seltype,'normal') % basic cell selection
    colo=[1 1 1];
    displaySelectedContour(src,hpaint,impaint1,val,colo);
end

if strcmp(seltype,'alt') % swap cells
    prev=findobj(hpaint,'Type','Line');
    if numel(prev)
        prev=prev.UserData;

        if prev~=val
            colo=[1 0 0];
            displaySelectedContour(src,hpaint,impaint1,val,colo);
            pause(0.05);

            pixelchannel=obj.findChannelID(classif.strid);
            pixcha=find(obj.channelid==pixelchannel);

            if numel(pixcha)
                pixcellold= obj.image(:,:,pixcha,obj.display.frame:end)==prev; % pixels to be replace
                pixcellnew= obj.image(:,:,pixcha,obj.display.frame:end)==val;

                imtmp= obj.image(:,:,pixcha,obj.display.frame:end);
                imtmp(pixcellold)= val;
                imtmp(pixcellnew)= prev;

                obj.image(:,:,pixcha,obj.display.frame:end)=imtmp;
                updatedisplay(obj,him,hp,classif)

            end

            
            colo=[1 1 1];
            displaySelectedContour(src,hpaint,impaint1,prev,colo);
        end
    end
end

if strcmp(seltype,'extend') % swap cells

    if val~=0
        colo=[0 0 1];
        displaySelectedContour(src,hpaint,impaint1,val,colo);

        answer = questdlg('Suppress this cell ?', ...
            'Cell ID processing menu', ...
            'Forward','Backward','Cancel','Cancel');
        % Handle response
        switch answer
            case 'Forward'
                pixelchannel=obj.findChannelID(classif.strid);
                pixcha=find(obj.channelid==pixelchannel);

                if numel(pixcha)
                    pixcellnew= obj.image(:,:,pixcha,obj.display.frame:end)==val;

                    imtmp= obj.image(:,:,pixcha,obj.display.frame:end);

                    imtmp(pixcellnew)= 0;

                    obj.image(:,:,pixcha,obj.display.frame:end)=imtmp;

                    updatedisplay(obj,him,hp,classif);
                end
                 case 'Backward'
                pixelchannel=obj.findChannelID(classif.strid);
                pixcha=find(obj.channelid==pixelchannel);

                if numel(pixcha)
                    pixcellnew= obj.image(:,:,pixcha,1:obj.display.frame)==val;

                    imtmp= obj.image(:,:,pixcha,1:obj.display.frame);

                    imtmp(pixcellnew)= 0;

                    obj.image(:,:,pixcha,1:obj.display.frame)=imtmp;

                    updatedisplay(obj,him,hp,classif);
                end
            case 'Cancel'
                colo=[1 1 1];
                displaySelectedContour(src,hpaint,impaint1,0,colo);
        end
    end



end

end