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


% % This should work in both HG1 and HG2:
% hManager = uigetmodemanager(h);
% try
%     set(hManager.WindowListenerHandles, 'Enable', 'off');  % HG1
% catch
%     [hManager.WindowListenerHandles.Enabled] = deal(false);  % HG2
% end
% set(h, 'WindowKeyPressFcn', []);
%set(hFig, 'KeyPressFcn', @myKeyPressCallback);

h.Name=['ROI# :' obj.id]; 

if numel(h.UserData)~=0 % window is already displayed; therefore just update the figure
    him=h.UserData.him;
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
    
    obj.display.selectedchannel=zeros(1,numel(obj.display.selectedchannel));
    
    ps=find(matches(obj.display.channel,classif.channelName{1}));
    if numel(ps)
        obj.display.selectedchannel(ps)=1;
    end

    pix =obj.findChannelID(classif.strid);
    pix= obj.channelid(pix);
    obj.display.selectedchannel(pix)=1;
    
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
        
        % here !!!!!
        if obj.display.selectedchannel(i)==1
            % if obj.display.selectedchannel(pix)==1
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
    
    
    if obj.display.selectedchannel(i)==1
        %    i
        %   if obj.display.selectedchannel(pix)==1
        cd=cd+1;
    end
end


% create draw menu

handles=findobj(h,'Tag','DrawMenu');

if numel(handles)==0
    dr = uimenu(h,'Text','Draw','Tag','DrawMenu');
    dritem = uimenu(dr,'Text','Add Channel','Tag','AddChannel');
    set(dritem,'MenuSelectedFcn',{@addChannel,obj});
    
    dritem(2) = uimenu(dr,'Text','Remove Channel','Tag','RemoveChannel');
    set(dritem(2),'MenuSelectedFcn',{@removeChannel,obj});
    
    dritem(3) = uimenu(dr,'Text','Copy frames between channels','Tag','CopyFrames');
    set(dritem(3),'MenuSelectedFcn',{@copyFrames,obj});
    
    dritem(4) = uimenu(dr,'Text','Draw object','Tag','Draw object','Separator','on');
    set(dritem(4),'MenuSelectedFcn',{@drawObject,obj});
    
 
      if numel(classif)>0
           if strcmp(classif.category{1},'Image')  || strcmp(classif.category{1},'LSTM') % display user training and results
               
     dr = uimenu(h,'Text','Classification options','Tag','Classification');
     
    dritem = uimenu(dr,'Text','Assign classes for multiple frames','Tag','FillIn1');
    set(dritem,'MenuSelectedFcn',{@fillInClasses,obj,classif});
    
       dritem2 = uimenu(dr,'Text','Fill-in unclassified frames with class from last classified frame','Tag','FillIn2');
    set(dritem2,'MenuSelectedFcn',{@fillInClassesTheo,obj,classif});

            end
      end
      
    %   dritem(5) = uimenu(dr,'Text','Draw cell number for tracked cells','Checked','off','Tag','DrawCellNumber');
    %   set(dritem(5),'MenuSelectedFcn',{@checkCells,obj,h,classif});
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
    
    if obj.display.selectedchannel(i)==1
        % if obj.display.selectedchannel(pix)==1
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
                %   pix=obj.findChannelID(classif.strid);
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
        
        % size(im)
        
        aa=h.Position;
        
        if dis==0
            him.image(cc)=imshow(im(cc).data);
        else
            
            him.image(cc)=imshow(im(cc).data,cmap);
            % 'ok'
            %    return;
        end
        
        h.Position=aa; % forcing positioning (in case cd==1)
        
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
        
        %   ax=gca;
        
        %    set(zoom(ax),'ActionPreCallback',@(x,y) myCallbackFcn(ax,h));
        
        cc=cc+1;
        
        
    end
end


%     function myCallbackFcn(ax,h)
%
%
%         % here must disable paintingif zoom is in
%           for j=1:numel(classif.classes)
%                 ha=findobj('Tag',['classes_' num2str(j)]);
%                 if numel(ha)
%                         ha.Checked='off';
%                 end
%
%
%           end
%
%     h.WindowButtonDownFcn='';
%     h.Pointer = 'arrow';
%     h.WindowButtonMotionFcn = '';
%     h.WindowButtonUpFcn = '';
%    % figure(h); % set focus
%
%
%     end

