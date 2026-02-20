function convertPixelClasses(classif, roiid)
% Convert small, unbudded, large classes into no div, div, dead classes
% for training set to test the possibility to automatically detect divisions

% Déterminer la liste des ROI à traiter
if nargin == 1
    list = 1:numel(classif.roi);
else
    list = roiid;
end

% Boucle sur les ROI spécifiés
for i = list
    % Charger l'objet ROI
    roiobj = classif.roi(i);

    if isempty(roiobj.image)
        roiobj.load; % Charger l'image si elle n'est pas déjà chargée
    end

    % Identifier le canal correspondant
    str = classif.strid;
    channels = roiobj.display.channel;
    idx = matches(channels, str);

    if any(idx)
        channel = channels{idx};
    else
        % Si aucun canal correspondant n'est trouvé, passer au suivant
        continue;
    end

    pix=roiobj.findChannelID(channel);
    % Traitement de l'image : binarisation
    im = roiobj.image(:, :, pix, :);
    im(im >= 2) = 2;

    % Mise à jour de l'image dans l'objet ROI
    roiobj.image(:, :, pix, :) = im;

    % Sauvegarder les modifications dans l'objet ROI
    roiobj.save;
end



