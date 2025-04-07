function score_display(app, mode)
% score_display(app, mode, dataFields)

%% --- Vérification de la ROI et chargement de l'image ---
checkOrCreateImageFigure(app); % to be removed later

if isempty(app.content.ROIList)
    return;
end
selectedROIIndex = find(cell2mat(app.UIROITable.Data(:, 1)), 1);
if isempty(selectedROIIndex)
    return;
end
selectedROI = app.content.ROIList{selectedROIIndex};
if isempty(selectedROI.image)
    selectedROI.load();
end
currentFrame=selectedROI.display.frame;
numFrames = size(selectedROI.image, 4);
if currentFrame < 1 || currentFrame > numFrames
    return;
end

%% build argument list for display

 arg=score_gatherArguments(app,selectedROI);
 opts = score_collectDisplayOptions(arg{:});
 cmap=app.MoviecolormapEditField.Value;
 opts=score_updateLayout(opts,selectedROI,cmap);
 app.layoutOptions=opts;

   if strcmp(mode, 'slow') || ~ishandle(app.displayHandles.Figure)

       if ishandle(app.displayHandles.Figure)
           clf(app.displayHandles.Figure);
       end

[displayHandles, opts]= score_createDisplayHandles(opts,app.ImageFigure);
app.graphicsHandles=score_renderFinalFrame(displayHandles , selectedROI, opts);
app.displayHandles=displayHandles;
   else
 score_updateRender(app.graphicsHandles,selectedROI, opts, app.displayHandles,currentFrame)
   end

% to do : 
% indexed channels, overlayed channel, vector or not, data plotting
% consistency



%% --- Calcul commun de l'image(s) à afficher ---
% Pour overlay : on accumule dans compositeImage (taille originale)
% Pour non-overlay : on sauvegarde chaque canal dans channelImages

% [imgHeight, imgWidth, ~, ~] = size(selectedROI.image);
% 
% 
% if app.OverlayCheckBox.Value
%     compositeImage = zeros(imgHeight, imgWidth, 3);
% else
%     channelImages = {};
% end
% 
% for i = 1:numel(visibleChannels)
%     chIndex = visibleChannels(i);
%     if ~selectedROI.display.selectedchannel(chIndex)
%         continue;
%     end
%     pix = selectedROI.findChannelID(selectedROI.display.channel{chIndex});
%     if numel(pix) == 3
%         % Canal RGB
%         channelImageR = double(selectedROI.image(:, :, pix(1), currentFrame));
%         channelImageG = double(selectedROI.image(:, :, pix(2), currentFrame));
%         channelImageB = double(selectedROI.image(:, :, pix(3), currentFrame));
%         rgbChannelImage = cat(3, channelImageR, channelImageG, channelImageB);
%         if isfield(selectedROI.display, 'displaylim') && ~isempty(selectedROI.display.displaylim) && size(selectedROI.display.displaylim,2) >= chIndex
%             minLevel = 65535 * selectedROI.display.displaylim(1, chIndex);
%             maxLevel = 65535 * selectedROI.display.displaylim(2, chIndex);
%         else
%             minLevel = 0; maxLevel = 65535;
%         end
%         rgbChannelImage = (rgbChannelImage - minLevel) / (maxLevel - minLevel);
%         rgbChannelImage = max(0, min(1, rgbChannelImage));
%         intensity = selectedROI.display.alpha(chIndex);
%         coloredChannel = intensity * rgbChannelImage;
%         % Pour le masque, on prendra par exemple le canal rouge
%         channelForMask = channelImageR;
%     else
%         % Canal monochrome
%         channelImage = double(selectedROI.image(:, :, chIndex, currentFrame));
%         if isfield(selectedROI.display, 'displaylim') && ~isempty(selectedROI.display.displaylim) && size(selectedROI.display.displaylim,2) >= chIndex
%             minLevel = 65535 * selectedROI.display.displaylim(1, chIndex);
%             maxLevel = 65535 * selectedROI.display.displaylim(2, chIndex);
%         else
%             minLevel = 0; maxLevel = 65535;
%         end
%         normChannel = (channelImage - minLevel) / (maxLevel - minLevel);
%         normChannel = max(0, min(1, normChannel));
%         intensity = selectedROI.display.alpha(chIndex);
%         rgbColor = selectedROI.display.rgb(chIndex, :);
%         coloredChannel = zeros(imgHeight, imgWidth, 3);
%         for c = 1:3
%             coloredChannel(:, :, c) = intensity * rgbColor(c) * normChannel;
%         end
%         channelForMask = channelImage;
%     end
% 
%     if app.OverlayCheckBox.Value
%         compositeImage = compositeImage + coloredChannel;
%     else
%         channelImages{end+1} = coloredChannel;
%     end
% end