if cd>0
    linkaxes(hp);
end


if numel(handles)==0
      if numel(classif)>0

          
           if strcmp(classif.category{1},'Image')  || strcmp(classif.category{1},'LSTM') % display user training and results
               
      dritem2 = uimenu(dr,'Text','Correction Mode GT vs Pred','Checked','off','Tag','Correction1');
    set(dritem2,'MenuSelectedFcn',{@correctionMode,obj, him, hp, classif,1});

    dritem2 = uimenu(dr,'Text','Correction Mode Class group','Checked','off','Tag','Correction2');
    set(dritem2,'MenuSelectedFcn',{@correctionMode,obj,him,hp,classif,2});

            end
      end

end


%========POSITION IMAGE=========
%set(h,'Units', 'Normalized','Position',[0 0 1 1]);


h.UserData.him=him;
h.UserData.correctionMode='off';

% reset mouse interaction function
h.WindowButtonDownFcn='';
h.Pointer = 'arrow';
h.WindowButtonMotionFcn = '';
h.WindowButtonUpFcn = '';


% add buttons and fcn to chanfe frame
keys={'a' 'z' 'e' 'r' 't' 'y' 'u' 'i' 'o' 'p'};
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
        cc= obj.channelid(cc);
        
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
    
    
    if strcmp(classif.category{1},'Pixel') | strcmp(classif.category{1},'Object') | strcmp(classif.category{1},'Image')  | strcmp(classif.category{1},'LSTM')
        % plotting classes menu for classification
        
        
        handles=findobj('Tag','TrainingClassesMenu');
        
        if numel(handles)~=0
            delete(handles)
        end
        
        m = uimenu(h,'Text',[classif.category{1} 'Training Classes'],'Tag','TrainingClassesMenu');
        mitem=[];
        
        for i=1:numel(classif.classes)
            %  cmap
            %aa=keys{i}
            %bb=cmap(i+1,:)
            
            
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
            h.KeyPressFcn={@changeframe,obj,him,hp,keys,classif,hpaint.Children(1),hcopy.Children(1),hpaint};
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
    
    if strcmp(classif.category{1},'LSTM Regression') || strcmp(classif.category{1},'Image Regression') % Regression training analysis
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

htextclassi=findobj(gcf,'Tag','classitext');

if numel(htextclassi)>0
    if ishandle(htextclassi)
        delete(htextclassi);
    end
end

cctext=1;

%test

