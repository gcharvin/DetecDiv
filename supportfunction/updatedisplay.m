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
    if strcmp(classif.category{1},'Pixel') | strcmp(classif.category{1},'Object') | strcmp(classif.category{1},'Delta')
        htmp=findobj('Tag',classif.strid);
        hpt=findobj(hp,'UserData',classif.strid);


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

%         if numel(obj.train)>0
%             fields=fieldnames(obj.train);
% 
%             for k=1:numel(fields)
% 
%                 if ~isfield(obj.train.(fields{k}),'id')
%                     continue
%                 end
% 
%                 if numel(obj.train.(fields{k}).id)>=obj.display.frame
%                     tt=obj.train.(fields{k}).id(obj.display.frame);
% 
%                     if isfield(obj.train.(fields{k}),'classes')
%                         classesspe=obj.train.(fields{k}).classes; % classes name specfic to training
%                     else
%                         classesspe=    obj.classes ;
%                     end
% 
%                     if tt<=0
%                         if  numel(classesspe)>0
%                             tt='Not Clas.';
%                         else
%                             % regression
%                         end
%                     else
% 
%                         if numel(classesspe)>0
%                             if tt <= length(classesspe)
%                                 tt=classesspe{tt};
%                             else
%                                 tt='N/A';
%                             end
%                         else
% 
%                             %
%                             tt=num2str(tt);
%                         end
% 
%                     end
% 
%                     %     tt
%                     displaystruct(discc).name=fields{k};
%                     displaystruct(discc).gt=['GT: ' tt];
% 
% 
%                     if numel(classif)>0 & strcmp(classif.strid,fields{k})
%                         if strcmp(classif.category{1},'Image')  || strcmp(classif.category{1},'LSTM')
% 
%                             pixx=numel(find(obj.train.(classif.strid).id==0));
% 
%                             if pixx>0
%                                 strclassi= [num2str(pixx) ' frames remain to be classified'];
%                                 displaystruct(discc).info=strclassi;
%                             end
%                         end
% 
%                         if isfield(obj.train.(classif.strid),'bounds')
%                             strbound=num2str(obj.train.(classif.strid).bounds);
%                         end
% 
%                         if isfield(obj.train.(classif.strid),'bounds')
%                             strbound=num2str(obj.train.(classif.strid).bounds);
%                         end
% 
% 
%                     end
%                     discc=discc+1;
%                 end
%             end
% 
%         end
      %  discc=discc+1;

%         if numel(obj.results)>0
%             pl = fieldnames(obj.results);
% 
%             %aa=obj.results
%             for k = 1:length(pl)
%                 if isfield(obj.results.(pl{k}),'labels')
%                     %   tt=char(obj.results.(pl{k}).labels(obj.display.frame));
%                     if numel(obj.results.(pl{k}).id)>= obj.display.frame
%                         % tt=num2str(obj.results.(pl{k}).id(obj.display.frame));
%                         % str=[str ' - class #' tt ' (' pl{k} ')'];
% 
%                         tt=obj.results.(pl{k}).id(obj.display.frame);
%                         ttid=obj.results.(pl{k}).id(obj.display.frame);
% 
%                         if isfield(obj.results.(pl{k}),'classes')
%                             classesspe=obj.results.(pl{k}).classes; % classes name specfic to training
%                         else
%                             classesspe=    obj.classes ;
%                         end
% 
% 
%                         if tt<=0
%                             if  length(classesspe)>0
%                                 tt='Not Clas.';
%                             else
%                                 % regression
%                             end
%                         else
% 
%                             if length(classesspe)>0
%                                 if tt <= length( classesspe)
%                                     tt= classesspe{tt};
%                                 else
%                                     tt='N/A';
%                                 end
%                             else
% 
%                                 %
%                                 tt=num2str(tt);
%                             end
% 
%                         end
% 
%                         %     tt
%                         %  str=[str ' - ' tt ' ( ' fields{k} ')'];
% 
%                         found=0;
%                         for jk=1:numel(displaystruct)
%                             if strcmp(displaystruct(jk).name,pl{k})
%                                 displaystruct(jk).pred=['Pred: ' tt];
%                                 found=1;
%                             end
%                         end
%                         if found==0
%                             chk=0;
%                             if numel(displaystruct)==1
%                                 if numel(displaystruct(1).name)==0
%                                     chk=1;
%                                 end
%                             end
%                             if chk==0
%                                 displaystruct(end+1).pred=['Pred: ' tt];
%                                 displaystruct(end+1).name=pl{k};
%                             else
%                                 displaystruct(1).pred=['Pred: ' tt];
%                                 displaystruct(1).name=pl{k};
%                             end
%                         end
% 
%                     end
%                 end
%                 %
%                 %                 if isfield(obj.results.(pl{k}),'mother')
%                 %                     % pedigree data available .
%                 %
%                 %                     if strcmp(['results_' pl{k}],str) % identify channel
%                 %
%                 %                         plotLinksResults(obj,hp,pl{k})
%                 %                     end
%                 %                 end
% 
%                 if isfield(obj.results.(pl{k}),'mother')
%                     % pedigree data available .
%                     %    str,pl{k}
%                     %   if strcmp(['results_' pl{k}],str) % identify channel
%                     if strcmp([pl{k}],str) % identify channel
%                         %       'ok'
%                         plotLinksResults(obj,hp,pl{k})
%                     end
%                 end
% 
%             end
%         end



        if numel(strfind(obj.display.channel{i},'track'))~=0 | numel(strfind(obj.display.channel{i},'pedigree'))~=0
            im=him.image(cc).CData;

            [l n]=bwlabel(im);
            r=regionprops(l,'Centroid');

            for k=1:n
                bw=l==k;
                id=round(mean(im(bw)));

                tmp=hp(cc);

                htext(cctext)=text(tmp,r(k).Centroid(1),r(k).Centroid(2),num2str(id),'Color',[1 1 1],'FontSize',10,'Tag','tracktext');
                cctext=cctext+1;
            end
        end


        subt={};

        for ii=1:numel(displaystruct)
            subt{ii}=[displaystruct(ii).name ' - '  displaystruct(ii).gt ' - ' displaystruct(ii).pred ' - '  displaystruct(ii).info ];


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

        if numel(strbound)
            subt(end+1)={['Frames bounds: ' strbound]} ;
        end

        str=[str subt];

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



htext=findobj(gcf,'Tag','frametext');
htext.String=num2str(obj.display.frame);

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
        

        dat=hpp.YData;
        pix=obj.display.frame;

        if iscategorical(dat(pix))
            txt=char(dat(pix));
        end
        if isnumeric(dat(pix))
            txt=num2str(dat(pix));
        end

        title(hpo,txt);
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

end