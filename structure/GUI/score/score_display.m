function score_display(app, mode)
% score_display(app, mode, dataFields)

%profile on
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
roiId = string(selectedROI.id);

chanToLoad = {};
try
    if isfield(selectedROI.display,'channel') && isfield(selectedROI.display,'selectedchannel')
        allNames = selectedROI.display.channel;
        selMask = logical(selectedROI.display.selectedchannel(:)');
        selMask = selMask(1:min(numel(selMask), numel(allNames)));
        if numel(selMask) < numel(allNames)
            selMask(end+1:numel(allNames)) = true;
        end

        % Prefer current UI channel checkboxes when available.
        try
            if isprop(app,'UIChannelTable') && ~isempty(app.UIChannelTable.Data)
                uiMask = logical(cell2mat(app.UIChannelTable.Data(:,1))');
                nu = min(numel(selMask), numel(uiMask));
                if nu > 0
                    selMask(1:nu) = uiMask(1:nu);
                end
            end
        catch
        end

        n = min(numel(allNames), numel(selMask));
        if n > 0
            keep = find(selMask(1:n));
            if ~isempty(keep)
                chanToLoad = allNames(keep);
            end
        end
    end
catch
    chanToLoad = {};
end

if isempty(chanToLoad)
    if isempty(selectedROI.image)
        fprintf('[score] ROI %s: loading full image (no channel filter).\n', char(roiId));
        selectedROI.load();
    end
else
    missing = chanToLoad;
    if ~isempty(selectedROI.image)
        missing = {};
        cLoaded = size(selectedROI.image,3);
        for ii = 1:numel(chanToLoad)
            name = chanToLoad{ii};
            pix = [];
            try
                pix = selectedROI.findChannelID(name,'exact');
            catch
                try
                    pix = selectedROI.findChannelID(name);
                catch
                    pix = [];
                end
            end
            if isempty(pix) || any(pix > cLoaded)
                missing{end+1} = name; %#ok<AGROW>
            end
        end
    end

    if ~isempty(missing)
        try
            fprintf('[score] ROI %s: loading channel(s): %s\n', char(roiId), strjoin(string(missing), ', '));
            selectedROI.load('Channel', missing, 'Data', false, 'Silent');
        catch
            selectedROI.load('Channel', missing);
        end
    elseif isempty(selectedROI.image)
        fprintf('[score] ROI %s: loading selected channel(s): %s\n', char(roiId), strjoin(string(chanToLoad), ', '));
        selectedROI.load('Channel', chanToLoad);
    end
end

   % <— ajoute cette ligne

currentFrame=selectedROI.display.frame;
numFrames = size(selectedROI.image, 4);
if currentFrame < 1 || currentFrame > numFrames
    return;
end

%% build argument list for display

 arg=score_gatherArguments(app,selectedROI);
 opts = score_collectDisplayOptions(arg{:});
 %cmap=app.MoviecolormapEditField.Value;
 opts=score_updateLayout(opts,selectedROI);

 %opts.paintChannel = app.DisplaySettings.Movie.paintChannel;  % peut être 0, un rang, ou un nom

 

 if numel(opts)==0 % layout returned an error, should quit
            disp('Display is aborted due to layout error!')
            return;
 end

 app.layoutOptions=opts;

 if opts.Nchannel==0
     return
 end

refresh=false; 
if isempty(app.displayHandles)
    refresh=true;
  
else 
    if ~isfield(app.displayHandles,'Figure')
        refresh =true;

    else 
        if ~ishandle(app.displayHandles.Figure)
                refresh=true;
       else
               % clf(app.displayHandles.Figure);
        end
    end
end

if strcmp(mode, 'slow')
 refresh=true;
end


%tmp=app.graphicsHandles.imgHandles
   if refresh
displayHandles= score_createDisplayHandles(opts,app.ImageFigure);

%nexttile([3 3])
%h=gcf
% imshow(rand(100,100),[])
%return;
app.graphicsHandles=score_renderFinalFrame(displayHandles , selectedROI, opts);
app.displayHandles=displayHandles;
   else
 score_updateRender(app.graphicsHandles,selectedROI, opts, app.displayHandles,currentFrame)
   end


   %% draw rectangle around selected cell 
try
    if app.KeepSelection && ~isempty(app.SelectedObjectLabelCell) && ~isnan(app.SelectedObjectLabelCell)
        sel = app.UIAnnotationTable.Selection;
        if ~isempty(sel)
            ann = app.UIAnnotationTable.Data{sel(1),2};
            cls = app.UIAnnotationTable.Data{sel(1),3};
            fullName = [ann '_' cls];
            channelIdx = find(strcmp(selectedROI.display.channel, fullName), 1);
            if ~isempty(channelIdx)
                pix = selectedROI.findChannelID(selectedROI.display.channel{channelIdx});
                redrawSelectedRectangle(app, selectedROI, channelIdx, pix);
            end
        end
    end
catch ME
    warning("Redraw selection failed: %s", ME.message);
end



%% --- Mises à jour complémentaires ---

% GUI panel update
app.FrameEditField_2.Value = currentFrame;

str='';
if ~isnan(app.SelectedObjectLabelCell)
    str=' - Selected cell: ';
    str=[str num2str(app.SelectedObjectLabelCell)];
end
app.ImageFigure.Name = ['ROI:' selectedROI.id ' -  Frame: ' num2str(selectedROI.display.frame) '/' num2str(numFrames) str];


% --- Overlay lineage (fille→mère)
try
    ensureCellInformationDataseries(selectedROI);  % sûr & idempotent
%    score_refreshLineageOverlay(app, selectedROI, opts);
catch ME
    warning("Lineage overlay failed: %s", ME.message);
end


app.updateAssignValueControls(); % this updates the value of the data plotted in the data panel GUI

% if isprop(app, 'SelectedObjectRectangle') && ~isempty(app.SelectedObjectRectangle) && isgraphics(app.SelectedObjectRectangle)
%     delete(app.SelectedObjectRectangle);
% end

% histo update
%if strcmp(mode, 'slow')
if app.DisplaySettings.panels.DisplaysettingsPanel=="on"
try
    score_updateHistogram(app, mode);
catch ME
    warning("score_updateHistogram failed: %s", ME.message);
end
end
%end

if app.DisplaySettings.panels.IntensityQuantificationPanel=="on"
if app.LineIntensityprofileButton.Value
      createIntensityLine(app);
    try
        score_updateIntensityProfile(app, getPosition(app.LineIntensityProfileLine));
    catch ME
        warning("score_updateIntensityProfile failed: %s", ME.message);
    end
end
if app.ShapeButton.Value
    createEllipse(app);
    try
        score_updateEllipticalProfile(app, app.EllipseIntensityProfileObj);
    catch ME
        warning("score_updateEllipticalProfile failed: %s", ME.message);
    end
end
end

%if strcmp(mode, 'slow')
%figure(app.displayHandles.Figure);
%end

aa=groot().CurrentFigure;

if aa.Tag~="ScoreDisplayFigure"
    figure(app.displayHandles.Figure);
end


%profile viewer
end