for i=1:numel(obj.display.channel)
    pix=find(obj.channelid==i); % find matrix index associated with channel
    pix=pix(1); % there may be several items in case of a   multi-array channel
    
    if obj.display.selectedchannel(i)==1
        %   if obj.display.selectedchannel(pix)==1
        
        %hp=findobj('UserData',obj.display.channel{i});
        axes(hp(cc));
        str=obj.display.channel{i};
        strbound='';
         discc=1;
          displaystruct=[];
        displaystruct.name=[];
        displaystruct.gt='';
        displaystruct.pred='';
        displaystruct.info='';
         
         if numel(obj.train)>0
            fields=fieldnames(obj.train);
            
            for k=1:numel(fields)
                
                tt=obj.train.(fields{k}).id(obj.display.frame);
                
                if isfield(obj.train.(fields{k}),'classes')
                    classesspe=obj.train.(fields{k}).classes; % classes name specfic to training
                else
                    classesspe=    obj.classes ;
                end
                
                      if tt<=0
                            if  numel(obj.classes)>0
                                tt='Not Clas.';
                            else
                                % regression
                            end
                        else
                            
                            if numel(obj.classes)>0
                                if tt <= length(obj.classes)
                                    tt=obj.classes{tt};
                                else
                                    tt='N/A';
                                end
                            else
                                
                                %
                                tt=num2str(tt);
                            end
                            
                        end
                
                %     tt
                displaystruct(discc).name=fields{k};
                displaystruct(discc).gt=['GT: ' tt];
                
               
              %  str=[str ' -  ' tt ' (tr.: ' fields{k} ')'];
                
                   if numel(classif)>0 & strcmp(classif.strid,fields{k})
                             if strcmp(classif.category{1},'Image')  || strcmp(classif.category{1},'LSTM') 

                                  pixx=numel(find(obj.train.(classif.strid).id==0));
                                  
                                  if pixx>0
                                 strclassi= [num2str(pixx) ' frames remain to be classified'];
                                 displaystruct(discc).info=strclassi; 
                                  end
                             end

                                if isfield(obj.train.(classif.strid),'bounds')
                                   strbound=num2str(obj.train.(classif.strid).bounds);
                                end

                   end
                   discc=discc+1;
                        
                
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
                    if numel(obj.results.(pl{k}).id)>= obj.display.frame
                       % tt=num2str(obj.results.(pl{k}).id(obj.display.frame));
                       % str=[str ' - class #' tt ' (' pl{k} ')'];
                        
                             tt=obj.results.(pl{k}).id(obj.display.frame);
                        
                        if isfield(obj.results.(pl{k}),'classes')
                            classesspe=obj.results.(pl{k}).classes; % classes name specfic to training
                        else
                            classesspe=    obj.classes ;
                        end
                        
                        if tt<=0
                            if  length(obj.classes)>0
                                tt='Not Clas.';
                            else
                                % regression
                            end
                        else
                            
                            if length(obj.classes)>0
                                if tt <= length(obj.classes)
                                    tt=obj.classes{tt};
                                else
                                    tt='N/A';
                                end
                            else
                                
                                %
                                tt=num2str(tt);
                            end
                            
                        end
                        
                        %     tt
                      %  str=[str ' - ' tt ' ( ' fields{k} ')'];
                        
                      found=0;
                        for jk=1:numel(displaystruct)
                            if strcmp(displaystruct(jk).name,pl{k})
                                displaystruct(jk).pred=['Pred: ' tt];
                                found=1;
                            end
                        end
                        if found==0
                            displaystruct(end+1).pred=tt;
                            displaystruct(end+1).name=pl{k};
                        end
                        
                    end
                end
                %
                %                 if isfield(obj.results.(pl{k}),'mother')
                %                     % pedigree data available .
                %
                %                     if strcmp(['results_' pl{k}],str) % identify channel
                %
                %                         plotLinksResults(obj,hp,pl{k})
                %                     end
                %                 end
                
                if isfield(obj.results.(pl{k}),'mother')
                    % pedigree data available .
                    %    str,pl{k}
                    %   if strcmp(['results_' pl{k}],str) % identify channel
                    if strcmp([pl{k}],str) % identify channel
                        %       'ok'
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
            
            im=him.image(cc).CData;m
            
            
            [l n]=bwlabel(im);
            r=regionprops(l,'Centroid');
            
            %'ok'
            
            xx=findobj('Tag','DrawCellNumber');
            
            if numel(xx)
                if strcmp(xx.Checked,'on')
                    
                    for k=1:n
                        bw=l==k;
                        id=round(mean(im(bw)));
                        htext(cctext)=text(r(k).Centroid(1),r(k).Centroid(2),num2str(id),'Color',[1 1 1],'FontSize',20,'Tag','tracktext');
                        cctext=cctext+1; % update handle counter
                    end
                end
            end
        end
        
        subt={};
        
        for ii=1:numel(displaystruct)
            subt{ii}=[displaystruct(ii).name ' - '  displaystruct(ii).gt ' - ' displaystruct(ii).pred ' - '  displaystruct(ii).info ];

                        if numel(classif)>0
            if strcmp(displaystruct(ii).name,classif.strid)
                 xx=size(obj.image,2)/2;
                 yy=size(obj.image,1)/2;
                  htextclassi=text(xx,yy,[displaystruct(ii).gt ' - ' displaystruct(ii).pred],'Color',[1 0 0],'FontSize',20,'Tag','classitext','HorizontalAlignment','center');
            end
                        end

        end
        
            if numel(strbound)
               subt(end+1)={['Frames bounds: ' strbound]} ;
            end

        title(hp(cc),[str subt],'FontSize',12,'interpreter','none');
        
        %test=get(hp(cc),'Parent')
     %   title(hp(cc),str,'FontSize',14,'interpreter','none');
        %title(hp(cc),str, 'Color',colo,'FontSize',20);
        cc=cc+1;
    end
