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
[displayHandles, opts]= score_createDisplayHandles(opts,app.ImageFigure);
app.graphicsHandles=score_renderFinalFrame(displayHandles , selectedROI, opts);
app.displayHandles=displayHandles;
   else
 score_updateRender(app.graphicsHandles,selectedROI, opts, app.displayHandles,currentFrame)
   end

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

%profile viewer
end

