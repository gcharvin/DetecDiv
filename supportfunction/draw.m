function [him, hp]=draw(obj,h,classif)

% function used to draw ROIs
% obj is an roi , h is a figure handle n which to draw it
%this function is called by the roi view() method

% updates number of channel if userTraining mode is on.

if nargin<3
    classif=[];
    % refresh='full';
end
% if nargin<4
%     refresh='full';
% end

if numel(h.UserData)~=0 % window is already displayed; therefore just update the figure
    him=h.UserData;
    hp=findobj(h,'Type','Axes');
    
    % sort Axes !
    s=[];
    %hp
    for i=1:numel(hp)
        s(i)=str2num(hp(i).Tag(7:end));
    end
    [q, ix]=sort(s);
    hp=hp(ix);
    
    
    updatedisplay(obj,him,hp,classif);
    return;
end

if numel(classif)>0
    if strcmp(classif.category{1},'Pixel') | strcmp(classif.category{1},'Object') % display properties for pixel classification
        
        % first create a decidated channel in the image matrix for pixel
        % classification if it is not exisiting
        
        %pix=find(classif.roi(i).channelid==classif.channel);
        
        %[pth fle ex]=fileparts(obj.path); % get the name of the current classification process
        % change here to use the reference to the classif being used
        
        %         pix = strfind(obj.display.channel, classif.strid);
        %
        %         cc=[];
        %         for i=1:numel(pix)
        %             if numel(pix{i})~=0
        %                 cc=i;
        %
        %                 break
        %             end
        %         end
        %
        %         pixelchannel=i;
        
        cc=obj.findChannelID(classif.strid);
        
        if numel(cc)==0 % create new empty array for user training (painting)
            matrix=uint16(zeros(size(obj.image,1),size(obj.image,2),1,size(obj.image,4)));
            obj.addChannel(matrix,classif.strid,[1 1 1],[0 0 0]);
            
            %pixelchannel=size(obj.image,3);
            %else
            
        else
            %pixelchannel=cc;
        end
        
        
        
    end
    if strcmp(classif.category{1},'Pedigree')
        ccpedigree=obj.findChannelID(classif.strid);
    end
end


% create display menu %

handles=findobj(h,'Tag','DisplayMenu');

if numel(handles)==0
    m = uimenu(h,'Text','Display','Tag','DisplayMenu');
    mitem=[];
    
    for i=1:numel(obj.display.channel)
        mitem(i) = uimenu(m,'Text',obj.display.channel{i},'Checked','on','Tag',['channel_' num2str(i)]);
        set(mitem(i),'MenuSelectedFcn',{@displayMenuFcn,obj,h,classif});
        
        pix=find(obj.channelid==i); % find matrix index associated with channel
        pix=pix(1); % there may be several items in case of a   multi-array channel
        
        if obj.display.selectedchannel(pix)==1
            set(mitem(i),'Checked','on');
        else
            set(mitem(i),'Checked','off');
        end
        
        if numel(classif)>0
        %    set(mitem(i),'Enable','off');
        else
            
        end
    end
end

% find channel to be displayed
cd=0;

        
for i=1:numel(obj.display.channel)
     pix=find(obj.channelid==i); % find matrix index associated with channel
 pix=pix(1); % there may be several items in case of a   multi-array channel
        
    if obj.display.selectedchannel(pix)==1
        cd=cd+1;
    end
end


% create draw menu

handles=findobj(h,'Tag','DrawMenu');

if numel(handles)==0
    dr = uimenu(h,'Text','Draw','Tag','DrawMenu');
    dritem = uimenu(dr,'Text','Add Channel','Tag','AddChannel');
    set(dritem,'MenuSelectedFcn',{@addChannel,obj});
    
    dritem(2) = uimenu(dr,'Text','Remove Channel','Tag','AddChannel');
    set(dritem(2),'MenuSelectedFcn',{@removeChannel,obj});
    
    dritem(3) = uimenu(dr,'Text','Draw object','Tag','Draw object','Separator','on');
    set(dritem(3),'MenuSelectedFcn',{@drawObject,obj});
end

% build display image object

im=buildimage(obj);

% display corresponding axes

cc=1;
him=[];
hp=[];

%pos=h.Position;

if numel(classif)>0
    %'ok'
    cmap=classif.colormap;
end

for i=1:numel(obj.display.channel)
    
    pix= find( obj.channelid==i);
    pix=pix(1);
    
    if obj.display.selectedchannel(pix)==1
        figure(h);
        
        if cd>1
            hp(cc)=subplot(1,cd,cc);
        else
            hp(cc)=axes('Units','normalized');
        end
        
        dis=0;
        % pixelchannel
        if numel(classif)>0
            if strcmp(classif.category{1},'Pixel') | strcmp(classif.category{1},'Object')% display user training and results
                % pixelchannel
             %   tmppix=obj.findChannelID(classif.strid);
             %    if pix==obj.findChannelID(classif.strid)
                if pix==obj.findChannelID(classif.strid)
                    dis=1;
                end
            end
        end
        
        if dis==0 %  channel to be displayed is not that of the ongoing classification
            if sum(obj.display.intensity(i,:))==0 % choose colormap to use to plot indexed data
                dis=1;
            %    tp=obj.image(:,:i,:);
                tp=obj.image(:,:,pix,:);
                maxe=double(max(tp(:)));
           %    maxe
                cmap=shallowColormap(maxe);
            end
        end
        % dis
     %   cc
       % size(im)
        
        if dis==0
            him.image(cc)=imshow(im(cc).data);
        else
            
            him.image(cc)=imshow(im(cc).data,cmap);
            % 'ok'
            %return;
        end
        
        set(hp(cc),'Tag',['AxeROI' num2str(cc)]);
        
        set(hp(cc),'UserData',obj.display.channel{i});
        
        %axis equal square
        %     tt=obj.display.intensity(i,:);
        
        %         if numel(classif)==0
        %             title(hp(cc),[obj.display.channel{i} ]); %' -Intensity:' num2str(tt)]);
        %         end
        
        if cd==1 % setting position in case of one axis, to adjust display size
            set(gca,'Position',[0.2 0.2 0.7 0.7]  );
        end
        
        cc=cc+1;
        
        
    end
