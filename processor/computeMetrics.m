function [paramout,dataout, imageout]=computeMetrics(param,roiobj,frames)

listChannels=listAvailableChannels;
listChannels=['N/A', listChannels];
environment='pc' ;

imageout=[];

if nargin==0
    paramout=[];

    tip={'Name of Mask channel  #1',...
        'Compute detailed Mask #1 statistics (area, etc)',...
        'Class number used to identify (cell) contours for Mask #1 (defaullt:2); Put 0 if you want to score the dat for all mask values (like when having multiple cells)',...
        'Label of Mask channel  #1 (optional, eg cytoplasm, nucleus, foci,etc...)',...
        'Name of Mask channel  #2',...
        'Class number used to identify (subcellular) contours for Mask #2 (defaullt:2)',...
        'Label of Mask channel  #2 (optional, eg cytoplasm, nucleus, foci,etc...)',...
        'Compute detailed Mask #2 statistics (area, etc)',...
        'Channel name #1 to score',...
        'Channel name #2 to score',...
        'Channel name #3 to score',...
        'Channel name #4 to score',...
        'Number of pixels to consider to calculate mean brightest pixels (default 20)',...
        };

    paramout.mask1_name=[listChannels listChannels{1}];
    paramout.mask1_stat=true;
    paramout.mask1_class=2;
    paramout.mask1_label='cyto';
    paramout.mask2_name=[listChannels listChannels{1}];
    paramout.mask2_stat=true;
    paramout.mask2_class=2;
    paramout.mask2_label='nucl';

    paramout.channel1_name=[listChannels listChannels{1}];
    paramout.channel2_name=[listChannels listChannels{1}];
    paramout.channel3_name=[listChannels listChannels{1}];
    paramout.channel4_name=[listChannels listChannels{1}];

    paramout.BrightestPixels=20;

    paramout.tip=tip;

    return;
else
    paramout=param;
end

channelsExtract={};
channelsName={};



paramout.mask1_name= paramout.mask1_name{end};
paramout.mask2_name= paramout.mask2_name{end};


for i=1:4
    paramout.(['channel' num2str(i) '_name'])= paramout.(['channel' num2str(i) '_name']){end};
    if ~strcmp( paramout.(['channel' num2str(i) '_name']),'N/A')

        cha=roiobj.findChannelID(paramout.(['channel' num2str(i) '_name']));
        channelsExtract=[channelsExtract cha];

        tmpp=paramout.(['channel' num2str(i) '_name']);

        channelsName=[channelsName tmpp];
    end
end

% if numel(channelsExtract)==0 % this channel contains the segmented objects
%    disp([' These channels do not exist for this ROI ! Quitting ...']) ;
%    return;
% end

if numel(roiobj.image)==0
    roiobj.load
end

% compute mask metrics ------------------------------------

dataout=roiobj.data;

imageout=roiobj.image;