% %% --- Calcul commun de l'overlay indexé ---
% indexedOverlay = zeros(imgHeight, imgWidth, 3);
% alphaOverlay = zeros(imgHeight, imgWidth);
% noIndexed = 0;
% 
% for l = 1:numel(indexedChannels)
%     noIndexed = noIndexed + selectedROI.display.selectedchannel(indexedChannels(l));
% end
% 
% if app.PaintButton.Value && noIndexed ~= 0
%     selectedRow = app.UIAnnotationTable.Selection;
%     if isempty(selectedRow) || isempty(selectedRow(1))
%         errordlg('No channel selected!');
%         return;
%     else
%         annotationPart = app.UIAnnotationTable.Data{selectedRow(1), 2};
%         classPart = app.UIAnnotationTable.Data{selectedRow(1), 3};
%         fullChannelName = [annotationPart, '_', classPart];
%         channelIdx = find(strcmp(selectedROI.display.channel, fullChannelName), 1);
%         if isempty(channelIdx)
%             errordlg('No channel selected!');
%             return;
%         end
%     end
%     pix = selectedROI.findChannelID(selectedROI.display.channel{channelIdx});
%     annotationImage = double(selectedROI.image(:, :, pix, currentFrame));
%     [imgH2, imgW2] = size(annotationImage);
%     uniqueVals = unique(annotationImage);
%     uniqueVals(uniqueVals == 0) = [];
%     numUnique = numel(uniqueVals);
%     if numUnique > 0
%         cmap = lines(numUnique);
%     else
%         cmap = [1 0 0];
%     end
%     annotationColorImage = zeros(imgH2, imgW2, 3);
%     alphamask = zeros(imgH2, imgW2);
%     for iVal = 1:numUnique
%         val = uniqueVals(iVal);
%         mask = (annotationImage == val);
%         alphamask = alphamask | mask;
%         for c = 1:3
%             annotationColorImage(:, :, c) = annotationColorImage(:, :, c) + mask * cmap(iVal, c);
%         end
%     end
%     annotationColorImage = max(0, min(1, annotationColorImage));
%     if numel(find(alphamask))
%         alphaOverlay(alphamask) = selectedROI.display.alpha(channelIdx);
%     end
%     indexedOverlay = annotationColorImage;
% else
%     for j = 1:numel(indexedChannels)
%         chIndex = indexedChannels(j);
%         if ~selectedROI.display.selectedchannel(chIndex)
%             continue;
%         end
%         pix = selectedROI.findChannelID(selectedROI.display.channel{chIndex});
%         if iscell(pix)
%             channelImage = double(selectedROI.image(:, :, pix{1}, currentFrame));
%         else
%             channelImage = double(selectedROI.image(:, :, pix, currentFrame));
%         end
%         if app.isthedefautcolorCheckBox.Value
%             mask = channelImage > 1;
%         else
%             mask = channelImage >= 1;
%         end
%         uniformColor = selectedROI.display.rgb(chIndex, :);
%         for k = 1:3
%             channelOverlay = indexedOverlay(:, :, k);
%             channelOverlay(mask) = uniformColor(k);
%             indexedOverlay(:, :, k) = channelOverlay;
%         end
%         alphaOverlay(mask) = selectedROI.display.alpha(chIndex);
%     end
% end