end

if cd>0
    linkaxes(hp);
end


%========POSITION IMAGE=========
set(h,'Units', 'Normalized','Position',[0 0 1 1]);


h.UserData=him;

% reset mouse interaction function
h.WindowButtonDownFcn='';
h.Pointer = 'arrow';
h.WindowButtonMotionFcn = '';
h.WindowButtonUpFcn = '';


% add buttons and fcn to chanfe frame
keys={'a' 'z' 'e' 'r' 't' 'y' 'u' 'i' 'o' 'p' 'q' 's' 'd' 'f' 'g' 'h' 'j'};
h.KeyPressFcn={@changeframe,obj,him,hp,keys,classif};

handles=findobj(h,'Tag','frametexttitle');
if numel(handles)==0
    btnSetFrame = uicontrol('Style', 'text','FontSize',14, 'String', 'Enter frame number here, or use arrows <- ->',...
        'Position', [50 50 450 20],'HorizontalAlignment','left', ...
        'Tag','frametexttitle') ;
end

handles=findobj(h,'Tag','frametext');
if numel(handles)==0
    btnSetFrame = uicontrol('Style', 'edit','FontSize',14, 'String', num2str(obj.display.frame),...
        'Position', [50 20 80 20],...
        'Callback', {@setframe,obj,him,hp,classif},'Tag','frametext') ;
else
    handles.Callback=  {@setframe,obj,him,hp,classif};
    handles.String=num2str(obj.display.frame);
end

% create training specific menus and graphics
% training classes menu

% display user classification status
if numel(classif)>0
    
    if strcmp(classif.category{1},'Image')  || strcmp(classif.category{1},'LSTM') % display user training and results
        if numel(obj.train)==0 % new roi , training not yet used
            obj.train.(classif.strid)=[];
            obj.train.(classif.strid).id=zeros(1,size(obj.image,4));
        end
        
        %         if obj.train(obj.display.frame)==0 % user training
        %             str='not classified';
        %             colo=[0 0 0];
        %
        %         else
        %             str= obj.classes{obj.train(obj.display.frame)};
        %             colo=cmap(obj.train(obj.display.frame),:);
        %         end
        
        
        %         cc=1;
        %         for i=1:numel(obj.display.channel)
        %             if obj.display.selectedchannel(i)==1
        %                 tt=hp(cc).Title.String;
        %                 hp(cc).Title.String=[tt ' - ' str ' (training)'];
        %                 %title(hp(cc),str, 'Color',colo,'FontSize',20);
        %                 cc=cc+1;
        %             end
        %         end
    end
    
    if strcmp(classif.category{1},'Pixel') | strcmp(classif.category{1},'Object')  % display the axis associated with user training to paint on the channel
        
        %         pix = strfind(obj.display.channel, classif.strid);
        %         cc=[];
        %         for i=1:numel(pix)
        %             if numel(pix{i})~=0
        %                 cc=i;
        %
        %                 break
        %             end
        %         end
        
        cc=obj.findChannelID(classif.strid);
        
        if numel(cc)
            if obj.display.selectedchannel(cc)==1
              %  cha1= classif.channel(1)
                cha1=1;
                % axes where to copy the new axes
                axes(hp(cha1));
                alpha(0.8);
                
                cha1pos=get(hp(cha1),'Position');
                hcopy=findobj(hp,'UserData',classif.strid);
                %
                htmp = copyobj(hcopy,h);
                htmp.Position=cha1pos;
                % aa=classif.strid,
                %  h.Childr
                
                set(htmp,'Tag',classif.strid);
                axes(htmp);
                alpha(0.7);
                
                linkaxes([hp htmp]);
            end
        end
        
    end
    
    if strcmp(classif.category{1},'Pixel') | strcmp(classif.category{1},'Object') | (strcmp(classif.category{1},'Image') & classif.typeid~=11) | (strcmp(classif.category{1},'LSTM') & classif.typeid~=12)
        % plotting classes menu for classification
   
    
        handles=findobj('Tag','TrainingClassesMenu');
        
        if numel(handles)~=0
            delete(handles)
        end
        
        m = uimenu(h,'Text',[classif.category{1} 'Training Classes'],'Tag','TrainingClassesMenu');
        mitem=[];
        
        for i=1:numel(obj.classes)
          %  cmap

            mitem(i) = uimenu(m,'Text',obj.classes{i},'Checked','off','Tag',['classes_' num2str(i)],'ForegroundColor',cmap(i+1,:),'Accelerator',keys{i});
            
            if strcmp(classif.category{1},'Pixel') | strcmp(classif.category{1},'Object') % only in pixel mode
                hpaint=findobj('Tag',classif.strid); % if the painting axe is displayed
                if numel(hpaint)~=0
                    set(mitem(i),'MenuSelectedFcn',{@classesMenuFcn,h,obj,hpaint.Children(1),hcopy.Children(1),hpaint,classif});
                    
                end
            end
            
            %         if strcmp(classif.category{1},'Object') % only in object mode
            %             hpaint=findobj('Tag',classif.strid); % if the painting axe is displayed
            %             if numel(hpaint)~=0
            %                 set(mitem(i),'MenuSelectedFcn',{@classesMenuFcnObject,h,obj,hpaint.Children(1),hcopy.Children(1),hpaint,classif});
            %
            %             end
            %         end
            
            %     if obj.display.selectedchannel(i)==1
            %         set(mitem(i),'Checked','on');
            %     else
            %         set(mitem(i),'Checked','off');
            %     end
        end
        
        % change keypressfcn if painting is allowed to allow more functions
        %
         if strcmp(classif.category{1},'Pixel') | strcmp(classif.category{1},'Object') % only in pixel mode
        h.KeyPressFcn={@changeframe,obj,him,hp,keys,classif,hpaint.Children(1),hcopy.Children(1)};
