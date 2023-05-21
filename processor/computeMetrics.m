function paramout=computeMetrics(param,roiobj,frames)

listChannels=listAvailableChannels;
listChannels=['N/A', listChannels];
environment='pc' ;

if nargin==0
    paramout=[];

    tip={'Name of Mask channel  #1 (eg cell contours)',...
        'Compute detailed Mask #1 statistics (area, etc)',...
        'Class number used to identify (cell) contours for Mask #1 (defaullt:2)',...
        'Name of Mask channel  #2 (optional, eg nucleus, foci,etc...)',...
        'Class number used to identify (subcellular) contours for Mask #2 (defaullt:2)',...
        'Compute detailed Mask #2 statistics (area, etc)',...
        'Channel name #1 to score',...
        'Channel name #2 to score',...
        'Channel name #3 to score',...
        'Channel name #4 to score',...
        'Max intensity pixel number (default 20)',...
        'Number of frames between 2 fluo acquisitions'};

    paramout.mask1_name=[listChannels listChannels{1}];
    paramout.mask1_stat=true;
    paramout.mask1_class=2;
    paramout.mask2_name=[listChannels listChannels{1}];
    paramout.mask2_stat=true;
    paramout.mask2_class=2;

    paramout.channel1_name=[listChannels listChannels{1}];
    paramout.channel2_name=[listChannels listChannels{1}];
    paramout.channel3_name=[listChannels listChannels{1}];
    paramout.channel4_name=[listChannels listChannels{1}];

    paramout.kMaxPixels=20;
    paramout.snapinc=1;

    paramout.tip=tip;

    return;
else
    paramout=param;
end

snapinc=paramout.snapinc;

channelsExtract={};
channelsName={};

paramout.mask1_name= paramout.mask1_name{end};
paramout.mask2_name= paramout.mask2_name{end};

i=1;

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

% compute mask metrics