% %% --- Création du tiledlayout et affichage final ---
% if app.OverlayCheckBox.Value
%     % Mode overlay : 1 colonne, 1+N lignes
%     %    numDataFields = numel(dataFields);
%     nRows = 1;
%     if strcmp(mode, 'slow')
%         t = tiledlayout(app.ImageFigure, nRows, 1, 'TileSpacing', 'tight', 'Padding', 'tight');
%         t.Tag = 'MyTileLayout';
%     else
%         % En fast, on essaie de récupérer le tiledlayout existant et on le réutilise
%         t = findobj(app.ImageFigure, 'Type', 'tiledlayout', 'Tag', 'MyTileLayout');
%         if isempty(t)
%             t = tiledlayout(app.ImageFigure, nRows, 1, 'TileSpacing', 'tight', 'Padding', 'tight');
%             t.Tag = 'MyTileLayout';
%         else
%             t = t(1);
%             % Ne pas supprimer les enfants pour conserver les axes existants
%         end
%     end
% 
%     % Récupération ou création du premier tile pour l'image composite
%     axImg = nexttile(t, 1);
%     if strcmp(mode, 'slow')
%         h = imshow(compositeImage, 'Parent', axImg, 'InitialMagnification', 'fit');
%         h.Tag = 'CompositeImage';
%         axImg.UserData.CDataHandle = h;
%         hold(axImg, 'on');
%         hOverlay = imshow(indexedOverlay, 'Parent', axImg, 'InitialMagnification', 'fit');
%         hOverlay.Tag = 'IndexedOverlay';
%         set(hOverlay, 'AlphaData', alphaOverlay, 'AlphaDataMapping', 'none');
%         axImg.UserData.OverlayHandle = hOverlay;
%         hold(axImg, 'off');
%     else
%         if isfield(axImg.UserData, 'CDataHandle') && isvalid(axImg.UserData.CDataHandle)
%             try
%                 set(axImg.UserData.CDataHandle, 'CData', compositeImage);
%             catch ME
%                 warning('Erreur lors de la mise à jour du CData : %s. Recréation de l''image.', ME.message);
%                 h = imshow(compositeImage, 'Parent', axImg);
%                 h.Tag = 'CompositeImage';
%                 axImg.UserData.CDataHandle = h;
%             end
%         else
%             h = imshow(compositeImage, 'Parent', axImg);
%             h.Tag = 'CompositeImage';
%             axImg.UserData.CDataHandle = h;
%         end
%         if isfield(axImg.UserData, 'OverlayHandle') && isvalid(axImg.UserData.OverlayHandle)
%             try
%                 set(axImg.UserData.OverlayHandle, 'CData', indexedOverlay, 'AlphaData', alphaOverlay);
%             catch ME
%                 warning('Erreur lors de la mise à jour de l''overlay : %s. Recréation de l''overlay.', ME.message);
%                 hOverlay = imshow(indexedOverlay, 'Parent', axImg);
%                 hOverlay.Tag = 'IndexedOverlay';
%                 set(hOverlay, 'AlphaData', alphaOverlay, 'AlphaDataMapping', 'none');
%                 axImg.UserData.OverlayHandle = hOverlay;
%                 set(hOverlay, 'HitTest', 'off');
%             end
%         else
%             hOverlay = imshow(indexedOverlay, 'Parent', axImg, 'InitialMagnification', 'fit');
%             hOverlay.Tag = 'IndexedOverlay';
%             set(hOverlay, 'AlphaData', alphaOverlay, 'AlphaDataMapping', 'none');
%             axImg.UserData.OverlayHandle = hOverlay;
%         end
%     end
% 
%     % Création ou mise à jour des tiles pour les champs de données
%     % for iField = 1:numDataFields
%     %     axData = nexttile(t, iField+1);
%     %     if strcmp(mode, 'slow')
%     %         plot(axData, dataFields{iField});
%     %     else
%     %         if isfield(axData.UserData, 'PlotHandle') && isvalid(axData.UserData.PlotHandle)
%     %             try
%     %                 set(axData.UserData.PlotHandle, 'YData', dataFields{iField});
%     %             catch ME
%     %                 warning('Erreur lors de la mise à jour du plot : %s. Recréation du plot.', ME.message);
%     %                 hPlot = plot(axData, dataFields{iField});
%     %                 axData.UserData.PlotHandle = hPlot;
%     %             end
%     %         else
%     %             hPlot = plot(axData, dataFields{iField});
%     %             axData.UserData.PlotHandle = hPlot;
%     %         end
%     %     end
%     %     title(axData, ['Champ de données ' num2str(iField)]);
%     % end
% else
%     % Mode non-overlay : idem, mais avec une grille à N colonnes pour les canaux
%     numChannelsDisp = numel(channelImages);
% 
% 
%     nRows = 1;
% 
%     if strcmp(mode, 'slow')
%         t = tiledlayout(app.ImageFigure, nRows, numChannelsDisp, 'TileSpacing', 'none', 'Padding', 'tight');
%         t.Tag = 'MyTileLayout';
%     else
%         t = findobj(app.ImageFigure, 'Type', 'tiledlayout', 'Tag', 'MyTileLayout');
%         if isempty(t)
%             t = tiledlayout(app.ImageFigure, nRows, numChannelsDisp, 'TileSpacing', 'none', 'Padding', 'tight');
%             t.Tag = 'MyTileLayout';
%         else
%             t = t(1);
%             % On garde les enfants existants
%         end
%     end
% 
%     % Première ligne : mise à jour de chaque axe canal et son overlay
%     for iChannel = 1:numChannelsDisp
%         axChan = nexttile(t, iChannel);
%         if strcmp(mode, 'slow')
%             h = imshow(channelImages{iChannel}, 'Parent', axChan, 'InitialMagnification', 'fit');
%             h.Tag = 'ChannelImage';
%             axChan.UserData.CDataHandle = h;
%             hold(axChan, 'on');
%             hOv = imshow(indexedOverlay, 'Parent', axChan, 'InitialMagnification', 'fit');
%             hOv.Tag = 'IndexedOverlay';
%             set(hOv, 'AlphaData', alphaOverlay, 'AlphaDataMapping', 'none');
%             axChan.UserData.OverlayHandle = hOv;
%             hold(axChan, 'off');
%         else
%             if isfield(axChan.UserData, 'CDataHandle') && isvalid(axChan.UserData.CDataHandle)
% 
%                 try
%                     set(axChan.UserData.CDataHandle, 'CData', channelImages{iChannel});
%                 catch ME
%                     warning('Erreur lors de la mise à jour du canal %d : %s. Recréation de l''image.', iChannel, ME.message);
%                     h = imshow(channelImages{iChannel}, 'Parent', axChan);
%                     h.Tag = 'ChannelImage';
%                     axChan.UserData.CDataHandle = h;
%                 end
%             else
%                 h = imshow(channelImages{iChannel}, 'Parent', axChan);
%                 h.Tag = 'ChannelImage';
%                 axChan.UserData.CDataHandle = h;
%             end
%             if isfield(axChan.UserData, 'OverlayHandle') && isvalid(axChan.UserData.OverlayHandle)
%                 try
%                     set(axChan.UserData.OverlayHandle, 'CData', indexedOverlay, 'AlphaData', alphaOverlay);
%                 catch ME
%                     warning('Erreur lors de la mise à jour de l''overlay du canal %d : %s. Recréation de l''overlay.', iChannel, ME.message);
%                     hOv = imshow(indexedOverlay, 'Parent', axChan);
%                     hOv.Tag = 'IndexedOverlay';
%                     set(hOv, 'AlphaData', alphaOverlay, 'AlphaDataMapping', 'none');
%                     axChan.UserData.OverlayHandle = hOv;
%                 end
%             else
%                 hOv = imshow(indexedOverlay, 'Parent', axChan, 'InitialMagnification', 'fit');
%                 hOv.Tag = 'IndexedOverlay';
%                 set(hOv, 'AlphaData', alphaOverlay, 'AlphaDataMapping', 'none');
%                 axChan.UserData.OverlayHandle = hOv;
%             end
%         end
%     end
% 
%     % % Lignes pour les données (si fournies) : chaque champ occupe une tile étendue sur toutes les colonnes
%     % for iField = 1:numDataFields
%     %     axData = nexttile(t, [1, numChannelsDisp]);
%     %     if strcmp(mode, 'slow')
%     %         plot(axData, dataFields{iField});
%     %     else
%     %         if isfield(axData.UserData, 'PlotHandle') && isvalid(axData.UserData.PlotHandle)
%     %             try
%     %                 set(axData.UserData.PlotHandle, 'YData', dataFields{iField});
%     %             catch ME
%     %                 warning('Erreur lors de la mise à jour du plot (non-overlay) : %s. Recréation du plot.', ME.message);
%     %                 hPlot = plot(axData, dataFields{iField});
%     %                 axData.UserData.PlotHandle = hPlot;
%     %             end
%     %         else
%     %             hPlot = plot(axData, dataFields{iField});
%     %             axData.UserData.PlotHandle = hPlot;
%     %         end
%     %     end
%     %     title(axData, ['Champ de données ' num2str(iField)]);
%     % end
% end


