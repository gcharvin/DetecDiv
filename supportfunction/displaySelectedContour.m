function displaySelectedContour(src,hpaint,impaint1,val,colo)
% display contour selected to assign cell identity

bw=impaint1.CData;

if val>0
    %tmp=bw;
    %         sel=l==val;
    %         bw(sel)=colo;
    %         impaint1.CData=bw;
    %         impaint2.CData=bw;
    %
    %         pixelchannel=obj.findChannelID(classif.strid);
    %         pix=find(obj.channelid==pixelchannel);
    %
    %         obj.image(:,:,pix,obj.display.frame)=impaint2.CData;
    % HERE


    handles=findobj(src,'Tag','celltext');
    handles.String=num2str(val);

    sel=bw==val;
    B = bwboundaries(sel);
    B=B{1};

    p=findobj(hpaint,'Type','Line');
    if numel(p)
        delete(p);
    end

 
    hh=line(B(:,2),B(:,1),'Color',colo,'LineWidth',2,'UserData',val);


    %  roit=drawpolygon(hpaint,'InteractionsAllowed','none','Position',[xx ; yy]);


else
    handles=findobj(src,'Tag','celltext');
    handles.String='-';

    p=findobj(hpaint,'Type','Line');
    if numel(p)
        delete(p);
    end
end