%<<<<<<< HEAD
         else
        h.KeyPressFcn={@changeframe,obj,him,hp,keys,classif};   
         end
        
        
%=======
                
%>>>>>>> 589f21a9bbb3f84230a952fbece4d0e9d1d7fbf6
        %end
    end
    
    if strcmp(classif.category{1},'Pedigree') % Pedigree analysis 
        % nothing here to do
        hpaint=findobj(hp,'UserData',classif.strid);
        ccpedigree=obj.findChannelID(classif.strid);
        set(h,'WindowButtonDownFcn',{@pedigree,h,hpaint,obj,ccpedigree,hp,classif});%%% HERE
        
        plotLinks(obj,hp,classif);
        
    end
    
      if classif.typeid==11 || classif.typeid==12 % Regression training analysis 
        %ccpedigree=obj.findChannelID(classif.strid);
        set(h,'WindowButtonDownFcn',{@regression,h,obj,him,hp,classif});%%% HERE
     
      %  plotLinks(obj,hp,classif);     
    end
    
end

% display results for image classification & plot tracking results if
% available

cc=1;

% delete text handle if present
htext=findobj(gcf,'Tag','tracktext');

if numel(htext)>0
    if ishandle(htext)
        delete(htext);
    end
end

cctext=1;

%test
for i=1:numel(obj.display.channel)
    
     pix=find(obj.channelid==i); % find matrix index associated with channel
     pix=pix(1); % there may be several items in case of a   multi-array channel
        
    if obj.display.selectedchannel(pix)==1
        
        %hp=findobj('UserData',obj.display.channel{i});
        axes(hp(cc));
        str=obj.display.channel{i};
        
        if numel(obj.train)>0
            fields=fieldnames(obj.train);
            
            for k=1:numel(fields)
                tt=obj.train.(fields{k}).id(obj.display.frame);
                
                if isfield(obj.train.(fields{k}),'classes')
                    classesspe=obj.train.(fields{k}).classes; % classes name specfic to training
                else
                    classesspe=    obj.classes ;
                end
                
                if tt<0
                    tt='Not Clas.';
                else
                       % if tt <= length(obj.classes) & tt>=0
                       %     tt=obj.classes{tt};
                       % else
                       %     tt='N/A';
                        %end
                        tt=num2str(tt);
                end
                    
               %     tt
                    str=[str ' - ' tt ' (tr.: ' fields{k} ')'];
                    
                    %                         if obj.train(obj.display.frame)==0
                    %                             str=[str ' - not classified'];
                    %                     %title(hp(cc),str, 'Color',[0 0 0],'FontSize',20);
                    %                         else
                    %                             str= [str ' - ' obj.classes{obj.train(obj.display.frame)} ' (training)'];
                    %                     %title(hp(cc),str, 'Color',cmap(obj.train(obj.display.frame),:),'FontSize',20);
                    %                         end
              %  end
                
            end
        end
           
            % str=hp(cc).Title.String;
            
            if numel(obj.results)>0
                pl = fieldnames(obj.results);
                %aa=obj.results
                for k = 1:length(pl)
                    if isfield(obj.results.(pl{k}),'labels')
                     %   tt=char(obj.results.(pl{k}).labels(obj.display.frame));
                            tt=num2str(obj.results.(pl{k}).id(obj.display.frame));
                        str=[str ' - ' tt ' (' pl{k} ')'];
                    end
                    
                    if isfield(obj.results.(pl{k}),'mother')
                        % pedigree data available .
                        
                        if strcmp(['results_' pl{k}],str) % identify channel
                            
                            plotLinksResults(obj,hp,pl{k})
                            
                        end
                    end
                end
            end
            
            % display tracking results as numbers on each cell
            %him.image(cc) are the Data
            
            
            % display tracking numbers on cells
            % obj.display.channel{i}
            
            if numel(strfind(obj.display.channel{i},'track'))~=0 | numel(strfind(obj.display.channel{i},'pedigree'))~=0
                
                im=him.image(cc).CData;
                
                [l n]=bwlabel(im);
                r=regionprops(l,'Centroid');
                
                %'ok'
                
                for k=1:n
                    bw=l==k;
                    id=round(mean(im(bw)));
                    htext(cctext)=text(r(k).Centroid(1),r(k).Centroid(2),num2str(id),'Color',[1 1 1],'FontSize',20,'Tag','tracktext');
                    cctext=cctext+1; % update handle counter
                end
            end
            
            %test=get(hp(cc),'Parent')
            title(hp(cc),str,'FontSize',14,'interpreter','none');
            %title(hp(cc),str, 'Color',colo,'FontSize',20);
            cc=cc+1;
        end
    end
