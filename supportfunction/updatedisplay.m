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

strplus='';

if numel(classif)>0
    cmap=classif.colormap;
    if strcmp(classif.category{1},'Pixel') | strcmp(classif.category{1},'Object') | strcmp(classif.category{1},'Delta')
        htmp=findobj('Tag',classif.strid);

        if numel(htmp)>1
            disp('One painting window is probably already open : please close ! ');
            return;
        end

        hpt=findobj(hp,'UserData',classif.strid);

        if numel(htmp)>1
            disp('One painting window is probably already open : please close ! ');
            return;
        end


        if numel(htmp) && numel(hpt)
            hc=findobj(hpt,'Type','Image');
            hm=findobj(htmp,'Type','Image');
            hm.CData=hc.CData; % updates data on the painting window

            %   htmp
            if  strcmp(classif.category{1},'Delta')
                colo=[1 1 1];
                hcc=findobj(h,'Tag','celltext');
                val=hcc.String;
                if  numel(str2num(val))
                    displaySelectedContour(h,htmp,hm,str2num(val),colo);
                end
            end

        end
    end


    if strcmp(classif.category{1},'Pedigree')
        plotLinks(obj,hp,classif);
    end

    if numel(obj.data)
        listdata={obj.data.groupid};

        pixdata=find(matches(listdata,classif.strid));

        if numel(pixdata)
            dd=obj.data(pixdata);
            ddts=dd.getData('labels_training');

            if numel(ddts)
                strplus=[ddts(obj.display.frame)];
            end

        end
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
htextclassipred=findobj(gcf,'Tag','classitextpred');

if numel(htextclassi)>0
    if ishandle(htextclassi)
        ha=findobj('Tag','classitextflag');
        if numel(ha)
            if strcmp(ha.Checked,'off')
                delete(htextclassi);
                delete(htextclassipred);
            end
        end

    end
end

cc=1;
cctext=1;

for i=1:numel(obj.display.channel)
    pix=find(obj.channelid==i); % find matrix index associated with channel
    pix=pix(1); % there may be several items in case of a   multi-array channel

    if obj.display.selectedchannel(i)==1
        % if obj.display.selectedchannel(pix)==1
        %      axes(hp(cc));

        str=obj.display.channel{i};
        strclassi='';
        strbound='';
        displaystruct=[];
        displaystruct.name=[];
        displaystruct.gt='';
        displaystruct.pred='';
        displaystruct.info='';

        discc=1;


        % display object number on object if it is a track
        if numel(strfind(obj.display.channel{i},'track'))~=0 | numel(strfind(obj.display.channel{i},'pedigree'))~=0
            im=him.image(cc).CData;

            [l n]=bwlabel(im);
            r=regionprops(l,'Centroid');

            for k=1:n
                bw=l==k;
                id=round(mean(im(bw)));

                tmp=hp(cc);




                htext(cctext)=text(tmp,r(k).Centroid(1),r(k).Centroid(2),num2str(id),'Color',[0.8 0.8 0.8],'FontSize',10,'Tag','tracktext','UserData',obj.display.channel{i});
                set(htext(cctext), 'ButtonDownFcn', @(src, event) enableEditing(src, event));
                cctext=cctext+1;

            end

            % Define the callback function to enable editing
        end


        subt={};

        for ii=1:numel(displaystruct)
            subt{ii}=[displaystruct(ii).name ' - '  displaystruct(ii).gt ' - ' displaystruct(ii).pred ' - '  displaystruct(ii).info ];

            % display current classi on image

            if numel(classif)>0
                % if strcmp(displaystruct(ii).name,classif.strid)
                ha=findobj('Tag','classitextflag');

                if numel(ha)
                    if strcmp(ha.Checked,'on')
                        xx=size(obj.image,2)/2;
                        yy=1*size(obj.image,1)/2;
                        % idf=obj.train.(displaystruct(ii).name).id(obj.display.frame);

                        [dataout, labelout]=getTrainingData(obj,classif.strid);
                        idf=dataout(obj.display.frame);
                        txt=char(labelout(obj.display.frame));

                        if idf==0, idf=10; end

                        if exist('ttid'), idfpred=ttid; else idfpred=1; end
                        colmap=flip(prism,1);
                        if numel(htextclassi)==0 %|| numel(htextclassipred)==0
                            htextclassi=text(xx,yy,txt,'Color',colmap(1*idf,:),'FontSize',20,'FontWeight','Bold','Tag','classitext','HorizontalAlignment','right');
                            %htextclassipred=text(xx,yy,['   ' displaystruct(ii).pred],'Color',colmap(1*idfpred,:),'FontSize',20,'FontWeight','Bold','Tag','classitextpred','HorizontalAlignment','left');
                        else
                            htextclassi.String=txt;
                            htextclassi.Color=colmap(1*idf,:);
                            %htextclassipred.String=['   ' displaystruct(ii).pred];
                            %htextclassipred.Color=colmap(1*idfpred,:);
                        end
                    end
                end

                % end
            end
        end

        str=[str strplus];
        if ~strcmp(h.UserData.correctionMode,'off')
            tt=h.UserData.correctionMode;
            str=[{['[CORRECTION MODE ' tt ' - j/kkeys]']}, str];
        end




        title(hp(cc),str,'FontSize',12,'interpreter','none');
        % subtitle(hp(cc), subt ,'FontSize',10,'interpreter','none');

        %title(hp(cc),str, 'Color',colo,'FontSize',20);
        cc=cc+1;
    end