%% --- Mises à jour complémentaires ---

% GUI panel update
app.FrameLabel.Text = ['Frame : ' num2str(currentFrame)];
app.ImageFigure.Name = ['Frame ' num2str(selectedROI.display.frame)];

app.updateAssignValueControls(); % this updates the value of the data plotted in the data panel GUI

if isprop(app, 'SelectedObjectRectangle') && ~isempty(app.SelectedObjectRectangle) && isgraphics(app.SelectedObjectRectangle)
    delete(app.SelectedObjectRectangle);
end

% histo update
score_updateHistogram(app, mode);
if app.LineIntensityprofileButton.Value
    score_updateIntensityProfile(app, getPosition(app.LineIntensityProfileLine));
end
if app.ShapeButton.Value
    score_updateEllipticalProfile(app, app.EllipseIntensityProfileObj);
end

% selection = app.UIDataTable.Selection;
% if isempty(selection)
%     return;
% end
% dsIndex = selection(1);
% if ~isprop(selectedROI, 'data') || numel(selectedROI.data) < dsIndex
%     return;
% end
% selectedROI.data(dsIndex).plotProperties = app.UISubDataTable.Data;
% 
% subData = app.UISubDataTable.Data;
% if ~isempty(subData) && any(cell2mat(subData(:,1)))
%     try
%         selectedTableIndex = find(cell2mat(app.UIDataTable.Data(:,1)));
%         for i = 1:numel(selectedROI.data)
%             h = findobj('Tag', selectedROI.data(i).id);
%             if ~isempty(h)
%                 if isempty(find(selectedTableIndex == i, 1))
%                     delete(h);
%                 end
%             end
%             if ~isempty(find(selectedTableIndex == i, 1))
%                 app.DataFigure(i) = selectedROI.data(i).plot();
%             end
%         end
%     catch ME
%         warning('Error when calling plot method: %s', ME.message);
%     end
%     figure(app.displayHandles.Figure);
% end

end

