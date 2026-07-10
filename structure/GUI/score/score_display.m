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
score_applyDefaultChannelSelection(selectedROI);

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
        fprintf('[score] ROI %s: no selected image channel to load.\n', char(roiId));
    end
else
    if score_loadChannelsForDisplay(selectedROI, chanToLoad)
        fprintf('[score] ROI %s: loaded selected channel(s): %s\n', char(roiId), strjoin(string(chanToLoad), ', '));
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
 syncChannelTableLevels(app, opts, selectedROI);

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

figureState = captureScoreFigureState(app);

%tmp=app.graphicsHandles.imgHandles
   if refresh
displayHandles= score_createDisplayHandles(opts,app.ImageFigure);

%nexttile([3 3])
%h=gcf
% imshow(rand(100,100),[])
%return;
app.graphicsHandles=score_renderFinalFrame(displayHandles , selectedROI, opts);
app.displayHandles=displayHandles;
restoreScoreFigureState(app, figureState);
   else
 try
     score_updateRender(app.graphicsHandles,selectedROI, opts, app.displayHandles,currentFrame)
 catch ME
     if strcmp(ME.identifier, 'score_updateRender:InvalidImageHandle')
         displayHandles = score_createDisplayHandles(opts,app.ImageFigure);
         app.graphicsHandles = score_renderFinalFrame(displayHandles , selectedROI, opts);
         app.displayHandles = displayHandles;
         restoreScoreFigureState(app, figureState);
     else
         rethrow(ME);
     end
 end
   end

score_syncOverlayAxes(app.graphicsHandles);
score_refreshScaleBars(app.graphicsHandles, opts);
try
    app.ImageFigure.SizeChangedFcn = @(~, ~) syncScoreOverlayAndScaleBars(app);
catch
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
    if isprop(app,'PaintButton') && app.PaintButton.Value && ~isempty(app.UIAnnotationTable.Selection)
        sel = app.UIAnnotationTable.Selection;
        ann = app.UIAnnotationTable.Data{sel(1),2};
        cls = app.UIAnnotationTable.Data{sel(1),3};
        lineageChannelName = [ann '_' cls];
        lineageChannelIdx = find(strcmp(selectedROI.display.channel, lineageChannelName), 1);
        if ~isempty(lineageChannelIdx)
            lineagePix = selectedROI.findChannelID(selectedROI.display.channel{lineageChannelIdx});
            if ~isempty(lineagePix) && lineagePix >= 1
                activateLineageSourceForChannel(selectedROI, lineageChannelName, lineagePix, ...
                    'sourceHint', ann, ...
                    'exclusive', false, ...
                    'WriteLegacyAlias', false, ...
                    'CreateIfMissing', false);
            end
        end
    end
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

function state = captureScoreFigureState(app)
state = [];
try
    if ~isprop(app, 'ImageFigure') || isempty(app.ImageFigure) || ...
            ~ishandle(app.ImageFigure) || ~isvalid(app.ImageFigure)
        return;
    end

    fig = app.ImageFigure;
    state.Units = fig.Units;
    fig.Units = 'pixels';
    state.Position = fig.Position;
    state.WindowState = fig.WindowState;
    fig.Units = state.Units;
catch
    state = [];
end
end

function restoreScoreFigureState(app, state)
try
    if isempty(state) || ~isprop(app, 'ImageFigure') || isempty(app.ImageFigure) || ...
            ~ishandle(app.ImageFigure) || ~isvalid(app.ImageFigure)
        return;
    end

    fig = app.ImageFigure;
    oldUnits = fig.Units;
    fig.Units = 'pixels';
    if isfield(state, 'Position') && numel(state.Position) == 4 && all(isfinite(state.Position))
        fig.Position = state.Position;
    end
    if isfield(state, 'WindowState') && strlength(string(state.WindowState)) > 0
        fig.WindowState = state.WindowState;
    end
    fig.Units = oldUnits;
catch
    try
        app.ImageFigure.Units = state.Units;
    catch
    end
end
end

function syncChannelTableLevels(app, opts, selectedROI)
try
    if ~isprop(app, 'UIChannelTable') || isempty(app.UIChannelTable) || isempty(app.UIChannelTable.Data)
        return;
    end
    if ~isfield(opts, 'channel') || ~isfield(opts, 'levels') || isempty(opts.channel)
        return;
    end
    data = app.UIChannelTable.Data;
    if size(data, 2) < 5
        return;
    end
    optNames = opts.channel;
    if isstring(optNames)
        optNames = cellstr(optNames);
    elseif ~iscell(optNames)
        optNames = cellstr(string(optNames(:)));
    end
    for row = 1:size(data, 1)
        rowName = char(string(data{row, 2}));
        hit = find(strcmpi(optNames, rowName), 1, 'first');
        if isempty(hit) || hit > numel(opts.levels)
            continue;
        end
        lev = opts.levels{hit};
        if iscell(lev)
            data{row, 5} = char(string(lev{1}));
        elseif isnumeric(lev) && numel(lev) >= 2
            chIdx = find(strcmpi(selectedROI.display.channel, rowName), 1, 'first');
            if isempty(chIdx)
                displayLevels = lev(1:2);
                unit = 'raw';
            else
                displayLevels = score_decodeChannelValues(selectedROI, chIdx, lev(1:2));
                unit = score_channelDisplayUnit(selectedROI, chIdx);
            end
            if strcmp(unit, 'raw')
                data{row, 5} = sprintf('%.0f %.0f', round(displayLevels(1)), round(displayLevels(2)));
            else
                data{row, 5} = sprintf('%.4g %.4g', displayLevels(1), displayLevels(2));
            end
        end
    end
    app.UIChannelTable.Data = data;
catch ME
    warning("score_display:SyncChannelTableLevelsFailed", ...
        "Could not update display level table: %s", ME.message);
end
end

function syncScoreOverlayAndScaleBars(app)
try
    score_syncOverlayAxes(app.graphicsHandles);
    if isprop(app, 'layoutOptions') && ~isempty(app.layoutOptions)
        score_refreshScaleBars(app.graphicsHandles, app.layoutOptions);
    end
catch
end
end