end
end

%  function checkCells(handles, event,obj,h,classif)
%  if strcmp(handles.Checked,'on')
%  set(handles,'Checked','off')
%  else
%  set(handles,'Checked','on')
%  end
%
%clf
%h.UserData=[];
%[him hp]=draw(obj,h,classif);

%obj.view;
% end

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

disp(['update stretchlim: ' num2str(obj.id) ', computing them...']);
obj.computeStretchlim;

obj.view;
end

function removeChannel(handles, event,obj)

h=findobj('Tag',['ROI' obj.id]);
h.UserData.selection=[];


fig = uifigure('Position',[100 100 300 150],'UserData',h,'Name','Select channel:');
dd = uidropdown(fig,'Items', obj.display.channel,...
    'Position',[10, 120, 200, 32],...
    'Value', obj.display.channel{1},...
    'ValueChangedFcn',@(dd,event) selection(dd,fig));

btn = uibutton(fig,'push',...
    'Position',[10, 10, 100, 22],'Text','Proceed',...
    'ButtonPushedFcn', @(btn,event) plotButtonPushed(btn,fig));

% Create the function for the ButtonPushedFcn callback
    function plotButtonPushed(btn,fig)
        close(fig)
    end

    function selection(dd,fig)
        val = dd.Value;
        fig.UserData.UserData.selection = val;
    end

uiwait(fig);

sele=h.UserData.selection;

if numel(sele)
    close(h);
    
    obj.removeChannel(sele);
    obj.view;
end

end

function copyFrames(handles, event,obj)

h=findobj('Tag',['ROI' obj.id]);
h.UserData.copyframes={obj.display.channel{1} obj.display.channel{1} num2str(obj.display.frame) num2str(obj.display.frame) };

fig = uifigure('Position',[100 100 350 150],'UserData',h,'Name','Copy frames:');

lab=uilabel(fig,'Position',[10, 120, 100, 22],'Text','From channel::');
lab=uilabel(fig,'Position',[180, 120, 100, 22],'Text','To channel::');


dd1 = uidropdown(fig,'Items', obj.display.channel,...
    'Position',[10, 100, 150, 22],...
    'Value', obj.display.channel{1},...
    'ValueChangedFcn',@(dd,event) selection(dd,fig,1));

dd2 = uidropdown(fig,'Items', obj.display.channel,...
    'Position',[180, 100, 150, 22],...
    'Value', obj.display.channel{1},...
    'ValueChangedFcn',@(dd2,event) selection(dd2,fig,2));

lab=uilabel(fig,'Position',[10, 80, 120, 22],'Text','Source frames:');

txt = uieditfield(fig,...
    'Value', num2str(obj.display.frame), 'Position',[40 60 100 22],...
    'ValueChangedFcn',@(txt,event) selection(txt,fig,3));


lab=uilabel(fig,'Position',[140, 80, 120, 22],'Text','Destination frames:');

txt2 = uieditfield(fig,...
    'Value', num2str(obj.display.frame), 'Position',[190 60 100 22],...
    'ValueChangedFcn',@(txt,event) selection(txt,fig,4));

% Code the callback function

btn = uibutton(fig,'push',...
    'Position',[10, 10, 100, 22],'Text','Proceed',...
    'ButtonPushedFcn', @(btn,event) plotButtonPushed(btn,fig));


% Create the function for the ButtonPushedFcn callback
    function plotButtonPushed(btn,fig)
        fig.UserData.UserData.copyframes{5}='ok';
        close(fig)
    end

% drop down selection function
    function selection(dd,fig,id)
        val = dd.Value;
        fig.UserData.UserData.copyframes{id} = val;
    end

uiwait(fig);

sele=h.UserData.copyframes;

