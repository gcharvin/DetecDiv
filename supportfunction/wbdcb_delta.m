function wbdcb_delta(src,event,obj,impaint1,impaint2,hpaint)
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

     if strcmp(seltype,'normal')
        colo=[1 1 1];
    end

    if strcmp(seltype,'open')
        colo=[1 0 0];
    end

   displaySelectedContour(src,hpaint,impaint1,val,colo);

end