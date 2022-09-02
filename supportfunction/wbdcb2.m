function wbdcb2(src,obj,impaint1,impaint2,hpaint)
% function used to assign a single class to objects 
seltype = src.SelectionType;

if strcmp(seltype,'normal')
    %src.Pointer = 'circle';
    cp = hpaint.CurrentPoint;

    xinit = cp(1,1);
    yinit = cp(1,2);

    if xinit>size(obj.image,2) | xinit<1 | yinit<1 | yinit>size(obj.image,1)
        return;
    end

    hmenu = findobj('Tag','TrainingClassesMenu');
    hclass=findobj(hmenu,'Checked','on');
    strcolo=replace(hclass.Tag,'classes_','');
    colo=str2num(strcolo);

    bw=impaint1.CData;
    [l n]=bwlabel(bw>0);

    %xinit,yinit
    val=l(round(yinit),round(xinit));

    if val>0
        %tmp=bw;
        sel=l==val;
        bw(sel)=colo;
        impaint1.CData=bw;
        impaint2.CData=bw;

        pixelchannel=obj.findChannelID(classif.strid);
        pix=find(obj.channelid==pixelchannel);

        obj.image(:,:,pix,obj.display.frame)=impaint2.CData;
        % HERE
    end


    % hl = line('XData',xinit,'YData',yinit,...
    % 'Marker','p','color','b');
    %src.WindowButtonMotionFcn = {@wbmcb,1};
    %src.WindowButtonUpFcn = @wbucb;

end
%         if strcmp(seltype,'alt')
%             src.Pointer = 'circle';
%             cp = hpaint.CurrentPoint;
%             xinit = cp(1,1);
%             yinit = cp(1,2);
%             % hl = line('XData',xinit,'YData',yinit,...
%             % 'Marker','p','color','b');
%             src.WindowButtonMotionFcn = {@wbmcb,2};
%             src.WindowButtonUpFcn = @wbucb;
%
%         end
end