if numel(sele)==5
    
    pix1=obj.findChannelID(sele{1});
    pix2=obj.findChannelID(sele{2});
    fr1=str2num(sele{3});
    fr2=str2num(sele{4});
    
    obj.image(:,:,pix2,fr2)=obj.image(:,:,pix1,fr1);
    
    close(h);
    %
    %     obj.removeChannel(sele);
    obj.view;
end

end

function fillInClasses(handles, event,obj, classif)

if numel(obj.classes)==0
    disp('there are no classes in this roi !');
    return;
end

h=findobj('Tag',['ROI' obj.id]);

id=obj.train.(classif.strid).id;

idframe=id(obj.display.frame);

if idframe==0
    idframe=1;
end

h.UserData.classframes={obj.classes{idframe}   num2str(obj.display.frame) num2str(size(obj.image,4)) };


fig = uifigure('Position',[100 100 350 150],'UserData',h,'Name','Fill in classes in frames:');

lab=uilabel(fig,'Position',[10, 120, 100, 22],'Text','Class: :');

dd1 = uidropdown(fig,'Items', obj.classes,...
    'Position',[10, 100, 150, 22],...
    'Value', obj.classes{idframe},...
    'ValueChangedFcn',@(dd,event) classselection(dd,fig,1));

lab=uilabel(fig,'Position',[10, 80, 120, 22],'Text','Start frame:');

txt = uieditfield(fig,...
    'Value', num2str(obj.display.frame), 'Position',[40 60 100 22],...
    'ValueChangedFcn',@(txt,event) classselection(txt,fig,2));


lab=uilabel(fig,'Position',[140, 80, 120, 22],'Text','End frame:');

txt2 = uieditfield(fig,...
    'Value', num2str(size(obj.image,4)), 'Position',[190 60 100 22],...
    'ValueChangedFcn',@(txt,event) classselection(txt,fig,3));

% Code the callback function

btn = uibutton(fig,'push',...
    'Position',[10, 10, 100, 22],'Text','Proceed',...
    'ButtonPushedFcn', @(btn,event) classButtonPushed(btn,fig));


% Create the function for the ButtonPushedFcn callback
    function classButtonPushed(btn,fig)
        fig.UserData.UserData.classframes{4}='ok';
        close(fig)
    end

% drop down selection function
    function classselection(dd,fig,id)
        val = dd.Value;
        fig.UserData.UserData.classframes{id} = val;
    end

uiwait(fig);

sele=h.UserData.classframes;

if numel(sele)==4
    
    pix1=find(matches(obj.classes,sele{1}));
    fr1=str2num(sele{2});
    fr2=str2num(sele{3});
    
    obj.train.(classif.strid).id(fr1:fr2)=pix1;
    
    close(h);
    
    %
    %    obj.removeChannel(sele);
     %   obj.view;
 
    obj.view(obj.display.frame,classif);
end

end

function fillInClassesTheo(handles, event,obj, classif)


if numel(obj.classes)==0
    disp('there are no classes in this roi !');
    return;
end

h=findobj('Tag',['ROI' obj.id]);

obj.fillTraining('Training',classif.strid); 
close(h);
obj.view(obj.display.frame,classif);

end

function correctionMode(handles, event,obj, him,hp,classif,mode)

h=findobj('Tag',['ROI' obj.id]);

  ha=findobj('Tag',['Correction' num2str(mode)]); 
    
    if numel(ha)
        if strcmp(ha.Checked,'on')
             set(ha,'Checked','off');
              h.UserData.correctionMode='off';
        else
           set(ha,'Checked','on');
            h.UserData.correctionMode=num2str(mode);
           ha=findobj('Tag',['Correction' num2str(2-mode+1)]);
           set(ha,'Checked','off');
        end
    end

    updatedisplay(obj,him,hp,classif)
    % HERE : 
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
    
    tz=zoom(h);
    tp=pan(h);
    
    if strcmp(tz.Enable,'on')  || strcmp(tp.Enable,'on')
        %  disp('not available,  set zoom and pan will be set off');
        tz.Enable='off';
        tp.Enable='off';
        % return;
    end
    
    handles.Checked='on';
    
    
    % set pixel painting mode
    if strcmp(classif.category{1},'Pixel')
        set(h,'WindowButtonDownFcn',{@wbdcb,obj,impaint1,impaint2,hpaint,classif,h});
    end
    
    if strcmp(classif.category{1},'Object')
        set(h,'WindowButtonDownFcn',{@wbdcb2,impaint1,impaint2,h});
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