end

    function addChannel(handles, event,obj)
        matrix=uint16(zeros(size(obj.image,1),size(obj.image,2),1,size(obj.image,4)));
        rgb=[1 1 1];
        intensity=[0 0 0];
        answer = inputdlg({'Channel Name','RGB','Intensity'},'New CHannel',1,{'mychannel','[1 1 1]','[0 0 0]'});
        
        if numel(answer)==0
            return;
        end
        
        h=findobj('Tag',['ROI' obj.id]);
        close(h);
        obj.addChannel(matrix,answer{1},str2num(answer{2}),str2num(answer{3}));
        obj.view;  
    end

    function removeChannel(handles, event,obj)
        
        cha=numel(obj.channelid);
        answer = inputdlg({'Channel number to remove'},'Remove Channel',1,{num2str(cha)});
        
        if numel(answer)==0
            return;
        end
        
        h=findobj('Tag',['ROI' obj.id]);
        close(h);
        
        obj.removeChannel(str2num(answer{1}));
        obj.view;
    end


    function drawObject(handles, event,obj)
        
        cha=1;
        answer = inputdlg({'Channel id on which to draw ?'},'Draw',1,{num2str(cha)});
        
        if numel(answer)==0
            return;
        end
        
        h=findobj('Tag',['ROI' obj.id]);
        
        hp=findobj(h,'Tag','AxeROI1');
        
        xc=size(obj.image,2)/2;
        yc=size(obj.image,1)/2;
        sizx=40;
        sizy=30;
        
        windo=[xc-sizx yc-sizy 2*sizx 2*sizy];
        roi = imellipse(hp,windo);
        inputpoly = wait(roi);
        delete(roi);
        
        BW=poly2mask(inputpoly(:,1),inputpoly(:,2),size(obj.image,1),size(obj.image,2));
        BW=repmat(BW,[1 1 1 size(obj.image,4)]);
        
        obj.image(:,:,str2num(answer{1}),:)=uint16(obj.image(:,:,str2num(answer{1}),:) | BW);
        %h=findobj('Tag',['ROI' obj.id]);
        %close(h);
        obj.view;
    end


    function pedigree(handles, event,h,hpaint,obj,ccpedigree,hp,classif)
        
        cp = hpaint.CurrentPoint;
        
        xinit = cp(1,1);
        yinit = cp(1,2);
        
        im=obj.image(:,:,ccpedigree,obj.display.frame);
        
        daughter=0;
        % find object if any is selected
        if yinit>0 && xinit>0 && xinit< size(im,2)+1 && yinit<size(im,1)+1
            daughter= im(round(yinit),round(xinit));
        end
        
        if daughter==0
            return;
        end
        
        bw=im==daughter;
        stat=regionprops(bw,'Centroid');
        
        xinit=stat(1).Centroid(1);
        yinit=stat(1).Centroid(2);
        
        hl = line('XData',[xinit xinit],'YData',[yinit yinit], 'Marker','p','color','w','LineWidth',3);
        
        %hl= annotation('arrow',[xinit xinit],[yinit yinit],'Color',[1 1 1],'Units','pixels');
        % hl = line('XData',xinit,'YData',yinit,...
        % 'Marker','p','color','b');
        handles.WindowButtonMotionFcn = {@wmp,1};
        handles.WindowButtonUpFcn = @wup;
        
        x=1;
        y=1;
        
        
        function wmp(src,event,bsize)
            cp = hpaint.CurrentPoint;
            
            x = cp(1,1);
            y = cp(1,2);
            
            set(hl,'XData',[xinit x],'YData',[yinit y]);
            %hl.X=[xinit x];
            %hl.Y=[xinit y];
        end
        
        function wup(src,callbackdata)
            last_seltype = src.SelectionType;
            src.Pointer = 'arrow';
            src.WindowButtonMotionFcn = '';
            src.WindowButtonUpFcn = '';
            
            if ishandle(hl)
                delete(hl);
            end
            
            mother= im(round(y),round(x));
            
            % if mother==0
            %
            %  return;
            % end
            
            %             bw=im==mother;
            %             stat=regionprops(bw,'Centroid');
            %
            %             xinit=stat(1).Centroid(1);
            %             yinit=stat(1).Centroid(2);
            %mother,daughter
            str=hpaint.UserData;
            
            %pix=find(
            obj.train.(str).mother(daughter)=mother;
            
            
            if numel(obj.train.(str).mother)>=mother & mother>0
                if obj.train.(str).mother(mother)==daughter
                    obj.train.(str).mother(mother)=0;
                end
            end
            %pix=find(
            %obj.train.(str).mother(mother)=mother;
            
            plotLinks(obj,hp,classif)
        end 
    end

    function classesMenuFcn(handles, event, h,obj,impaint1,impaint2,hpaint,classif)
        
        if strcmp(handles.Checked,'off')
            
            for i=1:numel(classif.classes)
                ha=findobj('Tag',['classes_' num2str(i)]);
                
                if numel(ha)
                    ha.Checked='off';
                end
            end
            
            handles.Checked='on';
            %aa=handles.Tag
            %str=replace(handles.Tag,'classes_','');
            %colo=str2num(str);
            
            
            % set pixel painting mode
            if strcmp(classif.category{1},'Pixel')
                set(h,'WindowButtonDownFcn',@wbdcb);
            end
            
            if strcmp(classif.category{1},'Object')
                set(h,'WindowButtonDownFcn',@wbdcb2);
            end
            
            %ah = hp(1); %axes('SortMethod','childorder');
        else
            
            handles.Checked='off';
            str=handles.Tag;
            
            h.WindowButtonDownFcn='';
            h.Pointer = 'arrow';
            h.WindowButtonMotionFcn = '';
            h.WindowButtonUpFcn = '';
            figure(h); % set focus        
        end
        
        %[him hp]=draw(obj,h,classif);
        function wbdcb2(src,cbk)
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
        
        % nested function, good luck ;-) ....
        function wbdcb(src,cbk)
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
                
                
                switch bsize
                    case 2 % fine brush
                        % xdat = [cp(1,1) ];
                        %ydat = [cp(1,2) ];
                        
                        mix=max(1,cp(1,2));
                        miy=max(1,cp(1,1));
                        mux=min(size(ma,1),cp(1,2));
                        muy=min(size(ma,1),cp(1,1));
                             
                    case 1 % large brush
                        %xdat = [cp(1,1) cp(1,1)+1 cp(1,1)-1 cp(1,1)+1 cp(1,1)-1 cp(1,1) cp(1,1) cp(1,1)+1 cp(1,1)-1];
                        %ydat = [cp(1,2) cp(1,2)+1 cp(1,2)-1 cp(1,2)-1 cp(1,2)+1 cp(1,2)+1 cp(1,2)-1 cp(1,2) cp(1,2)];
                        
                        mix=max(1,cp(1,2)-1);
                        miy=max(1,cp(1,1)-1);
                        mux=min(size(ma,1),cp(1,2));
                        muy=min(size(ma,1),cp(1,1));
                        
                        %ma(mix:mux,miy:muy)=1;
                        % pis=ma>0;
                        
                    case 3 % huge brush
                        
                        % ma=zeros(size(obj,image,1),size(obj.image,2));
                        mix=max(1,cp(1,2)-8);
                        miy=max(1,cp(1,1)-8);
                        mux=min(size(ma,1),cp(1,2)+8);
                        muy=min(size(ma,1),cp(1,1)+8);
                        
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
    end
    
    
    function regression(handles,event,h,obj,him,hp,classif)
        
        cp = get(hp,'CurrentPoint');
        
        xinit = cp(1,1);
        yinit = cp(1,2);
        
%         im=obj.image(:,:,ccpedigree,obj.display.frame);
%         
%         daughter=0;
%         % find object if any is selected
%         if yinit>0 && xinit>0 && xinit< size(im,2)+1 && yinit<size(im,1)+1
%             daughter= im(round(yinit),round(xinit));
%         end
%         
%         if daughter==0
%             return;
%         end
%         
%         bw=im==daughter;
%         stat=regionprops(bw,'Centroid');
%         
%         xinit=stat(1).Centroid(1);
%         yinit=stat(1).Centroid(2);
        
        hl = line('XData',[xinit xinit],'YData',[yinit yinit], 'Marker','p','color','w','LineWidth',3);
        
        %hl= annotation('arrow',[xinit xinit],[yinit yinit],'Color',[1 1 1],'Units','pixels');
        % hl = line('XData',xinit,'YData',yinit,...
        % 'Marker','p','color','b');
        handles.WindowButtonMotionFcn = {@wmp,1};
        handles.WindowButtonUpFcn = @wup;
        
        x=1;
        y=1;
           
        function wmp(src,event,bsize)
          % cp = hpaint.CurrentPoint;
            cp = get(hp,'CurrentPoint');
            
            x = cp(1,1);
            y = cp(1,2);
            
            set(hl,'XData',[xinit x],'YData',[yinit y]);
            %hl.X=[xinit x];
            %hl.Y=[xinit y];
        end
        
        function wup(src,callbackdata)
            last_seltype = src.SelectionType;
            src.Pointer = 'arrow';
            src.WindowButtonMotionFcn = '';
            src.WindowButtonUpFcn = '';
            

            if ishandle(hl)
                
               ax=hl.XData;
               ay=hl.YData; 
                            
                delete(hl);
            end
            
            dist=sqrt((ax(2)-ax(1)).^2+(ay(2)-ay(1)).^2);
            %mother= im(round(y),round(x));
            
%            str=hpaint.UserData;
 
            obj.train.(classif.strid).id(obj.display.frame)=round(dist);
            
             updatedisplay(obj,him,hp,classif)
%             if numel(obj.train.(str).mother)>=mother & mother>0
%                 if obj.train.(str).mother(mother)==daughter
%                     obj.train.(str).mother(mother)=0;
%                 end
%             end
            %pix=find(
            %obj.train.(str).mother(mother)=mother;
            
           % plotLinks(obj,hp,classif)
        end
    end

    function displayMenuFcn(handles, event, obj,h,classif)
        
        if strcmp(handles.Checked,'off')
            handles.Checked='on';
            str=handles.Tag;
            i = str2num(replace(str,'channel_',''));
             pix=find(obj.channelid==i); % find matrix index associated with channel
             pix=pix(1); % there may be several items in case of a   multi-array channel
        
            obj.display.selectedchannel(pix)=1;
            % aa=obj.display.selectedchannel(i)
        else
            
            handles.Checked='off';
            str=handles.Tag;
            i = str2num(replace(str,'channel_',''));
            
            pix=find(obj.channelid==i); % find matrix index associated with channel
             pix=pix(1); % there may be several items in case of a   multi-array channel
            
            obj.display.selectedchannel(pix)=0;
            %  bb=obj.display.selectedchannel(i)
        end
        
        clf
        h.UserData=[];
        [him hp]=draw(obj,h,classif);
    end

    function updatedisplay(obj,him,hp,classif)
        
        % list=[];
        % for i=1:numel(obj.display.settings)
        %     handles=findobj('Tag',['channel_' num2str(i)]);
        %     if strcmp(handles.Checked,'on')
        %         list=[list i];
        %     end
        % end
        
        im=buildimage(obj);
        
        
        % need to update the painting window here hpaint.Children(1).CData...
   
        cc=1;
        for i=1:numel(obj.display.channel)     
            pix=find(obj.channelid==i); % find matrix index associated with channel
            pix=pix(1); % there may be several items in case of a   multi-array channel
             
            if obj.display.selectedchannel(pix)==1         
                him.image(cc).CData=im(cc).data;
                % title(hp(i),['Channel ' num2str(i) ' -Intensity:' num2str(obj.display.intensity(i))]);
                %tt=obj.display.intensity(i,:);        
                %title(hp(cc),[obj.display.channel{i} ' -Intensity:' num2str(tt)]);   
                cc=cc+1;
            end
        end

        if numel(classif)>0
            cmap=classif.colormap;         
            if strcmp(classif.category{1},'Pixel') | strcmp(classif.category{1},'Object')
                htmp=findobj('Tag',classif.strid);
                hpt=findobj(hp,'UserData',classif.strid);
                
                if numel(htmp) && numel(hpt)
                    htmp.Children(1).CData=hpt.Children(1).CData; % updates data on the painting window
                end       
            end
            
            if strcmp(classif.category{1},'Pedigree')
                plotLinks(obj,hp,classif);
            end
            
            %     if strcmp(classif.category{1},'Image') || strcmp(classif.category{1},'LSTM')
            %         cc=1;
            %         for i=1:numel(obj.display.channel)
            %             if obj.display.selectedchannel(i)==1
            %                 str='';
            %                 if obj.train(obj.display.frame)==0
            %                     str='not classified';
            %                     title(hp(cc),str, 'Color',[0 0 0],'FontSize',20);
            %                 else
            %                     str= obj.classes{obj.train(obj.display.frame)};
            %                     title(hp(cc),str, 'Color',cmap(obj.train(obj.display.frame),:),'FontSize',20);
            %                 end
            %
            %                 cc=cc+1;
            %             end
            %         end
            %     end
        end
        
        % display results for image classification
        htext=findobj(gcf,'Tag','tracktext');
        
        if numel(htext)>0
            if ishandle(htext)
                delete(htext);
            end
        end
        
        cc=1;
        cctext=1;
        for i=1:numel(obj.display.channel)
            pix=find(obj.channelid==i); % find matrix index associated with channel
             pix=pix(1); % there may be several items in case of a   multi-array channel
            if obj.display.selectedchannel(pix)==1
                axes(hp(cc));
                str=obj.display.channel{i};
                
                 if numel(obj.train)>0
            fields=fieldnames(obj.train);
            
            for k=1:numel(fields)
                tt=obj.train.(fields{k}).id(obj.display.frame);
                
                if isfield(obj.train.(fields{k}),'classes')
                    classesspe=obj.train.(fields{k}).classes; % classes name specfic to training
                else
                    classesspe=    obj.classes ;
                end
                
                
             
                
                if tt<0
                    tt='Not Clas.';
                else
                       % if tt <= length(obj.classes) & tt>=0
                       %     tt=obj.classes{tt};
                       % else
                       %     tt='N/A';
                        %end
                        tt=num2str(tt);
                end
                    
               %     tt
                    str=[str ' - ' tt ' (tr.: ' fields{k} ')'];
                    
                    %                         if obj.train(obj.display.frame)==0
                    %                             str=[str ' - not classified'];
                    %                     %title(hp(cc),str, 'Color',[0 0 0],'FontSize',20);
                    %                         else
                    %                             str= [str ' - ' obj.classes{obj.train(obj.display.frame)} ' (training)'];
                    %                     %title(hp(cc),str, 'Color',cmap(obj.train(obj.display.frame),:),'FontSize',20);
                    %                         end
              %  end
                
            end
        end
            
            % str=hp(cc).Title.String;
            
            if numel(obj.results)>0
                pl = fieldnames(obj.results);
                %aa=obj.results
                for k = 1:length(pl)
                    if isfield(obj.results.(pl{k}),'labels')
                     %   tt=char(obj.results.(pl{k}).labels(obj.display.frame));
                            tt=num2str(obj.results.(pl{k}).id(obj.display.frame));
                        str=[str ' - ' tt ' (' pl{k} ')'];
                    end
                    
                    if isfield(obj.results.(pl{k}),'mother')
                        % pedigree data available .
                        
                        if strcmp(['results_' pl{k}],str) % identify channel
                            
                            plotLinksResults(obj,hp,pl{k})            
                        end
                    end
                end
            end
            
%                 if numel(obj.train)>0
%                     fields=fieldnames(obj.train);
%                     
%                     for k=1:numel(fields)
%                         tt=obj.train.(fields{k}).id(obj.display.frame);
%                         
%                         if isfield(obj.train.(fields{k}),'classes')
%                             classesspe=obj.train.(fields{k}).classes; % classes name specfic to training
%                         else
%                             classesspe=    obj.classes ;
%                         end
%                         
%                         if tt==0
%                             tt='not classified';
%                         else
%                             if tt <= length(obj.classes)
%                                 tt=obj.classes{tt};
%                             else
%                                 tt='class unavailable';
%                             end
%                         end
%                         str=[str ' - ' tt ' (training: ' fields{k} ')'];
%                         
%                         %                         if obj.train(obj.display.frame)==0
%                         %                             str=[str ' - not classified'];
%                         %                     %title(hp(cc),str, 'Color',[0 0 0],'FontSize',20);
%                         %                         else
%                         %                             str= [str ' - ' obj.classes{obj.train(obj.display.frame)} ' (training)'];
%                         %                     %title(hp(cc),str, 'Color',cmap(obj.train(obj.display.frame),:),'FontSize',20);
%                         %                         end
%                     end
%                     
%                 end
%                 
%                 % str=hp(cc).Title.String;
%                 
%                 if numel(obj.results)>0
%                     pl = fieldnames(obj.results);
%                     %aa=obj.results
%                     for k = 1:length(pl)
%                         if isfield(obj.results.(pl{k}),'labels')
%                             tt=char(obj.results.(pl{k}).labels(obj.display.frame));
%                             str=[str ' - ' tt ' (' pl{k} ')'];
%                         end
%                         
%                         if isfield(obj.results.(pl{k}),'mother')
%                             % pedigree data available .
%                             
%                             if strcmp(['results_' pl{k}],str) % identify channel
%                                 
%                                 plotLinksResults(obj,hp,pl{k})
%                                 
%                             end
%                         end
%                     end
%                 end
%                 
                % display tracking numbers on cells
                if numel(strfind(obj.display.channel{i},'track'))~=0 | numel(strfind(obj.display.channel{i},'pedigree'))~=0 
                    im=him.image(cc).CData;
                    
                    [l n]=bwlabel(im);
                    r=regionprops(l,'Centroid');
              
                    for k=1:n
                        bw=l==k;
                        id=round(mean(im(bw)));
                        htext(cctext)=text(r(k).Centroid(1),r(k).Centroid(2),num2str(id),'Color',[1 1 1],'FontSize',20,'Tag','tracktext');
                        cctext=cctext+1;
                    end           
                end
       
                title(hp(cc),str,'FontSize',14,'interpreter','none');
                %title(hp(cc),str, 'Color',colo,'FontSize',20);
                cc=cc+1;
            end
        end
        
        htext=findobj(gcf,'Tag','frametext');
        htext.String=num2str(obj.display.frame);
        
        % if classif result is displayed, then update the position of the cursor
        
        htraj=findobj('Tag',['Traj' num2str(obj.id)]);
        if numel(htraj)~=0
            hl=findobj(htraj,'Tag','track');
            if numel(hl)>0
                hl.XData=[obj.display.frame obj.display.frame];
            end
        end

        %return;
        %axes(hp(1));    
    end

    function plotLinks(obj,hp,classif)
        mother=obj.train.(classif.strid).mother;
        
        hmother=findobj('Tag','mothertag');
        hmother2=findobj('Tag','mothertag2');
        
        hpt=findobj(hp,'UserData',classif.strid);
        hpt=findobj(hpt,'Type','Image');
        
        imtmp=hpt.CData;
        %imtmp=im(cc).data;
        
        if numel(hmother)>0
            if ishandle(hmother)
                delete(hmother);
            end
        end
        if numel(hmother2)>0
            if ishandle(hmother2)
                delete(hmother2);
            end
        end
        
        for i=1:numel(mother)
            if mother(i)~=0
                
                bw=imtmp==i;
                bw2=imtmp==mother(i);
                
                stat=regionprops(bw,'Centroid');
                stat2=regionprops(bw2,'Centroid');
                
                if numel(stat)==1 && numel(stat2)==1
                    x1=stat(1).Centroid(1);
                    y1=stat(1).Centroid(2);
                    
                    x2=stat2(1).Centroid(1);
                    y2=stat2(1).Centroid(2);

                    hmother(i)=line([x1 x2],[y1 y2],'Color',[0.9 0.9 0.9],'Tag','mothertag','LineWidth',3);
                    
                    x=x2+0.8*(x1-x2);
                    y=y2+0.8*(y1-y2);
                    
                    hmother2(i)=line([x x],[y y],'Color',[0.9 0.9 0.9],'Tag','mothertag2','LineWidth',3,'Marker','o','MarkerSize',10);
                end
                % HERE
                
            end
        end
    end

    function plotLinksResults(obj,hp,strid)
        mother=obj.results.(strid).mother;
        
        hmother=findobj('Tag','mothertagresults');
        hmother2=findobj('Tag','mothertagresults2');
        
        hpt=findobj(hp,'UserData',['results_' strid]);
        hpt=findobj(hpt,'Type','Image');
        
        imtmp=hpt.CData;
        %imtmp=im(cc).data;
        
        if numel(hmother)>0
            if ishandle(hmother)
                delete(hmother);
            end
        end
        if numel(hmother2)>0
            if ishandle(hmother2)
                delete(hmother2);
            end
        end
        
        for i=1:numel(mother)
            if mother(i)~=0           
                bw=imtmp==i;
                bw2=imtmp==mother(i);     
                stat=regionprops(bw,'Centroid');
                stat2=regionprops(bw2,'Centroid');
                
                if numel(stat)==1 && numel(stat2)==1
                    x1=stat(1).Centroid(1);
                    y1=stat(1).Centroid(2);         
                    x2=stat2(1).Centroid(1);
                    y2=stat2(1).Centroid(2);
           
                    hmother(i)=line([x1 x2],[y1 y2],'Color',[0.5 0.5 0.5],'Tag','mothertagresults','LineWidth',3);
                    
                    x=x2+0.8*(x1-x2);
                    y=y2+0.8*(y1-y2);
                    
                    hmother2(i)=line([x x],[y y],'Color',[0.5 0.5 0.5],'Tag','mothertagresults2','LineWidth',3,'Marker','o','MarkerSize',10);
                end
                % HERE
                
            end
        end
    end


    function im=buildimage(obj)
        
        % outputs a structure containing all displayed images
        im=[];
        im.data=[];
        
        frame=obj.display.frame;
        
        if numel(obj.image)==0
            disp('Warning : image is no longer present. Try reloading ...');
            obj.load
        end
 
        cc=1;
        for i=1:numel(obj.display.channel)
            
            pix=find(obj.channelid==i); % find matrix index associated with channel
            pix=pix(1); % there may be several items in case of a   multi-array channel
             
            if obj.display.selectedchannel(pix)==1
                % get the righ data: there may be several matrices for one single
                % channel in case of RGB images
                pix=find(obj.channelid==i);
                src=obj.image;
                
                % for each channel perform normalization
                %pix
                %INTENSITY
                if numel(pix)==1 % single channel to display
                    %pix
                    tmp=src(:,:,pix,:);
                     meangfp=0.3*double(mean(tmp(:)));
                      mingfp=double(min(tmp(:)));
                      maxgfp=double(0.7*max(tmp(:)));
                      
%                     % pix,i
                     it=mean(obj.display.intensity(i,:));
%                     maxgfp=double(meangfp+1*it*(max(tmp(:))-meangfp));
                    
                    if maxgfp==0
                        maxgfp=1;
                    end
                    % frame
                    % size(obj.image)
                    
                    imout=obj.image(:,:,pix,frame);
                    
                    if it~=0 % it=0 corresponds to binary or indexed images
                        imout=imadjust(imout,[mingfp/65535 maxgfp/65535],[0 1]);
                        % imout=mat2gray(imout,[meangfp maxgfp]);
                        % imout =repmat(imout,[1 1 3]);
                        % for k=1:3
                        %     imout(:,:,k)=imout(:,:,k).*obj.display.rgb(i,k);
                        % end
                    end
                else
                    %'ok'
                    imout=uint16(zeros(size(obj.image,1),size(obj.image,2),3));    
                    % size(imout)
                    %i    
                    for j=1:numel(pix)
                      %   i,j,pix(j)
                      %  tmp=src(:,:,pix(j),:);
                      %  meangfp=0.5*double(mean(tmp(:)));
                       % it=obj.display.intensity(i,j);
%                         maxgfp=double(meangfp+it*(max(tmp(:))-meangfp));
%                         if maxgfp==0
%                             maxgfp=1;
%                         end
                        imtemp=obj.image(:,:,pix(j),frame);
                        %size(imtemp)
                        
                       % if meangfp>0 && maxgfp>0
                        %    imtemp = imadjust(imtemp,[meangfp/65535 maxgfp/65535],[0 1]);
                        %end
                        
                        imout(:,:,j)=imtemp.*obj.display.rgb(i,j);
                    end
                end
                im(cc).data=imout;
                cc=cc+1;
            end
            %   cc=cc+1;
        end
    end

    function setframe(handle,event,obj,him,hp,classif )      
        frame=str2num(handle.String);   
        if frame<=size(obj.image,4) & frame > 0
            obj.display.frame=frame;
            updatedisplay(obj,him,hp,classif)
        end
    end

    function changeframe(handle,event,obj,him,hp,keys,classif,impaint1,impaint2)
        
        %hpaint.Children(1),hcopy.Children(1)
        
        ok=0;
        h=findobj('Tag',['ROI' obj.id]);
        
        % if strcmp(event.Key,'uparrow')
        % val=str2num(handle.Tag(5:end));
        % han=findobj(0,'tag','movi')
        % han.trap(val-1).view;
        % delete(handle);
        % end
        
        if strcmp(event.Key,'rightarrow')
            if obj.display.frame+1>size(obj.image,4)
                return;
            end
            
            obj.display.frame=obj.display.frame+1;
            frame=obj.display.frame+1;
            ok=1;
        end
        
        if strcmp(event.Key,'m') % move by 10 frames rights
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
        
        if strcmp(event.Key,'l') % move by 10 frames right
            if obj.display.frame-10<1
                return;
            end
            
            obj.display.frame=obj.display.frame-10;
            frame=obj.display.frame-10;
            ok=1;
        end
        
        if nargin==9 % only if painting is allowed
            if strcmp(event.Key,'k') % fill up painted contours     
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
                pix=find(obj.channelid==pixelchannel);
                obj.image(:,:,pix,obj.display.frame)=impaint2.CData;
                ok=1;
            end
        end
        
        if nargin==9 % only if painting is allowed
            if strcmp(event.Key,'uparrow') % 
                
                warning off all
                ax=findobj('Tag',classif.strid);
                al=ax.Children.AlphaData;
                ax.Children.AlphaData=min(al+0.2,1);
                warning on all
                
                %obj.display.intensity(obj.display.selectedchannel)=max(0.01,obj.display.intensity(obj.display.selectedchannel)-0.01);
                ok=1;
            end
            
%<<<<<<< HEAD
%            if strcmp(event.Key,'downarrow') %
                
%=======
            if strcmp(event.Key,'downarrow') % TO BE IMPLEMENTED      
%>>>>>>> 589f21a9bbb3f84230a952fbece4d0e9d1d7fbf6
                warning off all
                ax=findobj('Tag',classif.strid);
                al=ax.Children.AlphaData;
                ax.Children.AlphaData=max(al-0.2,0);
                warning on all
                % obj.display.intensity(obj.display.selectedchannel)=min(1,obj.display.intensity(obj.display.selectedchannel)+0.01);
                ok=1;
            end
        end
         
        for i=1:numel(keys) % display the selected class for the current image
            if i>numel(obj.classes)
                break
            end
            
            if strcmp(event.Key,keys{i})
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
        if ok==1
            updatedisplay(obj,him,hp,classif)
        end
    end