for i=1:2
    if  paramout.(['mask' num2str(i) '_stat']) &  ~strcmp(paramout.(['mask' num2str(i) '_name']),'N/A') % if detailed stat should be computed

        cha=roiobj.findChannelID(paramout.(['mask' num2str(i) '_name']));

        if numel(cha)==0
            continue
        end

        BW_3D=roiobj.image(:,:,cha,:);
        pixdata=find(arrayfun(@(x) strcmp(x.groupid, paramout.(['mask' num2str(i) '_name'])),roiobj.data)); % find if object exists already

        %
        if numel(pixdata)
            cc=pixdata(1); % data to be overwritten
        else
            n=numel(roiobj.data);
            if n==1 & numel(roiobj.data.data)==0
                cc=1; % replace empty dataset
            else
                cc=numel(roiobj.data)+1;
            end
        end

        % chatGPT code inserted

        nb_temps = size(BW_3D, 4);

        % Obtenir la liste des valeurs entières différentes du masque
        liste_valeurs = unique(BW_3D(:));

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

        for v = 1:length(liste_valeurs)
            for t = 1:nb_temps
                % Extraire le masque BW pour la valeur et le temps courants
                valeur = liste_valeurs(v);
                BW = (BW_3D(:,:,1,t) == valeur);

                % Calculer les statistiques
                stats = regionprops(BW, 'Area', 'MajorAxisLength', 'MinorAxisLength','Eccentricity');

                % Stocker les résultats dans les tableaux
                surface(v,t) = sum([stats.Area]);
                axe_majeur(v,t) = mean([stats.MajorAxisLength]);
                axe_mineur(v,t) = mean([stats.MinorAxisLength]);
                eccentricity(v,t) = mean([stats.Eccentricity]);

                %here
                r=axe_mineur(v,t);
                h=axe_majeur(v,t) -r;

                cellvolume(v,t)= 4*pi*r^3/3 + pi*r^2*h;
                cellsurface(v,t)= 4*pi*r^2 + 2*pi*r*h;

            end

            val_surface{v}=   ['Area_Mask_' num2str(valeur)];
            val_axe_mineur{v}=['Length_Minor_Axis_' num2str(valeur)];
            val_axe_majeur{v}=['Length_Major_Axis_' num2str(valeur)];
            val_eccentricity{v}=['Number_Eccentricity_' num2str(valeur)];

            % plotgroup=[plotgroup {'Area' 'Length' 'Length' 'Number'}];
            defplot=[defplot {false false false false}];

        end

        plotgroup=[repmat({'Area'},[1 length(liste_valeurs)]), repmat({'Length'},[1 length(liste_valeurs)]),...
            repmat({'Length'},[1 length(liste_valeurs)]) repmat({'Number'},[1 length(liste_valeurs)])];

        cell_data={};
        cell_name={};

        if numel(find(liste_valeurs==paramout.(['mask' num2str(i) '_class'])))

            pix=find(liste_valeurs==paramout.(['mask' num2str(i) '_class']));

            cell_data=[surface(pix,:); axe_mineur(pix,:) ; axe_majeur(pix,:); eccentricity(pix,:); cellvolume(pix,:); cellsurface(pix,:)];
            cell_name={'Area_Projected_Cell' 'Length_MinorAxis_Cell' 'Length_MajorAxis_Cell' 'Number_Eccentricity' 'Volume_Cell' 'Surface_Cell'};
            plotgroup=[{'Area' 'Length' 'Length' 'Number' 'Volume' 'Area'} plotgroup];
            defplot=[{true true true true true true} defplot];
        end

        % size([cell_data' surface' axe_mineur' axe_majeur' eccentricity'])
        % size([cell_name val_surface val_axe_mineur val_axe_majeur val_eccentricity])

        temp=dataseries([cell_data' surface' axe_mineur' axe_majeur' eccentricity'],...
            [cell_name val_surface val_axe_mineur val_axe_majeur val_eccentricity],...
            'groupid',paramout.(['mask' num2str(i) '_name']),'parentid',roiobj.id,'plot',defplot,'groups',plotgroup);

        roiobj.data(cc)=temp;
        roiobj.data(cc).class="processing";
        roiobj.data(cc).plotGroup={[] [] [] [] [] unique(plotgroup)};

    end
end

% chatGPT code:  compute mean, total, max N pixels fluorescence for all channels, all masks, and intersection between bw1 and bw2

im = roiobj.image;

chabw={};
for i=1:2
    if  ~strcmp(paramout.(['mask' num2str(i) '_name']),'N/A') % if detailed stat should be computed

        chabw{i}=roiobj.findChannelID(paramout.(['mask' num2str(i) '_name']));

    end
end

if numel(chabw{1})
    bw1=roiobj.image(:,:,chabw{1},:);
    bw1=repmat(bw1,[1 1 1 1 size(im,3)]);
    bw1=permute(bw1,[1 2 5 4 3]);
    bw1=reshape(bw1,[],size(bw1,3),size(bw1,4));
end

if numel(chabw{2})
    bw2=roiobj.image(:,:,chabw{2},:);
    bw2=repmat(bw2,[1 1 1 1 size(im,3)]);
    bw2=permute(bw2,[1 2 5 4 3]);
    bw2=reshape(bw2,[],size(bw2,3),size(bw2,4));
end

N = paramout.kMaxPixels; % Nombre de pixels les plus brillants à considérer

% Calcul des valeurs moyennes des pixels actifs, des sommes, de la moyenne à l'extérieur du masque et des différences pour tous les instants et tous les canaux pour bw1
if numel(chabw{1})
    pixels_actifs1 = reshape(im,[],size(im,3),size(im,4)) .* uint16(bw1);
    pixels_exterieur1 = reshape(im,[],size(im,3),size(im,4)) .* uint16(~bw1);
    moyennes1 = mean(pixels_actifs1, 1); size(moyennes1)
    sommes1 = sum(pixels_actifs1, 1);
    moyenne_exterieur1 = mean(pixels_exterieur1, 1);
    difference1 = moyennes1 - moyenne_exterieur1;

    % Calcul des valeurs moyennes des N pixels les plus brillants pour tous les instants et tous les canaux pour bw1
    pixels_actifs_sorted1 = sort(pixels_actifs1, 1, 'descend');
    moyenne_brillants1 = mean(pixels_actifs_sorted1(1:N, :, :), 1);
    somme_brillants1 = sum(pixels_actifs_sorted1(1:N, :, :), 1);
end

% Calcul des valeurs moyennes des pixels actifs, des sommes, de la moyenne à l'extérieur du masque et des différences pour tous les instants et tous les canaux pour bw2
if numel(chabw{2})
    pixels_actifs2 = reshape(im,[],size(im,3),size(im,4)) .* uint16(bw2);
    pixels_exterieur2 = reshape(im,[],size(im,3),size(im,4)).* uint16(~bw2);
    moyennes2 = mean(pixels_actifs2, 1);
    sommes2 = sum(pixels_actifs2, 1);
    moyenne_exterieur2 = mean(pixels_exterieur2, 1);
    difference2 = moyennes2 - moyenne_exterieur2;

    % Calcul des valeurs moyennes des N pixels les plus brillants pour tous les instants et tous les canaux pour bw2
    pixels_actifs_sorted2 = sort(pixels_actifs2, 1, 'descend');
    moyenne_brillants2 = mean(pixels_actifs_sorted2(1:N, :, :), 1);
    somme_brillants2 = sum(pixels_actifs_sorted2(1:N, :, :), 1);
end

% Calcul de la valeur moyenne et totale de im pour l'intersection de bw1 et bw2
if numel(chabw{1}) &&  numel(chabw{2})
    pixels_intersection = reshape(im,[],size(im,3),size(im,4)) .* uint16(bw1 & bw2);
    pixels_intersection2 = reshape(im,[],size(im,3),size(im,4)) .* uint16(bw1 & ~bw2);

    if any(pixels_intersection(:))
        moyenne_intersection = mean(pixels_intersection, 1);
        somme_intersection = sum(pixels_intersection, 1);
    else
        moyenne_intersection = zeros(1, size(im, 3), size(im, 4));
        somme_intersection = zeros(1, size(im, 3), size(im, 4));
    end

    if any(pixels_intersection2(:))
        moyenne_intersection2 = mean(pixels_intersection2, 1);
        somme_intersection2 = sum(pixels_intersection2, 1);
    else
        moyenne_intersection2 = zeros(1, size(im, 3), size(im, 4));
        somme_intersection2 = zeros(1, size(im, 3), size(im, 4));
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
    cha=channelsExtract{i};

    bwn=1;
    if numel(chabw{bwn})
        name=[name, ['Mean_' channelsName{i} '_Mask_' paramout.(['mask' num2str(bwn) '_name'])],...
            ['Total_' channelsName{i} '_Mask_' paramout.(['mask' num2str(bwn) '_name'])],...
            ['Mean_Brightest_' channelsName{i} '_Mask_' paramout.(['mask' num2str(bwn) '_name'])],...
            ['Total_Brightest_' channelsName{i} '_Mask_' paramout.(['mask' num2str(bwn) '_name'])],...
            ['Background_' channelsName{i} '_Mask_' paramout.(['mask' num2str(bwn) '_name'])],...
            ['Mean_Minus_Background_' channelsName{i} '_Mask_' paramout.(['mask' num2str(bwn) '_name'])]];
        group=[group {'Mean' 'Total' 'Mean' 'Total' 'Mean' 'Mean'} ];
        defplot=[defplot {true false false false false false}];

        dat1=[dat1 moyennes1(:,cha,:) sommes1(:,cha,:) moyenne_brillants1(:,cha,:),...
            somme_brillants1(:,cha,:) moyenne_exterieur1(:,cha,:) difference1(:,cha,:)];
    end

    bwn=2;
    if numel(chabw{bwn})
        name=[name, ['Mean_' channelsName{i} '_Mask_' paramout.(['mask' num2str(bwn) '_name'])],...
            ['Total_' channelsName{i} '_Mask_' paramout.(['mask' num2str(bwn) '_name'])],...
            ['Mean_Brightest_' channelsName{i} '_Mask_' paramout.(['mask' num2str(bwn) '_name'])],...
            ['Total_Brightest_' channelsName{i} '_Mask_' paramout.(['mask' num2str(bwn) '_name'])],...
            ['Background_' channelsName{i} '_Mask_' paramout.(['mask' num2str(bwn) '_name'])],...
            ['Mean_Minus_Background_' channelsName{i} '_Mask_' paramout.(['mask' num2str(bwn) '_name'])]];
        group=[group {'Mean' 'Total' 'Mean' 'Total' 'Mean' 'Mean'} ];
        defplot=[defplot {true false false false false false}];

        dat2=[dat2 moyennes2(:,cha,:) sommes2(:,cha,:) moyenne_brillants2(:,cha,:),...
            somme_brillants2(:,cha,:) moyenne_exterieur2(:,cha,:) difference2(:,cha,:)];
    end
    
    bwn=1;
    if numel(chabw{1}) &&  numel(chabw{2})
        name=[name, ['Mean_' channelsName{i} '_Mask_1_AND_2'],...
            ['Total_' channelsName{i} '_Mask_1_AND_2'],...
            ['Mean_' channelsName{i} '_Mask_1_AND_NOT_2'],...
            ['Total_' channelsName{i} '_Mask_1_AND_NOT_2']];
        group=[group {'Mean' 'Total' 'Mean' 'Total'} ];
        defplot=[defplot {true false true false}];

        dat3=[dat3 moyenne_intersection(:,cha,:), somme_intersection(:,cha,:),...
            moyenne_intersection2(:,cha,:),somme_intersection2(:,cha,:)];
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

temp=dataseries(dat,name,...
    'groupid','channel_quantification','parentid',roiobj.id,'plot',defplot,'groups',group);

pixdata=find(arrayfun(@(x) strcmp(x.groupid, 'channel_quantification'),roiobj.data)); % find if object exists already

%
if numel(pixdata)
    cc=pixdata(1); % data to be overwritten
else
    n=numel(roiobj.data);
    if n==1 & numel(roiobj.data.data)==0
        cc=1; % replace empty dataset
    else
        cc=numel(roiobj.data)+1;
    end
end


roiobj.data(cc)=temp;
roiobj.data(cc).class="processing";
roiobj.data(cc).plotGroup={[] [] [] [] [] unique(plotgroup)};