% nested function, good luck ;-) ....

end


function wbdcb(src,event,obj,impaint1,impaint2,hpaint,classif,h)
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
                % xdat = [cp(1,1) ];
                %ydat = [cp(1,2) ];
                
                mix=max(1,cp(1,2));
                miy=max(1,cp(1,1));
                mux=min(size(ma,1),cp(1,2));
                muy=min(size(ma,1),cp(1,1));
                
            case 1 % large brush
                %xdat = [cp(1,1) cp(1,1)+1 cp(1,1)-1 cp(1,1)+1 cp(1,1)-1 cp(1,1) cp(1,1) cp(1,1)+1 cp(1,1)-1];
                %ydat = [cp(1,2) cp(1,2)+1 cp(1,2)-1 cp(1,2)-1 cp(1,2)+1 cp(1,2)+1 cp(1,2)-1 cp(1,2) cp(1,2)];
                
                mix=max(1,cp(1,2)-3);
                miy=max(1,cp(1,1)-3);
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

function wbdcb2(src,obj,impaint1,impaint2,h)
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
        
        obj.train.(classif.strid).id(obj.display.frame)=floor(dist);
        
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
    
    obj.display.selectedchannel(i)=1;
    % aa=obj.display.selectedchannel(i)
else
    
    handles.Checked='off';
    str=handles.Tag;
    i = str2num(replace(str,'channel_',''));
    
    pix=find(obj.channelid==i); % find matrix index associated with channel
    pix=pix(1); % there may be several items in case of a   multi-array channel
    
    obj.display.selectedchannel(i)=0;
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
h=findobj('Tag',['ROI' obj.id]);
im=buildimage(obj);

% need to update the painting window here hpaint.Children(1).CData...

cc=1;
for i=1:numel(obj.display.channel)
    pix=find(obj.channelid==i); % find matrix index associated with channel
    pix=pix(1); % there may be several items in case of a   multi-array channel
    
    if obj.display.selectedchannel(i)==1
        %   if obj.display.selectedchannel(pix)==1
        
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

htextclassi=findobj(gcf,'Tag','classitext');

if numel(htextclassi)>0
    if ishandle(htextclassi)
        delete(htextclassi);
    end
end