for i=1:2
    if  paramout.(['mask' num2str(i) '_stat']) &  ~strcmp(paramout.(['mask' num2str(i) '_name']),'N/A') % if detailed stat should be computed

        cha=roiobj.findChannelID(paramout.(['mask' num2str(i) '_name']));

        if numel(cha)==0
            disp('The mask you selected is unavailable for thi ROI ! qutting!!')
            return;
        end

        BW_3D=roiobj.image(:,:,cha,:);
        pixdata=find(arrayfun(@(x) strcmp(x.groupid, ['mask_quantification_' paramout.(['mask' num2str(i) '_name'])]),roiobj.data)); % find if object exists already

        %
        if numel(pixdata)
            cc=pixdata(1); % data to be overwritten
        else
            n=numel(dataout);
            if n==1 & numel(dataout.data)==0
                cc=1; % replace empty dataset
            else
                cc=numel(dataout)+1;
            end
        end

        % chatGPT code inserted

        nb_temps = size(BW_3D, 4);

        % Obtenir la liste des valeurs entières différentes du masque
        liste_valeurs = unique(BW_3D(:));
        liste_valeurs=setxor(liste_valeurs,0);

        % Initialiser les tableaux pour stocker les résultats
        surface = zeros(length(liste_valeurs), nb_temps);
        axe_majeur = zeros(length(liste_valeurs), nb_temps);
        axe_mineur = zeros(length(liste_valeurs), nb_temps);
        eccentricity = zeros(length(liste_valeurs), nb_temps);
        cellvolume=zeros(length(liste_valeurs), nb_temps);
        cellsurface=zeros(length(liste_valeurs), nb_temps);

        % Calculer les statistiques pour chaque valeur de masque et chaque temps
        val_surface={};
        val_axe_mineur={};
        val_axe_majeur={};
        val_eccentricity={};

        plotgroup={};
        defplot={};

        BW_3D=permute(BW_3D,[1 2 4 3]);
        BW_big=zeros(size(BW_3D));
        BW_big=repmat(BW_big,[1 1 1 length(liste_valeurs)]);

        cd=1;
        for v=1:length(liste_valeurs)
            valeur = liste_valeurs(v);
            BW_big(:,:,:,cd)=BW_3D==valeur;
            cd=cd+1;
        end

        BWcell=mat2cell(BW_big,size(BW_big,1),size(BW_big,2),ones(1,size(BW_big,3)),ones(1,size(BW_big,4)));

        f=@(BW) regionprops(BW, 'Area', 'MajorAxisLength', 'MinorAxisLength','Eccentricity');
        stats=cellfun(f,BWcell,'UniformOutput',false);
        stats=permute(stats,[3 4 1 2]);
        output = cellfun(@getra, stats, 'UniformOutput', false);
        output= cell2mat(output); output=output';
        surface=output(1:4:end,:);
        axe_majeur=output(2:4:end,:);
        axe_mineur=output(3:4:end,:);
        eccentricity=output(4:4:end,:);
        r=axe_mineur;
        h=axe_majeur -r;
        cellvolume= 4*pi*r.^3/3 + pi*r.^2.*h;
        cellsurface= 4*pi*r.^2 + 2*pi.*r.*h;
        % return


        for v = 1:length(liste_valeurs)
            valeur = liste_valeurs(v);
            val_surface{v}=   ['Area_' num2str(valeur)];
            val_axe_mineur{v}=['LenMinAxis_' num2str(valeur)];
            val_axe_majeur{v}=['LenMajAxis_' num2str(valeur)];
            val_eccentricity{v}=['Eccentric_' num2str(valeur)];

            % plotgroup=[plotgroup {'Area' 'Length' 'Length' 'Number'}];
      %      defplot=[defplot {false false false false}];
        end

    %    plotgroup=[repmat({'Area'},[1 length(liste_valeurs)]), repmat({'Length'},[1 length(liste_valeurs)]),...
     %    repmat({'Length'},[1 length(liste_valeurs)]) repmat({'Number'},[1 length(liste_valeurs)])];

        cell_data={};
        cell_name={};

     %   if numel(find(liste_valeurs==paramout.(['mask' num2str(i) '_class'])))

            pix=find(liste_valeurs==paramout.(['mask' num2str(i) '_class']));

            cell_data=[surface(pix,:); axe_mineur(pix,:) ; axe_majeur(pix,:); eccentricity(pix,:); cellvolume(pix,:); cellsurface(pix,:)];
            cell_name={'Area_Cell' 'LenMinAxis_Cell' 'LenMajAxis_Cell' 'Eccentric_Cell' 'Vol_Cell' 'Surf_Cell'};
            plotgroup=[{'Area' 'Length' 'Length' 'Number' 'Volume' 'Area'} plotgroup];
            defplot=[{true true true true true true} defplot];

     temp=dataseries([cell_data'],...
            [cell_name],...
            'groupid',['mask_quantification_' paramout.(['mask' num2str(i) '_name'])],'parentid',roiobj.id,'plot',defplot,'groups',plotgroup);

    %    temp=dataseries([cell_data' surface' axe_mineur' axe_majeur' eccentricity'],...
    %        [cell_name val_surface val_axe_mineur val_axe_majeur val_eccentricity],...
     %       'groupid',['mask_quantification_' paramout.(['mask' num2str(i) '_name'])],'parentid',roiobj.id,'plot',defplot,'groups',plotgroup);

        dataout(cc)=temp;
        dataout(cc).class="processing";
        dataout(cc).plotGroup={[] [] [] [] [] unique(plotgroup)};

       if paramout.(['mask' num2str(i) '_class'])==0 % in this case , write all the values within each column for all the object with a given mask label

         dataout(cc).data.Area_Cell=surface(1:end,:)'; % puts all the cell objects into the first columns, must format data this way
         dataout(cc).data.LenMinAxis_Cell=axe_mineur(1:end,:)' ;
         dataout(cc).data.LenMajAxis_Cell=axe_majeur(1:end,:)' ;
         dataout(cc).data.Eccentric_Cell=eccentricity(1:end,:)' ;
         dataout(cc).data.Vol_Cell=cellvolume(1:end,:)' ;
         dataout(cc).data.Surf_Cell=cellsurface(1:end,:)' ;

       end
      %  end

    end
end

%- that plots the cell statistics as histograms to get histograms of
%ratios
% -that plots the ratio as a new channel 


 if numel(channelsExtract)  % compute mean, total, max N pixels fluorescence for all channels, all masks, and intersection between bw1 and bw2
    im = roiobj.image;
         chabw={};
    for i=1:2
        if  ~strcmp(paramout.(['mask' num2str(i) '_name']),'N/A') % if detailed stat should be computed
            chabw{i}=roiobj.findChannelID(paramout.(['mask' num2str(i) '_name']));
        else
            chabw{i}=[];
        end
    end

    if numel(chabw{1})
        if paramout.(['mask' num2str(1) '_class'])> 0
        bw1=roiobj.image(:,:,chabw{1},:)==paramout.(['mask' num2str(1) '_class']); 
        else
        bw1=roiobj.image(:,:,chabw{1},:);  % expect an indexed image
        end

        bw1=repmat(bw1,[1 1 1 1 size(im,3)]);
        bw1=permute(bw1,[1 2 5 4 3]);
        bw1=reshape(bw1,[],size(bw1,3),size(bw1,4));
    end

    if numel(chabw{2})
         if paramout.(['mask' num2str(1) '_class'])> 0
        bw2=roiobj.image(:,:,chabw{2},:)==paramout.(['mask' num2str(1) '_class']);
         else
        bw2=roiobj.image(:,:,chabw{2},:); % expect an indexed image
         end

        bw2=repmat(bw2,[1 1 1 1 size(im,3)]);
        bw2=permute(bw2,[1 2 5 4 3]);
        bw2=reshape(bw2,[],size(bw2,3),size(bw2,4));
    end

    N = paramout.BrightestPixels; % Nombre de pixels les plus brillants à considérer

    if numel(chabw{1})
         pixels_actifs1 = reshape(im,[],size(im,3),size(im,4));
    end
       if numel(chabw{2})
         pixels_actifs2 = reshape(im,[],size(im,3),size(im,4));
    end

  if numel(chabw{1})
   val1=unique(bw1);
   moyennes1=NaN*ones(length(val1),size(bw1,2),size(bw1,3));
   sommes1=moyennes1;
   moyenne_brillants1=moyennes1;
   somme_brillants1=moyennes1;

   for i=1:size(bw1,3) % loop on time 
       for k=1:size(bw1,2) % loop on channels
           cc=1;
            for j=val1'
                  vpix=pixels_actifs1(:,k,i);
                   tmp=bw1(:,k,i);
                    pix=tmp==j;
                    moyennes1(cc,k,i)=mean(vpix(pix));
                    sommes1(cc,k,i)=sum(vpix(pix));
                    moyenne_brillants1(cc,k,i) =  meanTopNValues(vpix(pix), N);
                    somme_brillants1(cc,k,i) =  sumTopNValues(vpix(pix), N);
                    cc=cc+1;
            end
       end
   end

   moyenne_exterieur1=moyennes1(1,:,:);
   difference1=moyennes1-moyenne_exterieur1;
  end


 if numel(chabw{2})
   val2=unique(bw2);
   moyennes2=NaN*ones(length(val2),size(bw2,2),size(bw2,3));
   sommes2=moyennes2;
   moyenne_brillants2=moyennes2;
   somme_brillants2=moyennes2;

   for i=1:size(bw2,3) % loop on time 
       for k=1:size(bw2,2) % loop on channels
           cc=1;
            for j=val1'
                  vpix=pixels_actifs2(:,k,i);
                   tmp=bw2(:,k,i);
                    pix=tmp==j;
                    moyennes2(cc,k,i)=mean(vpix(pix));
                    sommes2(cc,k,i)=sum(vpix(pix));
                    moyenne_brillants2 =  meanTopNValues(vpix(pix), N);
                    somme_brillants2 =  sumTopNValues(vpix(pix), N);
                    cc=cc+1;
            end
       end
   end

   moyenne_exterieur2=moyennes2(1,:,:);
   difference2=moyennes2-moyenne_exterieur2;
 end

 % do the intersection later
 if numel(chabw{1}) &&  numel(chabw{2})
    
        moyenne_intersection = zeros(1, size(im, 3), size(im, 4));

%             somme_intersection = zeros(1, size(im, 3), size(im, 4));
         if any(pixels_intersection(:))
% 
%             moyenne_intersection = sum(pixels_intersection, 1)./sum(uint16(bw1 & bw2), 1);
%             somme_intersection = sum(pixels_intersection, 1);
  %       else
% 
%             moyenne_intersection = zeros(1, size(im, 3), size(im, 4));
%             somme_intersection = zeros(1, size(im, 3), size(im, 4));
         end
% 
         if any(pixels_intersection2(:))
%             moyenne_intersection2 = mean(pixels_intersection2, 1)./sum(uint16(bw1 & ~bw2), 1);
%             somme_intersection2 = sum(pixels_intersection2, 1);
 %        else
%             moyenne_intersection2 = zeros(1, size(im, 3), size(im, 4));
%             somme_intersection2 = zeros(1, size(im, 3), size(im, 4));
         end
 end



    name={};
    group={};
    defplot={};
    dat=[];
    dat1=[];
    dat2=[];
    dat3=[];

    for i=1:numel(channelsExtract)
        cha=channelsExtract{i}; % cha has several elements in case of an RGB image

        bwn=1;
        if numel(chabw{bwn})

           % for ch=1:numel(cha)
            name=[name, ['Mean_' channelsName{i}  '_' paramout.(['mask' num2str(bwn) '_label'])],...
                ['Tot_' channelsName{i}   '_' paramout.(['mask' num2str(bwn) '_label'])],...
                ['MeanTop_' channelsName{i}  '_' paramout.(['mask' num2str(bwn) '_label'])],...
                ['TotTop_' channelsName{i}  '_' paramout.(['mask' num2str(bwn) '_label'])],...
                ['Mean_Bckg_' channelsName{i}  '_' paramout.(['mask' num2str(bwn) '_label'])],...
                ['MeanNoBckg_' channelsName{i}  '_' paramout.(['mask' num2str(bwn) '_label'])]];
            group=[group {['Mean_' channelsName{i}], ['Total_' channelsName{i}], ['Mean_' channelsName{i}], ['Total_' channelsName{i}], ['Mean_' channelsName{i}], ['Mean_' channelsName{i}]} ];
            defplot=[defplot {false false false false false true}];
          %  end

            dat1=[dat1 mean(moyennes1(1,cha,:),2) mean(sommes1(1,cha,:),2) mean(moyenne_brillants1(1,cha,:),2),...
                mean(somme_brillants1(1,cha,:),2) mean(moyenne_exterieur1(1,cha,:),2) mean(difference1(1,cha,:),2)];
        end

        bwn=2;
        if numel(chabw{bwn})

            % for ch=1:numel(cha)
            name=[name, ['Mean_' channelsName{i} '_' paramout.(['mask' num2str(bwn) '_label'])],...
                ['Tot_' channelsName{i}  '_' paramout.(['mask' num2str(bwn) '_label'])],...
                ['MeanTop_' channelsName{i}  '_' paramout.(['mask' num2str(bwn) '_label'])],...
                ['TotTop_' channelsName{i} '_' paramout.(['mask' num2str(bwn) '_label'])],...
                ['Mean_Bckg_' channelsName{i}   '_' paramout.(['mask' num2str(bwn) '_label'])],...
                ['MeanNoBckg_' channelsName{i} '_' paramout.(['mask' num2str(bwn) '_label'])]];
            group=[group {['Mean_' channelsName{i}], ['Total_' channelsName{i}], ['Mean_' channelsName{i}], ['Total_' channelsName{i}], ['Mean_' channelsName{i}], ['Mean_' channelsName{i}]} ];
            defplot=[defplot {false false false false false true}];
           % end

        %    dat2=[dat2 moyennes2(:,cha,:) sommes2(:,cha,:) moyenne_brillants2(:,cha,:),...
        %        somme_brillants2(:,cha,:) moyenne_exterieur2(:,cha,:) difference2(:,cha,:)];

             dat2=[dat2 mean(moyennes2(1,cha,:),2) mean(sommes2(1,cha,:),2) mean(moyenne_brillants2(1,cha,:),2),...
                mean(somme_brillants2(1,cha,:),2) mean(moyenne_exterieur2(1,cha,:),2) mean(difference2(1,cha,:),2)];

        end


        % intersection : to be done later

        %         bwn=1;
%         if numel(chabw{1}) &&  numel(chabw{2})
%           %   for ch=1:numel(cha)
%             name=[name, ['Mean_' channelsName{i}  '_' paramout.(['mask' num2str(bwn) '_label']) 'AND' paramout.(['mask' num2str(bwn+1) '_label'])],...
%                 ['Tot_' channelsName{i}  '_' paramout.(['mask' num2str(bwn) '_label']) '_AND_' paramout.(['mask' num2str(bwn+1) '_label'])],...
%                 ['Mean_' channelsName{i}  '_' paramout.(['mask' num2str(bwn) '_label']) '_AND_NOT_' paramout.(['mask' num2str(bwn+1) '_label'])],...
%                 ['Tot_' channelsName{i}  '_' paramout.(['mask' num2str(bwn) '_label']) '_AND_NOT_' paramout.(['mask' num2str(bwn+1) '_label'])]];
%             group=[group {['Mean_' channelsName{i}], ['Total_' channelsName{i}], ['Mean_' channelsName{i}], ['Total_' channelsName{i}]} ];
%             defplot=[defplot {true false true false}];
%           %   end
% 
%             dat3=[dat3 mean(moyenne_intersection(:,cha,:),2), mean(somme_intersection(:,cha,:),2),...
%                 mean(moyenne_intersection2(:,cha,:),2),mean(somme_intersection2(:,cha,:),2)];
%         end

    end


    %  %  compute ratios between channels

  ratios=[];

  bwn=1;
    if numel(chabw{bwn})
        for i=1:numel(channelsExtract)
            for j=i+1:numel(channelsExtract) % Assurez-vous de calculer chaque paire une seule fois
                cha_i = channelsExtract{i};
                cha_j = channelsExtract{j};

                % Calcul du ratio de MeanNoBckg entre les canaux i et j
                ratioMeanNoBckg = mean(difference1(1,cha_i,:),2) ./ mean(difference1(1,cha_j,:),2); % Exemple avec dat1, ajustez pour dat2 et dat3 si nécessaire

                % Mise à jour des noms des métriques
                ratioName = ['Ratio_Mean_NoBckg_' channelsName{i} '_' channelsName{j} '_' paramout.(['mask' num2str(bwn) '_label'])];
                name = [name, ratioName];

                % Stockage des valeurs calculées
                % Note: Vous aurez besoin d'une nouvelle variable pour stocker ces ratios
                % Par exemple, si vous utilisez 'ratios' comme nouvelle variable de stockage
                if ~exist('ratios', 'var')
                    ratios = []; % Initialise si elle n'existe pas encore
                end
                ratios = [ratios, ratioMeanNoBckg];

                group = [group, {ratioName}];
                defplot = [defplot, {false}];
            end
        end
    end


  bwn=2;
    if numel(chabw{bwn})
        for i=1:numel(channelsExtract)
            for j=i+1:numel(channelsExtract) % Assurez-vous de calculer chaque paire une seule fois
                cha_i = channelsExtract{i};
                cha_j = channelsExtract{j};

                % Calcul du ratio de MeanNoBckg entre les canaux i et j
                ratioMeanNoBckg = mean(difference2(1,cha_i,:),2) ./ mean(difference2(1,cha_j,:),2); % Exemple avec dat1, ajustez pour dat2 et dat3 si nécessaire

                % Mise à jour des noms des métriques
                ratioName = ['Ratio_Mean_NoBckg_' channelsName{i} '_' channelsName{j} '_' paramout.(['mask' num2str(bwn) '_label'])];
                name = [name, ratioName];

                % Stockage des valeurs calculées
                % Note: Vous aurez besoin d'une nouvelle variable pour stocker ces ratios
                % Par exemple, si vous utilisez 'ratios' comme nouvelle variable de stockage
                if ~exist('ratios', 'var')
                    ratios = []; % Initialise si elle n'existe pas encore
                end

                ratios = [ratios, ratioMeanNoBckg];
                group = [group, {ratioName}];
                defplot = [defplot, {false}];
            end
        end
    end

     if numel(dat1)
        dat1=permute(dat1,[3 2 1]);
        dat=dat1;
    end
    if numel(dat2)
        dat2=permute(dat2,[3 2 1]);
        dat=[dat dat2];
    end
    if numel(dat3)
        dat3=permute(dat3,[3 2 1]);
        dat=[dat dat3];
    end

    if numel(ratios)
        ratios=permute(ratios,[3 2 1]);
        dat=[dat ratios];
    end

    temp=dataseries(dat,name,...
        'groupid','channel_quantification','parentid',roiobj.id,'plot',defplot,'groups',group);

    pixdata=find(arrayfun(@(x) strcmp(x.groupid, 'channel_quantification'),dataout)); % find if object exists already

    %
    if numel(pixdata)
        cc=pixdata(1); % data to be overwritten
    else
        n=numel(dataout);
        if n==1 & numel(dataout)==0
            cc=1; % replace empty dataset
        else
            cc=numel(dataout)+1;
        end
    end

    dataout(cc)=temp;
    dataout(cc).class="processing";

      for i=1:numel(channelsExtract)
        cha=channelsExtract{i}; % cha has several elements in case of an RGB image
        bwn=1;
        if numel(chabw{bwn})
          dataout(cc).data.(['Mean_' channelsName{i}  '_' paramout.(['mask' num2str(bwn) '_label'])])=squeeze(mean(moyennes1(:,cha,:),2)).';
          dataout(cc).data.(['Tot_' channelsName{i}  '_' paramout.(['mask' num2str(bwn) '_label'])])=squeeze(mean(moyennes1(:,cha,:),2)).';
          dataout(cc).data.(['MeanTop_' channelsName{i}  '_' paramout.(['mask' num2str(bwn) '_label'])])=squeeze(mean(moyenne_brillants1(:,cha,:),2)).';
          dataout(cc).data.(['TotTop_' channelsName{i}  '_' paramout.(['mask' num2str(bwn) '_label'])])=squeeze(mean(somme_brillants1(:,cha,:),2)).';
          dataout(cc).data.(['MeanNoBckg_' channelsName{i}  '_' paramout.(['mask' num2str(bwn) '_label'])])=squeeze(mean(difference1(:,cha,:),2)).';

        end
        bwn=2;
        if numel(chabw{bwn})
          dataout(cc).data.(['Mean_' channelsName{i}  '_' paramout.(['mask' num2str(bwn) '_label'])])=squeeze(mean(moyennes2(:,cha,:),2)).';
          dataout(cc).data.(['Tot_' channelsName{i}  '_' paramout.(['mask' num2str(bwn) '_label'])])=squeeze(mean(moyennes2(:,cha,:),2)).';
          dataout(cc).data.(['MeanTop_' channelsName{i}  '_' paramout.(['mask' num2str(bwn) '_label'])])=squeeze(mean(moyenne_brillants2(:,cha,:),2)).';
          dataout(cc).data.(['TotTop_' channelsName{i}  '_' paramout.(['mask' num2str(bwn) '_label'])])=squeeze(mean(somme_brillants2(:,cha,:),2)).';
          dataout(cc).data.(['MeanNoBckg_' channelsName{i}  '_' paramout.(['mask' num2str(bwn) '_label'])])=squeeze(mean(difference2(:,cha,:),2)).';
        end
        
      end
        for i=1:numel(channelsExtract)
            for j=i+1:numel(channelsExtract) % Assurez-vous de calculer chaque paire une seule fois
                cha_i = channelsExtract{i};
                cha_j = channelsExtract{j};
                      bwn=1;

                     if numel(chabw{bwn})
                             ratioMeanNoBckg = squeeze(mean(difference1(:,cha_i,:),2) ./ mean(difference1(:,cha_j,:),2)).';
                             ratioName = ['Ratio_Mean_NoBckg_' channelsName{i} '_' channelsName{j} '_' paramout.(['mask' num2str(bwn) '_label'])];
                              dataout(cc).data.(ratioName)=ratioMeanNoBckg;
                     end

                      bwn=2;

                     if numel(chabw{bwn})
                             ratioMeanNoBckg = squeeze(mean(difference2(:,cha_i,:),2) ./ mean(difference2(:,cha_j,:),2)).';
                             ratioName = ['Ratio_Mean_NoBckg_' channelsName{i} '_' channelsName{j} '_' paramout.(['mask' num2str(bwn) '_label'])];
                              dataout(cc).data.(ratioName)=ratioMeanNoBckg;
                      end

            end
        end

    %roiobj.data(cc).plotGroup={[] [] [] [] [] unique(group)};
end


% if numel(channelsExtract)
%     % compute mean, total, max N pixels fluorescence for all channels, all masks, and intersection between bw1 and bw2
%     im = roiobj.image;
% 
%     chabw={};
%     for i=1:2
%         if  ~strcmp(paramout.(['mask' num2str(i) '_name']),'N/A') % if detailed stat should be computed
%             chabw{i}=roiobj.findChannelID(paramout.(['mask' num2str(i) '_name']));
%         else
%             chabw{i}=[];
%         end
%     end
% 
%     if numel(chabw{1})
%         bw1=roiobj.image(:,:,chabw{1},:)==paramout.(['mask' num2str(1) '_class']); 
%         bw1=repmat(bw1,[1 1 1 1 size(im,3)]);
%         bw1=permute(bw1,[1 2 5 4 3]);
%         bw1=reshape(bw1,[],size(bw1,3),size(bw1,4));
%     end
% 
%     if numel(chabw{2})
%         bw2=roiobj.image(:,:,chabw{2},:)==paramout.(['mask' num2str(1) '_class']);
%         bw2=repmat(bw2,[1 1 1 1 size(im,3)]);
%         bw2=permute(bw2,[1 2 5 4 3]);
%         bw2=reshape(bw2,[],size(bw2,3),size(bw2,4));
%     end
% 
%     N = paramout.BrightestPixels; % Nombre de pixels les plus brillants à considérer
% 
%     % Calcul des valeurs moyennes des pixels actifs, des sommes, de la moyenne à l'extérieur du masque et des différences pour tous les instants et tous les canaux pour bw1
%     if numel(chabw{1})
%         pixels_actifs1 = reshape(im,[],size(im,3),size(im,4)).*uint16(bw1);
%         pixels_exterieur1 = reshape(im,[],size(im,3),size(im,4)).*uint16(~bw1);
%         moyennes1=sum(pixels_actifs1,1)./sum(uint16(bw1),1);
%         sommes1 = sum(pixels_actifs1,1);
%         moyenne_exterieur1 = sum(pixels_exterieur1,1)./sum(uint16(~bw1),1);
%         difference1 = moyennes1 - moyenne_exterieur1;
% 
%         % Calcul des valeurs moyennes des N pixels les plus brillants pour tous les instants et tous les canaux pour bw1
%         pixels_actifs_sorted1 = sort(pixels_actifs1, 1, 'descend');
%         moyenne_brillants1 = mean(pixels_actifs_sorted1(1:N, :, :), 1);
%         somme_brillants1 = sum(pixels_actifs_sorted1(1:N, :, :), 1);
%     end
% 
%     % Calcul des valeurs moyennes des pixels actifs, des sommes, de la moyenne à l'extérieur du masque et des différences pour tous les instants et tous les canaux pour bw2
%     if numel(chabw{2})
%         pixels_actifs2 = reshape(im,[],size(im,3),size(im,4)).*uint16(bw2);
%         pixels_exterieur2 = reshape(im,[],size(im,3),size(im,4)).*uint16(~bw2);
%         moyennes2=sum(pixels_actifs2,1)./sum(uint16(bw2),1);
%         sommes2 = sum(pixels_actifs2,1);
%         moyenne_exterieur2 = sum(pixels_exterieur2,1)./sum(uint16(~bw2),1);
%         difference2 = moyennes2 - moyenne_exterieur2;
% 
%         % Calcul des valeurs moyennes des N pixels les plus brillants pour tous les instants et tous les canaux pour bw2
%         pixels_actifs_sorted2 = sort(pixels_actifs2, 1, 'descend');
%         moyenne_brillants2 = mean(pixels_actifs_sorted2(1:N, :, :), 1);
%         somme_brillants2 = sum(pixels_actifs_sorted2(1:N, :, :), 1);
%     end
% 
%     % Calcul de la valeur moyenne et totale de im pour l'intersection de bw1 et bw2
%     if numel(chabw{1}) &&  numel(chabw{2})
%         pixels_intersection = reshape(im,[],size(im,3),size(im,4)) .* uint16(bw1 & bw2);
%         pixels_intersection2 = reshape(im,[],size(im,3),size(im,4)) .* uint16(bw1 & ~bw2);
% 
%         if any(pixels_intersection(:))
%             moyenne_intersection = sum(pixels_intersection, 1)./sum(uint16(bw1 & bw2), 1);
%             somme_intersection = sum(pixels_intersection, 1);
%         else
%             moyenne_intersection = zeros(1, size(im, 3), size(im, 4));
%             somme_intersection = zeros(1, size(im, 3), size(im, 4));
%         end
% 
%         if any(pixels_intersection2(:))
%             moyenne_intersection2 = mean(pixels_intersection2, 1)./sum(uint16(bw1 & ~bw2), 1);
%             somme_intersection2 = sum(pixels_intersection2, 1);
%         else
%             moyenne_intersection2 = zeros(1, size(im, 3), size(im, 4));
%             somme_intersection2 = zeros(1, size(im, 3), size(im, 4));
%         end
%     end
% 
%     name={};
%     group={};
%     defplot={};
%     dat=[];
%     dat1=[];
%     dat2=[];
%     dat3=[];
% 
%     for i=1:numel(channelsExtract)
%         cha=channelsExtract{i}; % cha has several elements in case of an RGB image
% 
%         bwn=1;
%         if numel(chabw{bwn})
% 
%            % for ch=1:numel(cha)
%             name=[name, ['Mean_' channelsName{i}  '_' paramout.(['mask' num2str(bwn) '_label'])],...
%                 ['Tot_' channelsName{i}   '_' paramout.(['mask' num2str(bwn) '_label'])],...
%                 ['MeanTop_' channelsName{i}  '_' paramout.(['mask' num2str(bwn) '_label'])],...
%                 ['TotTop_' channelsName{i}  '_' paramout.(['mask' num2str(bwn) '_label'])],...
%                 ['Mean_Bckg_' channelsName{i}  '_' paramout.(['mask' num2str(bwn) '_label'])],...
%                 ['MeanNoBckg_' channelsName{i}  '_' paramout.(['mask' num2str(bwn) '_label'])]];
%             group=[group {['Mean_' channelsName{i}], ['Total_' channelsName{i}], ['Mean_' channelsName{i}], ['Total_' channelsName{i}], ['Mean_' channelsName{i}], ['Mean_' channelsName{i}]} ];
%             defplot=[defplot {false false false false false true}];
%           %  end
% 
%             dat1=[dat1 mean(moyennes1(:,cha,:),2) mean(sommes1(:,cha,:),2) mean(moyenne_brillants1(:,cha,:),2),...
%                 mean(somme_brillants1(:,cha,:),2) mean(moyenne_exterieur1(:,cha,:),2) mean(difference1(:,cha,:),2)];
%         end
% 
%         bwn=2;
%         if numel(chabw{bwn})
% 
%             % for ch=1:numel(cha)
%             name=[name, ['Mean_' channelsName{i} '_' paramout.(['mask' num2str(bwn) '_label'])],...
%                 ['Tot_' channelsName{i}  '_' paramout.(['mask' num2str(bwn) '_label'])],...
%                 ['MeanTop_' channelsName{i}  '_' paramout.(['mask' num2str(bwn) '_label'])],...
%                 ['TotTop_' channelsName{i} '_' paramout.(['mask' num2str(bwn) '_label'])],...
%                 ['Mean_Bckg_' channelsName{i}   '_' paramout.(['mask' num2str(bwn) '_label'])],...
%                 ['MeanNoBckg_' channelsName{i} '_' paramout.(['mask' num2str(bwn) '_label'])]];
%             group=[group {['Mean_' channelsName{i}], ['Total_' channelsName{i}], ['Mean_' channelsName{i}], ['Total_' channelsName{i}], ['Mean_' channelsName{i}], ['Mean_' channelsName{i}]} ];
%             defplot=[defplot {false false false false false true}];
%            % end
% 
%         %    dat2=[dat2 moyennes2(:,cha,:) sommes2(:,cha,:) moyenne_brillants2(:,cha,:),...
%         %        somme_brillants2(:,cha,:) moyenne_exterieur2(:,cha,:) difference2(:,cha,:)];
% 
%              dat2=[dat2 mean(moyennes2(:,cha,:),2) mean(sommes2(:,cha,:),2) mean(moyenne_brillants2(:,cha,:),2),...
%                 mean(somme_brillants2(:,cha,:),2) mean(moyenne_exterieur2(:,cha,:),2) mean(difference2(:,cha,:),2)];
% 
%         end
% 
%         bwn=1;
%         if numel(chabw{1}) &&  numel(chabw{2})
%           %   for ch=1:numel(cha)
%             name=[name, ['Mean_' channelsName{i}  '_' paramout.(['mask' num2str(bwn) '_label']) 'AND' paramout.(['mask' num2str(bwn+1) '_label'])],...
%                 ['Tot_' channelsName{i}  '_' paramout.(['mask' num2str(bwn) '_label']) '_AND_' paramout.(['mask' num2str(bwn+1) '_label'])],...
%                 ['Mean_' channelsName{i}  '_' paramout.(['mask' num2str(bwn) '_label']) '_AND_NOT_' paramout.(['mask' num2str(bwn+1) '_label'])],...
%                 ['Tot_' channelsName{i}  '_' paramout.(['mask' num2str(bwn) '_label']) '_AND_NOT_' paramout.(['mask' num2str(bwn+1) '_label'])]];
%             group=[group {['Mean_' channelsName{i}], ['Total_' channelsName{i}], ['Mean_' channelsName{i}], ['Total_' channelsName{i}]} ];
%             defplot=[defplot {true false true false}];
%           %   end
% 
%             dat3=[dat3 mean(moyenne_intersection(:,cha,:),2), mean(somme_intersection(:,cha,:),2),...
%                 mean(moyenne_intersection2(:,cha,:),2),mean(somme_intersection2(:,cha,:),2)];
%         end
% 
%     end
% 
% 
%  %  compute ratios between channels
% 
%   ratios=[];
% 
%   bwn=1;
%     if numel(chabw{bwn})
%         for i=1:numel(channelsExtract)
%             for j=i+1:numel(channelsExtract) % Assurez-vous de calculer chaque paire une seule fois
%                 cha_i = channelsExtract{i};
%                 cha_j = channelsExtract{j};
% 
%                 % Calcul du ratio de MeanNoBckg entre les canaux i et j
%                 ratioMeanNoBckg = difference1(:,cha_i,:) ./ difference1(:,cha_j,:); % Exemple avec dat1, ajustez pour dat2 et dat3 si nécessaire
% 
%                 % Mise à jour des noms des métriques
%                 ratioName = ['Ratio_Mean_NoBckg_' channelsName{i} '_' channelsName{j} '_' paramout.(['mask' num2str(bwn) '_label'])];
%                 name = [name, ratioName];
% 
%                 % Stockage des valeurs calculées
%                 % Note: Vous aurez besoin d'une nouvelle variable pour stocker ces ratios
%                 % Par exemple, si vous utilisez 'ratios' comme nouvelle variable de stockage
%                 if ~exist('ratios', 'var')
%                     ratios = []; % Initialise si elle n'existe pas encore
%                 end
%                 ratios = [ratios, ratioMeanNoBckg];
% 
%                 group = [group, {ratioName}];
%                 defplot = [defplot, {false}];
%             end
%         end
%     end
% 
% 
%   bwn=2;
%     if numel(chabw{bwn})
%         for i=1:numel(channelsExtract)
%             for j=i+1:numel(channelsExtract) % Assurez-vous de calculer chaque paire une seule fois
%                 cha_i = channelsExtract{i};
%                 cha_j = channelsExtract{j};
% 
%                 % Calcul du ratio de MeanNoBckg entre les canaux i et j
%                 ratioMeanNoBckg = difference2(:,cha_i,:) ./ difference2(:,cha_j,:); % Exemple avec dat1, ajustez pour dat2 et dat3 si nécessaire
% 
%                 % Mise à jour des noms des métriques
%                 ratioName = ['Ratio_Mean_NoBckg_' channelsName{i} '_' channelsName{j} '_' paramout.(['mask' num2str(bwn) '_label'])];
%                 name = [name, ratioName];
% 
%                 % Stockage des valeurs calculées
%                 % Note: Vous aurez besoin d'une nouvelle variable pour stocker ces ratios
%                 % Par exemple, si vous utilisez 'ratios' comme nouvelle variable de stockage
%                 if ~exist('ratios', 'var')
%                     ratios = []; % Initialise si elle n'existe pas encore
%                 end
%                 ratios = [ratios, ratioMeanNoBckg];
% 
%                 group = [group, {ratioName}];
%                 defplot = [defplot, {false}];
%             end
%         end
%     end
% 
%     if numel(dat1)
%         dat1=permute(dat1,[3 2 1]);
%         dat=dat1;
%     end
%     if numel(dat2)
%         dat2=permute(dat2,[3 2 1]);
%         dat=[dat dat2];
%     end
%     if numel(dat3)
%         dat3=permute(dat3,[3 2 1]);
%         dat=[dat dat3];
%     end
% 
%     if numel(ratios)
%         ratios=permute(ratios,[3 2 1]);
%         dat=[dat ratios];
%     end
% 
%     temp=dataseries(dat,name,...
%         'groupid','channel_quantification','parentid',roiobj.id,'plot',defplot,'groups',group);
% 
%     pixdata=find(arrayfun(@(x) strcmp(x.groupid, 'channel_quantification'),dataout)); % find if object exists already
% 
%     %
%     if numel(pixdata)
%         cc=pixdata(1); % data to be overwritten
%     else
%         n=numel(dataout);
%         if n==1 & numel(dataout)==0
%             cc=1; % replace empty dataset
%         else
%             cc=numel(dataout)+1;
%         end
%     end
% 
%     dataout(cc)=temp;
%     dataout(cc).class="processing";
%     %roiobj.data(cc).plotGroup={[] [] [] [] [] unique(group)};
% end


function y=getra(x)

if numel(x)==0
    y=[NaN NaN NaN NaN];
else
    y=[x.Area x.MajorAxisLength x.MinorAxisLength x.Eccentricity] ;
end



% Définition de la fonction auxiliaire topNValues
function topN =meanTopNValues(x, N)
    sortedX = sort(x, 'descend'); % Tri par ordre décroissant
    topN = mean(sortedX(1:min(N,end))); % Sélectionne les N premières valeurs et calcule la moyenne


function topN = sumTopNValues(x, N)
    sortedX = sort(x, 'descend'); % Tri par ordre décroissant
    topN = sum(sortedX(1:min(N,end))); % Sélectionne les N premières valeurs et calcule la moyenne