end



htext=findobj(h,'Tag','frametext');
if numel(htext)
    htext.String=num2str(obj.display.frame);
end


% if classif result and training is displayed, then update the position of the cursor
htraj=findobj('Type','Figure');

for i=1:numel(htraj)
    z= htraj(i).Name;

    if contains(z,obj.id)

        li=findobj(htraj(i),'Tag',[obj.id '_track']);

        if numel(li)==0
            continue
        end

        for j=1:numel(li)
            li(j).XData=[obj.display.frame obj.display.frame];
        end

        txt=[];
        hpo=findobj(htraj(i),'Tag','Axes_track');

        hpp=findobj(htraj(i),'Tag','labels_training');

        if numel(hpp)

            datastruct=hpp.UserData;
            datatot=datastruct.getData('id_training');
            pixdat=numel(find(datatot==0));

            datalabels=datastruct.getData('labels_training');

            dat=hpp.YData;
            pix=obj.display.frame;

            if iscategorical(dat(pix))
                txt=char(dat(pix));
            end
            if isnumeric(dat(pix))
                txt=num2str(dat(pix));
            end

            txt=[txt ' - ' num2str(pixdat) ' frames left to annotate'];
            title(hpo,txt);

            hpp.YData= datalabels;
            % update data plot
            %
            %     hh=findobj('Tag',obj.data(pixdata).id);
            %      if numel(hh)
            %          pos=hh.Position;
            %        pos(2)=pos(2)+0.05;
            %         delete(hh);
            %          obj.data(pixdata).plot(pos,'ok');
            %          figure(h);
            %      end


        end
    end
end

%h = findobj('-regexp','Tag',expr)
% if numel(htraj)~=0
%     hl=findobj(htraj,'Tag','track');
%     if numel(hl)>0
%         hl.XData=[obj.display.frame obj.display.frame];
%     end
% end

    function enableEditing(src, ~)
        % Enable editing mode
        oldLabel = str2double(src.String);

        src.Editing = 'on';

        % Set a callback for when editing is done
        addlistener(src, 'Editing', 'PostSet', @(~, event) disableEditing(src, event,oldLabel));
    end

% Define the callback function to disable editing after editing is done
    function disableEditing(htext, event,oldLabel)
        % Check if the editing is turned off
        if strcmp(event.AffectedObject.Editing, 'off')
            % Obtenir la nouvelle valeur du texte
            newLabelStr = event.AffectedObject.String;
            newLabel = str2double(newLabelStr);

            % Vérifier si le nouveau label est un nombre valide
            if ~isnan(newLabel)
                % Obtenir la position de l'objet texte
                pos = get(event.AffectedObject, 'Position');
                x = pos(1);
                y = pos(2);

                % Trouver les coordonnées correspondantes dans l'image labellisée
                row = round(y);
                col = round(x);

                L=l;
                % Mettre à jour l'image labellisée si les coordonnées sont dans les limites
                if row > 0 && row <= size(L, 1) && col > 0 && col <= size(L, 2)
                 %   oldLabel = uint16(str2double(event.AffectedObject.String));
                   % L(L == oldLabel) = newLabel; % Mettre à jour toutes les instances de l'ancien label
                   frame=obj.display.frame;
                   tmp=htext.UserData;
                   pix=obj.findChannelID(tmp);
                   img=obj.image(:,:,pix,frame:end);
         
                   p=img==oldLabel;
                   img(p)=newLabel;
                    obj.image(:,:,pix,frame:end)=img;
                    %figure, imshow(obj.image(:,:,pix,frame),[]);
                    updatedisplay(obj,him,hp,classif);
                end
            end
        end
    end
end