cc=1;
cctext=1;
for i=1:numel(obj.display.channel)
    pix=find(obj.channelid==i); % find matrix index associated with channel
    pix=pix(1); % there may be several items in case of a   multi-array channel
    if obj.display.selectedchannel(i)==1
        % if obj.display.selectedchannel(pix)==1
        axes(hp(cc));
        str=obj.display.channel{i};
        strclassi='';
        strbound='';
        displaystruct=[];
        displaystruct.name=[];
        displaystruct.gt='';
        displaystruct.pred='';
        displaystruct.info='';
        
        discc=1;
        
        if numel(obj.train)>0
            fields=fieldnames(obj.train);
            
            for k=1:numel(fields)
                
                tt=obj.train.(fields{k}).id(obj.display.frame);
                
                if isfield(obj.train.(fields{k}),'classes')
                    classesspe=obj.train.(fields{k}).classes; % classes name specfic to training
                else
                    classesspe=    obj.classes ;
                end
                
                      if tt<=0
                            if  numel(obj.classes)>0
                                tt='Not Clas.';
                            else
                                % regression
                            end
                        else
                            
                            if numel(obj.classes)>0
                                if tt <= length(obj.classes)
                                    tt=obj.classes{tt};
                                else
                                    tt='N/A';
                                end
                            else
                                
                                %
                                tt=num2str(tt);
                            end
                            
                        end
                
                %     tt
                displaystruct(discc).name=fields{k};
                displaystruct(discc).gt=['GT: ' tt];
                
               
              %  str=[str ' -  ' tt ' (tr.: ' fields{k} ')'];
                
                   if numel(classif)>0 & strcmp(classif.strid,fields{k})
                             if strcmp(classif.category{1},'Image')  || strcmp(classif.category{1},'LSTM') 

                                  pixx=numel(find(obj.train.(classif.strid).id==0));
                                  
                                  if pixx>0
                                 strclassi= [num2str(pixx) ' frames remain to be classified'];
                                 displaystruct(discc).info=strclassi; 
                                  end

                                 
                             end

                                  if isfield(obj.train.(classif.strid),'bounds')
                                   strbound=num2str(obj.train.(classif.strid).bounds);
                                  end


                   end
                   discc=discc+1;
                        
                
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
                    if numel(obj.results.(pl{k}).id)>= obj.display.frame
                       % tt=num2str(obj.results.(pl{k}).id(obj.display.frame));
                       % str=[str ' - class #' tt ' (' pl{k} ')'];
                        
                             tt=obj.results.(pl{k}).id(obj.display.frame);
                        
                        if isfield(obj.results.(pl{k}),'classes')
                            classesspe=obj.results.(pl{k}).classes; % classes name specfic to training
                        else
                            classesspe=    obj.classes ;
                        end
                        
                        if tt<=0
                            if  length(obj.classes)>0
                                tt='Not Clas.';
                            else
                                % regression
                            end
                        else
                            
                            if length(obj.classes)>0
                                if tt <= length(obj.classes)
                                    tt=obj.classes{tt};
                                else
                                    tt='N/A';
                                end
                            else
                                
                                %
                                tt=num2str(tt);
                            end
                            
                        end
                        
                        %     tt
                      %  str=[str ' - ' tt ' ( ' fields{k} ')'];
                        
                      found=0;
                        for jk=1:numel(displaystruct)
                            if strcmp(displaystruct(jk).name,pl{k})
                                displaystruct(jk).pred=['Pred: ' tt];
                                found=1;
                            end
                        end
                        if found==0
                            displaystruct(end+1).pred=tt;
                            displaystruct(end+1).name=pl{k};
                        end
                        
                    end
                end
                %
                %                 if isfield(obj.results.(pl{k}),'mother')
                %                     % pedigree data available .
                %
                %                     if strcmp(['results_' pl{k}],str) % identify channel
                %
                %                         plotLinksResults(obj,hp,pl{k})
                %                     end
                %                 end
                
                if isfield(obj.results.(pl{k}),'mother')
                    % pedigree data available .
                    %    str,pl{k}
                    %   if strcmp(['results_' pl{k}],str) % identify channel
                    if strcmp([pl{k}],str) % identify channel
                        %       'ok'
                        plotLinksResults(obj,hp,pl{k})
                    end
                end
                
            end
        end

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
 
        
        subt={};
        
        for ii=1:numel(displaystruct)
            subt{ii}=[displaystruct(ii).name ' - '  displaystruct(ii).gt ' - ' displaystruct(ii).pred ' - '  displaystruct(ii).info ];


            if numel(classif)>0
            if strcmp(displaystruct(ii).name,classif.strid)
                 xx=size(obj.image,2)/2;
                 yy=size(obj.image,1)/2;
                  htextclassi=text(xx,yy,[displaystruct(ii).gt ' - ' displaystruct(ii).pred],'Color',[1 0 0],'FontSize',20,'Tag','classitext','HorizontalAlignment','center');
            end
            end
        end

        if numel(strbound)
               subt(end+1)={['Frames bounds: ' strbound]} ;
        end

        str=[str subt];

        if ~strcmp(h.UserData.correctionMode,'off')
            tt=h.UserData.correctionMode;
str=[{['[CORRECTION MODE ' tt ']']}, str];
        end

        title(hp(cc),str,'FontSize',12,'interpreter','none');
      %  subtitle(hp(cc), subt ,'FontSize',10,'interpreter','none');

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

%hpt=findobj(hp,'UserData',['results_' strid]);
hpt=findobj(hp,'UserData',[strid]);
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
    
    if obj.display.selectedchannel(i)==1
        %    if obj.display.selectedchannel(pix)==1
        % get the righ data: there may be several matrices for one single
        % channel in case of RGB images
        
        pix=find(obj.channelid==i);
        src=obj.image;
        
        % for each channel perform normalization
        %pix
        %INTENSITY
        
        tmp=src(:,:,pix,:);
        
        %  imout=uint16(zeros(size(obj.image,1),size(obj.image,2),3));
        
        imtemp=obj.image(:,:,pix,frame);
        
        
        % WARNING PIX MAY BE A 1 or  3 element vector
        if (~isfield(obj.display,'stretchlim') && ~isprop(obj.display,'stretchlim')) || size(obj.display.stretchlim,2)~=numel(obj.channelid)
            disp(['No stretch limits found for ROI ' num2str(obj.id) ', computing them...']);
            obj.computeStretchlim;
        end
        
        strchlm=obj.display.stretchlim(:,(pix(end)-pix(1))/2 + pix(1)); %middle stack
        %strchlm=stretchlim(imtemp(:,:,(end-1)/2 + 1),[0.005 0.995]);
        %strchlm=stretchlim(imtemp(:,:,ceil((end+1)/2))); % computes the strecthlim for the middle stack. To be changed once we add multichannels as inputs.
        
        it=mean(obj.display.intensity(i,:)); % indexed images has intensity levels to 0
        
        if it~=0 || numel(pix)==3
            
            imtemp=imadjust(imtemp,strchlm);
            
        end
        imout=imtemp;
        %   if numel(pix)==1
        %     imtemp =repmat(imtemp,[1 1 3]);
        %  end
        
        if numel(pix)==3
            for j=1:size(imtemp,3)
                %   i,j,pix(j)
                %  tmp=src(:,:,pix(j),:);
                %  meangfp=0.5*double(mean(tmp(:)));
                % it=obj.display.intensity(i,j);
                %                         maxgfp=double(meangfp+it*(max(tmp(:))-meangfp));
                %                         if maxgfp==0
                %                             maxgfp=1;
                %                         end
                
                %size(imtemp)
                
                % if meangfp>0 && maxgfp>0
                %    imtemp = imadjust(imtemp,[meangfp/65535 maxgfp/65535],[0 1]);
                %end
                
                imout(:,:,j)=imtemp(:,:,j).*obj.display.rgb(i,j);
            end
        end
        
        %         end
        im(cc).data=imout;
        cc=cc+1;
    end
end
%   cc=cc+1;
end

function setframe(handle,event,obj,him,hp,classif )
frame=str2num(handle.String);
if frame<=size(obj.image,4) & frame > 0
    obj.display.frame=frame;
    updatedisplay(obj,him,hp,classif)
end
end

function changeframe(handle,event,obj,him,hp,keys,classif,impaint1,impaint2,hpaint)

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

if nargin==10 % only if painting is allowed
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

if nargin==10 % only if painting is allowed
    if strcmp(event.Key,'uparrow') %
        
        warning off all
        ax=findobj('Tag',classif.strid);
        al=ax.Children.AlphaData;
        ax.Children.AlphaData=min(al+0.1,1);
        %       aa=ax.Children.AlphaData
        
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
        ax.Children.AlphaData=max(al-0.1,0);
        warning on all
        % obj.display.intensity(obj.display.selectedchannel)=min(1,obj.display.intensity(obj.display.selectedchannel)+0.01);
        ok=1;
    end
end

if numel(classif)>0
  if  strcmp(classif.category{1},'Image') || strcmp(classif.category{1},'LSTM')% if image classification, assign class to keypress even
      if ~isfield(obj.train.(classif.strid),'bounds')
            obj.train.(classif.strid).bounds=[0 0];
      else
            if strcmp(event.Key,'w')
            obj.train.(classif.strid).bounds(1)=obj.display.frame;
            end
            if strcmp(event.Key,'x')
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
                                 
                                   [aa2,pix]=sort(obj.train.(classif.strid).id);
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

                                   pix1=find( aa1-aa2~=0,1,'last');
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
                                 
                                   [aa2 pix]=sort(obj.train.(classif.strid).id);
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
                            set(h,'WindowButtonDownFcn',{@wbdcb,obj,impaint1,impaint2,hpaint,classif,h});
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
if ok==1
    updatedisplay(obj,him,hp,classif)
end
end
