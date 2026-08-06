function score_paintOverlay(src, event, app)
% Peinture + sélection + menu contextuel (relabel) sur la figure d'affichage.
% - Clic gauche bref sur un objet : sélectionner
% - Glisser : peindre (gomme avec Shift/Ctrl)
% - Double-clic : sélectionner objet + bbox + attacher menu
% - Clic droit à l'intérieur de la bbox : menu masque, track et lignage
% - Clic gauche en dehors de la bbox : déselection (sans empêcher la peinture)
% - Clic hors image : déselection et on quitte

%% --- Contexte & récupérations ---
seltype = src.SelectionType;  % 'normal' 'alt' 'extend' 'open' (figure classique)

% ROI sélectionnée
if isempty(app.content.ROIList), return; end
selectedROIIndex = find(cell2mat(app.UIROITable.Data(:,1)), 1);
if isempty(selectedROIIndex), return; end
roi = app.content.ROIList{selectedROIIndex};
frm = roi.display.frame;

% Canal d'annotation depuis la table
selectedRow = app.UIAnnotationTable.Selection;
if isempty(selectedRow), disp('No channel is selected; quitting!'); return; end
annotationPart  = app.UIAnnotationTable.Data{selectedRow(1), 2};
classPart       = app.UIAnnotationTable.Data{selectedRow(1), 3};
if isempty(classPart)
    fullChannelName = char(string(annotationPart));
else
    fullChannelName = [char(string(annotationPart)), '_', char(string(classPart))];
end
[providerName, channelIdx, pix] = score_resolveMaskProvider(roi, fullChannelName);
if isempty(channelIdx), disp('Selected mask provider channel not found'); return; end
if isempty(pix) || pix<1, disp('Invalid pix for annotation channel'); return; end

% Masque courant & overlay handles (compatibles containers.Map, struct, cell, array)
currentMask = roi.image(:,:,pix,frm);
axOverlay   = getOverlayAxes(app);
hOverlayImg = getOverlayImageHandle(app);


if isempty(axOverlay) || isempty(hOverlayImg) || ~isgraphics(hOverlayImg)
    disp('No overlay handle found'); return;
end

% Si un ID est sélectionné mais que l'objet n'est pas présent sur cette frame,
% on garde l'ID (pour pouvoir l'utiliser en peinture) et on cache juste le visuel.
if hasSelectedObject(app, roi) && ~selectionPresentOnFrame(app, roi, pix, frm)
    hideSelectionVisual(app);
end


% Position souris (coords axes)
cp    = get(axOverlay,'CurrentPoint');
xinit = round(cp(1,1));
yinit = round(cp(1,2));

mods     = get(src,'CurrentModifier');          % {} ou cellstr

% isShift  = iscell(mods) && any(strcmp(mods,'shift'))
% isCtrl   = iscell(mods) && any(strcmp(mods,'control'))
% isAltKey = iscell(mods) && any(strcmp(mods,'alt'))   % touche Alt clavier (rarement utile)


%% --- Déselection si clic hors image (mais PAS si pixel==0 : on veut peindre) ---
if any(strcmp(seltype,{'normal','alt','extend'}))
    isOut = xinit < 1 || yinit < 1 || ...
        xinit > size(currentMask,2) || yinit > size(currentMask,1);
    if isOut
        safeClearSelection(app,roi,frm);
        return;
    end
end

% --- CTRL + clic gauche (MATLAB => seltype='alt') ---
if strcmp(seltype,'alt') && hasSelectedObject(app, roi)
    mods   = get(src,'CurrentModifier');
    isCtrl = iscell(mods) && any(strcmp(mods,'control'));
    if isCtrl
        oldPointer = src.Pointer;
        src.Pointer = 'watch';
        pointerCleanup = onCleanup(@() restoreFigurePointer(src, oldPointer)); %#ok<NASGU>
        flashStatus(app, 'Assigning parent track...');
        drawnow nocallbacks;
        try
        daughterID = int32(app.SelectedObjectLabelCell);
        labAt      = currentMask(yinit,xinit);
        [model, modelStatus] = score_getCellModel(roi);
        cfg = score_getObjectDisplayConfig(roi, fullChannelName);
        [~, familyId] = score_resolveCellModelFamily(model, cfg, fullChannelName);
        if strcmp(modelStatus, 'ok') && ~isempty(familyId)
            child = cellModel.findInstance(model, familyId, frm, daughterID);
            parent = [];
            if labAt > 0 && labAt ~= daughterID
                parent = cellModel.findInstance(model, familyId, frm, labAt);
            end
            if isempty(child) || (labAt > 0 && labAt ~= daughterID && isempty(parent))
                [model, ~] = cellModel.syncFrame(model, familyId, frm, currentMask, ...
                    'TrackPolicy', 'preserve_or_label');
            end
            if labAt > 0 && labAt ~= daughterID
                [model, report] = cellModel.setParent( ...
                    model, familyId, frm, daughterID, labAt, ...
                    'Fast', true, 'Toggle', true);
            else
                [model, report] = cellModel.setParent( ...
                    model, familyId, frm, daughterID, [], 'Fast', true);
            end
            roi.cellModel = model;
            syncLineageDisplayBindingAfterEdit(app);
            if strcmp(report.status, 'set')
                flashStatus(app, sprintf( ...
                    'Track %u parent = Track %u  OK (unsaved)', ...
                    report.child_track_id, report.parent_track_id));
            else
                flashStatus(app, sprintf( ...
                    'Parent removed from Track %u  OK (unsaved)', ...
                    report.child_track_id));
            end
        else
            % Backward-compatible editing for ROIs not migrated yet.
            ensureCellInformationDataseries(roi);
            setLineageChannel(roi, providerName, pix, annotationPart);
            if labAt > 0 && labAt ~= daughterID
                setCellMother(roi, daughterID, double(labAt), 'birthFrame', frm);
                flashStatus(app, sprintf('Mère de #%d → #%d (frame %d)', daughterID, labAt, frm));
            else
                removeCellMother(roi, daughterID);
                flashStatus(app, sprintf('Mère retirée pour #%d', daughterID));
            end
        end
        refreshLineageAfterEdit(app, roi, frm);
        app.notifyAnnotationChanged('lineage', frm, 'Save', false);
        catch ME
            flashStatus(app, ['Parent assignment failed: ' ME.message]);
            errordlg(ME.message, 'Assign parent track');
        end
        return;
    end
end

%% --- Double-clic : sélectionner l'objet + bbox + attacher menu ---
%% --- Double-clic : toggle sélection (si déjà sélectionné) ou sélectionner
if strcmp(seltype,'open')
    % Si une sélection existe et que le double-clic est DANS la bbox courante,
    % on déselectionne (toggle)
    % if isgraphics(app.SelectedObjectRectangle)
    %     bb = app.SelectedObjectRectangle.Position;  % [x y w h]
    %     if pointInBBox(xinit, yinit, bb)
    %         safeClearSelection(app, roi, frm);
    %         drawnow;
    %         return;
    %     end
    % end
    % Sinon on sélectionne l'objet sous le curseur
    displaySelectedObject(app, roi, channelIdx, pix, frm, axOverlay, xinit, yinit);
    return;
end

%% --- Déselection si clic gauche en dehors de la bbox (mais dans l'image) ---
if strcmp(seltype,'normal') & isgraphics(app.SelectedObjectRectangle)
    bb = app.SelectedObjectRectangle.Position;
    inBox = pointInBBox(xinit, yinit, bb);
    if ~inBox
        % enlève juste le visuel/état; on NE return PAS pour laisser peindre
        safeClearSelection(app,roi,frm);
    end
end

%% --- Peinture (left / middle / right, shift+left erases) ---
if ~(strcmp(seltype,'normal') || strcmp(seltype,'extend') || strcmp(seltype,'alt'))
    return;
end

src.Pointer = 'cross';
if exist('iptPointerManager','file')==2, iptPointerManager(src,'disable'); end

paintValue_locked = [];
paintColor_locked = [];
hasPainted = false;
dragThreshold = 4; % Screen pixels; ignore jitter during a click/double-click.
try
    dragStartPoint = double(src.CurrentPoint(1,1:2));
catch
    dragStartPoint = [xinit yinit];
end

src.WindowButtonMotionFcn = @wbmcb;
src.WindowButtonUpFcn     = @wbucb;

    function wbmcb(~, ~)
        % re-force le curseur à chaque mouvement
        src.Pointer = 'cross';

        cpMotion = get(axOverlay,'CurrentPoint');
        x = round(cpMotion(1,1));
        y = round(cpMotion(1,2));

        % A click often produces motion events. Painting starts only after
        % a deliberate drag so the first click of a double-click is safe.
        if ~hasPainted
            try
                dragPoint = double(src.CurrentPoint(1,1:2));
            catch
                dragPoint = [x y];
            end
            if hypot(dragPoint(1)-dragStartPoint(1), ...
                    dragPoint(2)-dragStartPoint(2)) < dragThreshold
                return;
            end
        end
        hasPainted = true;

        % Modifiers robustes
        mods = get(src,'CurrentModifier');         % {} ou cellstr
        isShift   = iscell(mods) && any(strcmp(mods,'shift'));


        brushSettings = getBrushSettings(app);
        % Taille/Mode pinceau
        if isShift
            brushRadius = brushSettings.eraserRadius;
        elseif strcmp(seltype,'extend')
            brushRadius = brushSettings.middleRadius;
        elseif strcmp(seltype,'alt')
            brushRadius = brushSettings.rightRadius;
        else
            brushRadius = brushSettings.leftRadius;
        end

        brushMask = createDiskBrush(brushRadius);
        [maskH, maskW] = size(brushMask);
        halfH = floor(maskH/2); halfW = floor(maskW/2);

        % Zone d'application dans l'image overlay
        [imgH,imgW,~] = size(get(hOverlayImg,'CData'));
        xRange = max(1, x-halfW) : min(imgW, x+halfW);
        yRange = max(1, y-halfH) : min(imgH, y+halfH);

        % Ajustement bords
        cropXStart = 1 + max(0, halfW+1 - x);
        cropXEnd   = maskW - max(0, x+halfW - imgW);
        cropYStart = 1 + max(0, halfH+1 - y);
        cropYEnd   = maskH - max(0, y+halfH - imgH);
        croppedBrush = brushMask(cropYStart:cropYEnd, cropXStart:cropXEnd);

        % Fenêtre correcte ?
        if yinit>size(currentMask,1) || xinit>size(currentMask,2)
            disp('Painting on the wrong display window'); return;
        end

 % ================== init du trait ==================
if isempty(paintValue_locked)
    if isShift
        paintValue_locked = 0;            % gomme
        paintColor_locked = [0 0 0];
    else
        if currentMask(yinit,xinit)==0
            % NOUVELLE RÈGLE : si un objet est sélectionné (même absent ici)
            % et qu'on peint sur le même canal, réutiliser son ID.
            if hasSelectedObject(app, roi) && app.SelectedObjectChannelIdx == channelIdx
                paintValue_locked = app.SelectedObjectLabelCell;
            else
                paintValue_locked = nextGlobalFreeLabel(roi, pix);  % fallback global
            end
        else
            paintValue_locked = currentMask(yinit,xinit);
        end
        paintColor_locked = selectedIdentityColor(app, paintValue_locked);
    end
end

% Valeurs pour CE mouvement :
paintValue = paintValue_locked;
paintColor = paintColor_locked;

% gomme temporaire si Shift+left maintenu
if isShift
    paintValue = 0;
    paintColor = [0 0 0];
end
% ===================================================


        % Peindre overlay (RGB + alpha)
        for c = 1:3
            hOverlayImg.CData(yRange,xRange,c) = ...
                hOverlayImg.CData(yRange,xRange,c).*double(~croppedBrush) + ...
                double(croppedBrush)*paintColor(c);
        end
        hOverlayImg.AlphaData(yRange,xRange) = ...
            hOverlayImg.AlphaData(yRange,xRange).*double(~croppedBrush) + ...
            double(croppedBrush)*app.Transparency.Value;

        % Peindre dans le masque GT
        roi.image(yRange,xRange,pix,frm) = ...
            uint16(~croppedBrush).*roi.image(yRange,xRange,pix,frm) + ...
            uint16(croppedBrush)*paintValue;

        drawnow limitrate nocallbacks;
    end

  function wbucb(~, ~)
    src.Pointer = 'arrow';
    src.WindowButtonMotionFcn = '';
    src.WindowButtonUpFcn     = '';
    if exist('iptPointerManager','file')==2, iptPointerManager(src,'enable'); end
    % --- NEW: fin de trait -> on libère l'ID/couleur verrouillés
    % A short left click selects the object. This also makes the legacy
    % double-click responsive without letting its first click paint.
    if ~hasPainted
        if strcmp(seltype,'normal') && currentMask(yinit,xinit) ~= 0
            displaySelectedObject(app, roi, channelIdx, pix, frm, ...
                axOverlay, xinit, yinit);
            drawnow limitrate nocallbacks;
        end
        return;
    end

    paintValue_locked = [];
    paintColor_locked = [];
    try
        score_syncCellModelFrame(roi, fullChannelName, frm, 'Save', false);
        score_updateSelectedObjectFields(app);
        app.notifyAnnotationChanged(fullChannelName, frm, 'Save', false);
    catch ME
        warning('score:CellModelMaskSync', ...
            'Could not synchronize the cellular model after painting: %s', ME.message);
    end
    drawnow limitrate nocallbacks;
end

end

%% ===== Helpers =====
function ok = hasActiveSelection(app, roi)
ok = isprop(app,'SelectedObjectRectangle') && ~isempty(app.SelectedObjectRectangle) && ...
    isgraphics(app.SelectedObjectRectangle) && ...
    ~isempty(app.SelectedObjectLabelCell) && ~isnan(app.SelectedObjectLabelCell) && ...
    (app.SelectedObjectRoiId == string(roi.id));
end

function tf = pointInBBox(x, y, bb)
% bb = [x y w h]
tf = x>=bb(1) && x<=bb(1)+bb(3) && y>=bb(2) && y<=bb(2)+bb(4);
end

function safeClearSelection(app,roi,frm)
if isprop(app,'SelectedObjectRectangle') && ~isempty(app.SelectedObjectRectangle) && isgraphics(app.SelectedObjectRectangle)
    delete(app.SelectedObjectRectangle);
end


tmp=['ROI:' char(app.SelectedObjectRoiId) ' -  Frame: ' num2str(frm) '/' num2str(size(roi.image,4))];
app.ImageFigure.Name = tmp;


app.MasklabelEditField.Value = 0;
app.SelectedObjectLabelCell  = NaN;
try app.SelectedTrackIDCell = NaN; catch, end
score_updateSelectedObjectFields(app);
app.SelectedObjectChannelIdx = NaN;
app.SelectedObjectRoiId      = "";
end

function brush = createDiskBrush(radius)
sz = 2*radius + 1;
[X,Y] = meshgrid(1:sz,1:sz);
center = radius + 1;
brush = ( (X-center).^2 + (Y-center).^2 ) <= radius^2;
end

function brushSettings = getBrushSettings(app)
brushSettings = struct('leftRadius', 7, 'middleRadius', 13, 'rightRadius', 4, 'eraserRadius', 7);

try
    if isprop(app, 'DisplaySettings') && isstruct(app.DisplaySettings) && ...
            isfield(app.DisplaySettings, 'Paint') && isstruct(app.DisplaySettings.Paint)
        brushSettings = localMergeBrushSettings(brushSettings, app.DisplaySettings.Paint);
        return;
    end
catch
end

try
    userprefs = detecdiv_prefs_load();
    if isfield(userprefs, 'painting_left_brush_radius')
        brushSettings.leftRadius = userprefs.painting_left_brush_radius;
    elseif isfield(userprefs, 'painting_normal_brush_radius')
        brushSettings.leftRadius = userprefs.painting_normal_brush_radius;
    elseif isfield(userprefs, 'painting_large_brush_size')
        brushSettings.leftRadius = sqrt(double(userprefs.painting_large_brush_size));
    end

    if isfield(userprefs, 'painting_middle_brush_radius')
        brushSettings.middleRadius = userprefs.painting_middle_brush_radius;
    elseif isfield(userprefs, 'painting_huge_brush_radius')
        brushSettings.middleRadius = userprefs.painting_huge_brush_radius;
    elseif isfield(userprefs, 'painting_huge_brush_size')
        brushSettings.middleRadius = sqrt(double(userprefs.painting_huge_brush_size));
    end

    if isfield(userprefs, 'painting_right_brush_radius')
        brushSettings.rightRadius = userprefs.painting_right_brush_radius;
    elseif isfield(userprefs, 'painting_large_brush_radius')
        brushSettings.rightRadius = userprefs.painting_large_brush_radius;
    end

    if isfield(userprefs, 'painting_eraser_brush_radius')
        brushSettings.eraserRadius = userprefs.painting_eraser_brush_radius;
    elseif isfield(userprefs, 'painting_fine_brush_radius')
        brushSettings.eraserRadius = userprefs.painting_fine_brush_radius;
    elseif isfield(userprefs, 'painting_small_brush_size')
        brushSettings.eraserRadius = sqrt(double(userprefs.painting_small_brush_size));
    end
catch
end

brushSettings = localSanitizeBrushSettings(brushSettings);
end

function out = localMergeBrushSettings(out, in)
keys = {'leftRadius', 'middleRadius', 'rightRadius', 'eraserRadius', ...
    'normalRadius', 'fineRadius', 'largeRadius'};
for k = 1:numel(keys)
    if isfield(in, keys{k}) && ~isempty(in.(keys{k}))
        switch keys{k}
            case 'normalRadius'
                out.leftRadius = in.(keys{k});
            case 'fineRadius'
                out.eraserRadius = in.(keys{k});
            case 'largeRadius'
                out.rightRadius = in.(keys{k});
            otherwise
                out.(keys{k}) = in.(keys{k});
        end
    end
end
out = localSanitizeBrushSettings(out);
end

function out = localSanitizeBrushSettings(out)
out.leftRadius = localBrushRadius(out.leftRadius, 7);
out.middleRadius = localBrushRadius(out.middleRadius, 13);
out.rightRadius = localBrushRadius(out.rightRadius, 4);
out.eraserRadius = localBrushRadius(out.eraserRadius, 7);
end

function r = localBrushRadius(value, fallback)
r = fallback;
try
    value = double(value);
    if isfinite(value) && value > 0
        r = min(50, max(1, round(value)));
    end
catch
end
end

function displaySelectedObject(app, roi, channelIdx, pix, frm, axOverlay, xinit, yinit)
currentMask = roi.image(:,:,pix,frm);

[H,W] = size(currentMask);
if xinit<1 || xinit>W || yinit<1 || yinit>H
    app.MasklabelEditField.Value = 0; return;
end
objLabel = currentMask(yinit,xinit);
if objLabel==0
    app.MasklabelEditField.Value = 0; return;
end

% Mémos sélection
app.MasklabelEditField.Value = double(objLabel);
app.SelectedObjectLabelCell  = double(objLabel);
try app.SelectedTrackIDCell = NaN; catch, end
app.SelectedObjectChannelIdx = channelIdx;
app.SelectedObjectRoiId      = string(roi.id);
app.KeepSelection            = true;

% Compute only the clicked connected component. Avoid relabelling and
% rewriting the complete RGB overlay for a selection-only gesture.
bb = clickedComponentBoundingBox(currentMask, objLabel, xinit, yinit);
if isempty(bb), return; end

if isprop(app,'SelectedObjectRectangle') && ~isempty(app.SelectedObjectRectangle) && isgraphics(app.SelectedObjectRectangle)
    delete(app.SelectedObjectRectangle);
end
app.SelectedObjectRectangle = rectangle(axOverlay, 'Position', bb, ...
    'EdgeColor','w','LineWidth',2,'LineStyle','--', ...
    'HitTest','on','PickableParts','all');  % capter les clics

% Render the visual feedback before model lookup/validation and menu work.
drawnow nocallbacks;

% Secondary UI updates may load/validate the cell model. They deliberately
% happen after the rectangle is visible.
score_updateSelectedObjectFields(app);
str = '';
try
    trackId = double(app.SelectedTrackIDCell);
    if isfinite(trackId) && trackId > 0
        str = sprintf(' - Selected track: %u', uint64(trackId));
    else
        str = sprintf(' - Unassigned object (mask %g)', ...
            app.SelectedObjectLabelCell);
    end
catch
end
app.ImageFigure.Name = ['ROI:' char(app.SelectedObjectRoiId) ...
    ' -  Frame: ' num2str(frm) '/' num2str(size(roi.image,4)) str];

% Attacher le menu après le premier rendu.
cm = buildDisplayContextMenu(app.ImageFigure, app, roi, channelIdx, pix, frm);
app.SelectedObjectRectangle.UIContextMenu = cm;
end

function bb = clickedComponentBoundingBox(mask, objLabel, x, y)
% Return the regionprops-compatible bbox of the component under (x,y).
bw = (mask == objLabel);
cc = bwconncomp(bw, 8);
clickedPixel = sub2ind(size(bw), y, x);
componentPixels = [];
for k = 1:cc.NumObjects
    pixels = cc.PixelIdxList{k};
    if any(pixels == clickedPixel)
        componentPixels = pixels;
        break;
    end
end
if isempty(componentPixels)
    bb = [];
    return;
end
[rows, cols] = ind2sub(size(bw), componentPixels);
xMin = min(cols);
xMax = max(cols);
yMin = min(rows);
yMax = max(rows);
bb = [xMin-0.5, yMin-0.5, xMax-xMin+1, yMax-yMin+1];
end

% function onRectMouseDown(srcRect, ~, fig, app, roi, chIdx, pix, frm)
% % Ouvre le menu contextuel quand on clique droit DANS le rectangle
% try
%     st = get(fig,'SelectionType');  % 'normal' 'alt' 'extend' 'open'
% catch
%     st = 'normal';
% end
% if strcmp(st,'alt')
%     % (Re)construit un menu frais pour être sûr que les callbacks ont le bon contexte
%     cm = buildDisplayContextMenu(fig, app, roi, chIdx, pix, frm);
%     % Attache-le au rectangle et affiche-le
%     srcRect.UIContextMenu = cm;
%     set(cm,'Visible','on');  % force l'ouverture immédiate
% end
% end



function cm = buildDisplayContextMenu(fig, app, roi, chIdx, pix, frm)
% Separate pixel-label operations from temporal track-identity operations.
old = findall(fig,'Type','uicontextmenu','Tag','DisplayContextMenu');
if ~isempty(old), delete(old); end
cm = uicontextmenu(fig,'Tag','DisplayContextMenu');
maskMenu = uimenu(cm,'Text','Advanced: frame mask labels');
uimenu(maskMenu,'Text','Renumber on current frame...', ...
    'MenuSelectedFcn', @(~,~) openRelabelDialog(app, roi, chIdx, pix, frm, 'frame-only'));
uimenu(maskMenu,'Text','Renumber from this frame to last appearance...', ...
    'MenuSelectedFcn', @(~,~) openRelabelDialog(app, roi, chIdx, pix, frm, 'to-last'));
uimenu(maskMenu,'Text','Renumber on all appearances...', ...
    'MenuSelectedFcn', @(~,~) openRelabelDialog(app, roi, chIdx, pix, frm, 'all-frames'));
uimenu(cm,'Separator','on','Text','Split object (watershed)', ...
    'MenuSelectedFcn', @(~,~) splitSelectedObjectWatershed(app, roi, chIdx, pix, frm));
uimenu(cm,'Text','SAM31 propagate this track...', ...
    'MenuSelectedFcn', @(~,~) propagateSelectedObjectSam31(app, roi, chIdx, pix, frm));
uimenu(cm,'Text','Repair ID continuity (IoU)...', ...
    'MenuSelectedFcn', @(~,~) repairSelectedObjectContinuityIoU(app, roi, chIdx, pix, frm));
trackMenu = uimenu(cm,'Separator','on','Text','Track identity');
uimenu(trackMenu,'Text','Assign on current frame...', ...
    'MenuSelectedFcn', @(~,~) openAssignTrackDialog(app, 'frame'));
uimenu(trackMenu,'Text','Start/reassign track from this frame onward...', ...
    'MenuSelectedFcn', @(~,~) openAssignTrackDialog(app, 'to-last'));
uimenu(trackMenu,'Text','Assign on all appearances...', ...
    'MenuSelectedFcn', @(~,~) openAssignTrackDialog(app, 'all'));
uimenu(cm,'Separator','on','Text','Lineage: set parent track...', ...
    'MenuSelectedFcn', @(~,~) openSetParentTrackDialog(app));
uimenu(cm,'Text','Lineage: remove parent', ...
    'MenuSelectedFcn', @(~,~) removeSelectedParentTrack(app));
% --- Delete actions ---
uimenu(cm,'Separator','on','Text','Delete object (this frame)', ...
    'MenuSelectedFcn', @(~,~) deleteSelectedObjectFrame(app, roi, pix, frm));
uimenu(cm,'Text','Delete object (all frames)', ...
    'MenuSelectedFcn', @(~,~) deleteSelectedObjectAllFrames(app, roi, pix,frm));

end

function openAssignTrackDialog(app, scope)
suggestedTrack = nextFreeTrackIdForSelection(app);
answer = inputdlg( ...
    {'Destination track ID (first unused ID suggested):'}, ...
    sprintf('Assign selected object to a track (%s)', scope), ...
    [1 54], {num2str(suggestedTrack)});
if isempty(answer), return; end
newTrack = str2double(answer{1});
if ~isfinite(newTrack) || newTrack < 1 || newTrack ~= round(newTrack)
    warndlg('Track ID must be a positive integer.', 'Assign track');
    return;
end
try
    report = score_assignSelectedTrack(app, newTrack, scope);
    flashStatus(app, sprintf('Track %u -> %u (%s, %d frame(s))', ...
        report.old_track_id, report.new_track_id, report.scope, ...
        numel(report.frames)));
catch ME
    if strcmp(ME.identifier, 'cellModel:TrackFrameConflict')
        resolveTrackAssignmentConflict(app, newTrack, ME.message);
    else
        errordlg(ME.message, 'Assign track');
    end
end
end

function resolveTrackAssignmentConflict(app, destinationTrack, conflictMessage)
currentTrack = NaN;
try
    currentTrack = str2double(char(string(app.SelectedTrackIDEditField.Value)));
catch
end
if ~isfinite(currentTrack)
    currentText = 'the selected track';
else
    currentText = sprintf('track %d', currentTrack);
end
message = sprintf([ ...
    '%s\n\nA track can contain only one object per frame. ' ...
    'You can exchange the two COMPLETE track identities (including lineage references), ' ...
    'or cancel and first move the object currently occupying track %d to a free track.'], ...
    conflictMessage, destinationTrack);
choice = questdlg(message, 'Track conflict', ...
    sprintf('Swap %s <-> %d', currentText, destinationTrack), ...
    'Cancel', 'Cancel');
if isempty(choice) || strcmp(choice, 'Cancel')
    return;
end
try
    report = score_swapSelectedTrackIds(app, destinationTrack);
    flashStatus(app, sprintf('Tracks %u and %u swapped (%d frame(s))', ...
        report.track_a, report.track_b, numel(report.frames)));
catch ME
    errordlg(ME.message, 'Swap tracks');
end
end

function nextTrack = nextFreeTrackIdForSelection(app)
nextTrack = 1;
try
    [roiobj, channelName] = score_selectedObjectChannel(app);
    [model, status] = score_getCellModel(roiobj);
    if ~strcmp(status, 'ok')
        return;
    end
    cfg = score_getObjectDisplayConfig(roiobj, channelName);
    [~, familyId] = score_resolveCellModelFamily(model, cfg, channelName);
    if isempty(familyId)
        return;
    end
    nextTrack = double(cellModel.nextTrackId(model, familyId));
catch
    nextTrack = 1;
end
end

function openSetParentTrackDialog(app)
answer = inputdlg({'Parent track ID:'}, ...
    'Set parent of selected track', [1 42], {''});
if isempty(answer), return; end
parentTrack = str2double(answer{1});
if ~isfinite(parentTrack) || parentTrack < 1 || parentTrack ~= round(parentTrack)
    warndlg('Parent track ID must be a positive integer.', 'Set parent');
    return;
end
try
    report = score_setSelectedParentTrack(app, parentTrack);
    flashStatus(app, sprintf('Parent of track %u -> %u', ...
        report.child_track_id, report.parent_track_id));
catch ME
    errordlg(ME.message, 'Set parent');
end
end

function removeSelectedParentTrack(app)
try
    report = score_setSelectedParentTrack(app, []);
    flashStatus(app, sprintf('Parent removed from track %u', ...
        report.child_track_id));
catch ME
    errordlg(ME.message, 'Remove parent');
end
end


function repairSelectedObjectContinuityIoU(app, roi, chIdx, pix, frm)
oldLab = app.SelectedObjectLabelCell;
if isempty(oldLab) || isnan(oldLab) || oldLab <= 0
    warndlg('No object is currently selected.','Repair ID continuity'); return;
end

M = roi.image(:,:,pix,frm);
if ~any(M(:) == oldLab)
    warndlg('Selected object is not present on this frame.','Repair ID continuity'); return;
end

nf = size(roi.image,4);
remaining = nf - frm;
if remaining <= 0
    warndlg('There is no following frame to scan.','Repair ID continuity'); return;
end

chName = roi.display.channel{chIdx};
answer = inputdlg( ...
    {'Forward frames to scan:', 'Minimum IoU:', 'Max consecutive unmatched frames:'}, ...
    sprintf('Repair ID #%d continuity on %s', oldLab, chName), ...
    [1 44], ...
    {num2str(min(50, remaining)), '0.20', '3'});
if isempty(answer)
    return;
end

maxFrames = round(str2double(answer{1}));
minIou = str2double(answer{2});
maxGap = round(str2double(answer{3}));
if ~isfinite(maxFrames) || maxFrames < 1
    warndlg('Frame count must be a positive integer.','Repair ID continuity'); return;
end
if ~isfinite(minIou) || minIou < 0 || minIou > 1
    warndlg('Minimum IoU must be between 0 and 1.','Repair ID continuity'); return;
end
if ~isfinite(maxGap) || maxGap < 0
    warndlg('Max consecutive unmatched frames must be zero or positive.','Repair ID continuity'); return;
end

opts = struct('maxFrames', min(maxFrames, remaining), ...
    'minIou', minIou, ...
    'maxGap', maxGap);
summary = repairIdentityContinuityByIoU(roi, pix, frm, oldLab, opts);
[~, selectedDisplayChannel] = score_selectedObjectChannel(app);
score_syncCellModelFrames(roi, selectedDisplayChannel, ...
    (frm + 1):min(size(roi.image,4), frm + opts.maxFrames));

score_display(app,'fast');
safeClearSelection(app, roi, frm);
if summary.repairedFrames == 0
    msg = sprintf('No ID continuity repair applied for #%d.\nScanned %d frame(s); best IoU seen: %.3f.', ...
        oldLab, summary.scannedFrames, summary.bestIouSeen);
else
    idsText = strjoin(cellstr(string(unique(summary.replacedLabels))), ', ');
    msg = sprintf('Repaired #%d on %d frame(s).\nScanned %d frame(s); replaced ID(s): %s; best IoU: %.3f.', ...
        oldLab, summary.repairedFrames, summary.scannedFrames, idsText, summary.bestIouSeen);
end
helpdlg(msg, 'Repair ID continuity');
end

function summary = repairIdentityContinuityByIoU(roi, pix, frm, oldLab, opts)
nf = size(roi.image,4);
lastFrame = min(nf, frm + opts.maxFrames);
refMask = roi.image(:,:,pix,frm) == oldLab;
gap = 0;
summary = struct('scannedFrames', 0, ...
    'repairedFrames', 0, ...
    'replacedLabels', [], ...
    'bestIouSeen', 0);

for f = (frm + 1):lastFrame
    summary.scannedFrames = summary.scannedFrames + 1;
    M = roi.image(:,:,pix,f);

    if any(M(:) == oldLab)
        refMask = (M == oldLab);
        gap = 0;
        continue;
    end

    [bestLab, bestIou] = bestOverlappingLabelByIoU(M, refMask, oldLab);
    summary.bestIouSeen = max(summary.bestIouSeen, bestIou);
    if bestLab > 0 && bestIou >= opts.minIou
        M(M == bestLab) = oldLab;
        roi.image(:,:,pix,f) = M;
        refMask = (M == oldLab);
        gap = 0;
        summary.repairedFrames = summary.repairedFrames + 1;
        summary.replacedLabels(end+1) = bestLab;
    else
        gap = gap + 1;
        if gap > opts.maxGap
            break;
        end
    end
end
end

function [bestLab, bestIou] = bestOverlappingLabelByIoU(M, refMask, oldLab)
labels = unique(M(:));
labels(labels == 0 | labels == oldLab) = [];
bestLab = 0;
bestIou = 0;
for i = 1:numel(labels)
    lab = labels(i);
    candidate = (M == lab);
    inter = nnz(candidate & refMask);
    if inter == 0
        continue;
    end
    unionCount = nnz(candidate | refMask);
    iou = inter / max(1, unionCount);
    if iou > bestIou
        bestIou = iou;
        bestLab = double(lab);
    end
end
end

function propagateSelectedObjectSam31(app, roi, chIdx, pix, frm)
oldLab = app.SelectedObjectLabelCell;
if isempty(oldLab) || isnan(oldLab) || oldLab <= 0
    warndlg('No object is currently selected.','SAM31 propagation'); return;
end

M = roi.image(:,:,pix,frm);
if ~any(M(:) == oldLab)
    warndlg('Selected object is not present on this frame.','SAM31 propagation'); return;
end

nf = size(roi.image,4);
remaining = nf - frm;
if remaining <= 0
    warndlg('There is no following frame to propagate into.','SAM31 propagation'); return;
end

defaults = defaultSam31PropagationOptions(roi, pix, frm);
defaults = mergeStoredSam31PropagationOptions(app, defaults, remaining);
defaultFrames = min(defaults.maxFrames, remaining);
answer = inputdlg( ...
    {'Following frames to update:', 'Resolution:', 'Object slots:', 'Collision overlap threshold (0-1):', 'Runner (external/session):'}, ...
    'SAM31 propagate selected track', ...
    [1 42], ...
    {num2str(defaultFrames), num2str(defaults.resolution), ...
    num2str(defaults.maxNumObjects), num2str(defaults.collisionThreshold), defaults.runnerMode});
if isempty(answer)
    return;
end

nFrames = round(str2double(answer{1}));
resolution = round(str2double(answer{2}));
maxObjects = round(str2double(answer{3}));
collisionThreshold = str2double(answer{4});
runnerMode = lower(strtrim(char(string(answer{5}))));
if ~isfinite(nFrames) || nFrames < 1
    warndlg('Frame count must be a positive integer.','SAM31 propagation'); return;
end
if ~isfinite(resolution) || resolution < 1
    warndlg('Resolution must be a positive integer.','SAM31 propagation'); return;
end
if ~isfinite(maxObjects) || maxObjects < 1
    warndlg('Object slots must be a positive integer.','SAM31 propagation'); return;
end
if ~isfinite(collisionThreshold) || collisionThreshold < 0 || collisionThreshold > 1
    warndlg('Collision overlap threshold must be between 0 and 1.','SAM31 propagation'); return;
end
if ~any(strcmp(runnerMode, {'external','session'}))
    warndlg('Runner must be either external or session.','SAM31 propagation'); return;
end
nFrames = min(nFrames, remaining);

opts = defaults;
opts.label = double(oldLab);
opts.annotationPix = pix;
opts.annotationChannelName = roi.display.channel{chIdx};
opts.startFrame = frm;
opts.maxFrames = nFrames;
opts.resolution = resolution;
opts.maxNumObjects = maxObjects;
opts.collisionThreshold = collisionThreshold;
opts.runnerMode = runnerMode;
storeSam31PropagationOptions(app, opts);

try
    set(app.ImageFigure, 'Pointer', 'watch');
    drawnow limitrate nocallbacks;
catch
end

try
    result = sam31.propagateTrackCorrection(roi, opts);
catch ME
    try
        set(app.ImageFigure, 'Pointer', 'arrow');
    catch
    end
    errordlg(sprintf('SAM31 propagation failed:\n%s', ME.message), 'SAM31 propagation');
    return;
end

try
    set(app.ImageFigure, 'Pointer', 'arrow');
catch
end

summary = applySam31TrackPropagationResult(roi, pix, oldLab, result, opts);
[~, selectedDisplayChannel] = score_selectedObjectChannel(app);
score_syncCellModelFrames(roi, selectedDisplayChannel, double(result.frames(:).'));
score_display(app,'fast');
safeClearSelection(app, roi, frm);
msg = sprintf('SAM31 propagation applied to %d/%d frames.', ...
    summary.appliedFrames, summary.totalTargetFrames);
if summary.appliedFrames == 0 && summary.emptyCandidateFrames == summary.totalTargetFrames
    msg = sprintf('%s\nSAM31 produced no candidate mask after the seed frame.', msg);
end
if summary.clippedFrames > 0 || summary.skippedFrames > 0
    msg = sprintf('%s\nClipped: %d frame(s). Skipped on collision: %d frame(s).', ...
        msg, summary.clippedFrames, summary.skippedFrames);
end
helpdlg(msg, 'SAM31 propagation');
end

function opts = defaultSam31PropagationOptions(roi, annotationPix, frm)
opts = struct();
opts.backend = 'wsl';
opts.resolution = 560;
opts.maxNumObjects = 120;
opts.minScore = 0;
opts.videoScoreThreshold = 0.40;
opts.videoNewDetThreshold = 0.40;
opts.videoDetNmsThreshold = 0.10;
opts.videoAssocIouThreshold = 0.50;
opts.collisionThreshold = 0.35;
opts.runnerMode = 'external';
opts.inputPix = defaultSam31InputPix(roi, annotationPix);
opts.classif = [];

try
    if isa(roi.parent, 'classi')
        opts.classif = roi.parent;
        opts = mergeSam31ClassifDefaults(opts, roi.parent);
    end
catch
end

try
    if ispc && (~isfield(opts,'backend') || isempty(opts.backend) || strcmpi(string(opts.backend), "local"))
        opts.backend = 'wsl';
    end
catch
end

if isempty(opts.inputPix)
    opts.inputPix = defaultSam31InputPix(roi, annotationPix);
end
opts.startFrame = frm;
end

function opts = mergeStoredSam31PropagationOptions(app, opts, remaining)
stored = struct();
try
    if isprop(app, 'DisplaySettings') && isstruct(app.DisplaySettings) && ...
            isfield(app.DisplaySettings, 'SAM31Propagation') && ...
            isstruct(app.DisplaySettings.SAM31Propagation)
        stored = app.DisplaySettings.SAM31Propagation;
    end
catch
end
try
    userprefs = detecdiv_prefs_load();
    stored = mergeSam31PropagationPrefs(stored, userprefs);
catch
end

opts.maxFrames = min(20, remaining);
opts = copyStoredNumericOption(opts, stored, 'maxFrames');
opts = copyStoredNumericOption(opts, stored, 'resolution');
opts = copyStoredNumericOption(opts, stored, 'maxNumObjects');
opts = copyStoredNumericOption(opts, stored, 'collisionThreshold');
try
    if isfield(stored, 'runnerMode') && ~isempty(stored.runnerMode)
        runnerMode = lower(strtrim(char(string(stored.runnerMode))));
        if any(strcmp(runnerMode, {'external','session'}))
            opts.runnerMode = runnerMode;
        end
    end
catch
end
opts.maxFrames = min(max(1, round(opts.maxFrames)), remaining);
end

function stored = mergeSam31PropagationPrefs(stored, userprefs)
if ~isstruct(stored)
    stored = struct();
end
mapping = { ...
    'sam31_propagation_max_frames', 'maxFrames'; ...
    'sam31_propagation_resolution', 'resolution'; ...
    'sam31_propagation_max_num_objects', 'maxNumObjects'; ...
    'sam31_propagation_collision_threshold', 'collisionThreshold'; ...
    'sam31_propagation_runner_mode', 'runnerMode'};
for i = 1:size(mapping, 1)
    prefName = mapping{i, 1};
    optName = mapping{i, 2};
    try
        if isstruct(userprefs) && isfield(userprefs, prefName) && ~isempty(userprefs.(prefName))
            stored.(optName) = userprefs.(prefName);
        end
    catch
    end
end
end

function opts = copyStoredNumericOption(opts, stored, name)
try
    if isfield(stored, name) && ~isempty(stored.(name))
        value = str2double(char(string(stored.(name))));
        if isfinite(value)
            opts.(name) = value;
        end
    end
catch
end
end

function storeSam31PropagationOptions(app, opts)
stored = struct( ...
    'maxFrames', opts.maxFrames, ...
    'resolution', opts.resolution, ...
    'maxNumObjects', opts.maxNumObjects, ...
    'collisionThreshold', opts.collisionThreshold, ...
    'runnerMode', opts.runnerMode);
try
    if isprop(app, 'DisplaySettings') && isstruct(app.DisplaySettings)
        app.DisplaySettings.SAM31Propagation = stored;
        assignin('base', 'DisplaySettings', app.DisplaySettings);
    end
catch
end
try
    userprefs = detecdiv_prefs_load();
    userprefs.sam31_propagation_max_frames = stored.maxFrames;
    userprefs.sam31_propagation_resolution = stored.resolution;
    userprefs.sam31_propagation_max_num_objects = stored.maxNumObjects;
    userprefs.sam31_propagation_collision_threshold = stored.collisionThreshold;
    userprefs.sam31_propagation_runner_mode = stored.runnerMode;
    detecdiv_prefs_save(userprefs);
catch
end
end

function opts = mergeSam31ClassifDefaults(opts, classif)
sources = {};
try
    if isprop(classif, 'trainingParam') && isstruct(classif.trainingParam)
        sources{end+1} = classif.trainingParam;
    end
catch
end
try
    if isprop(classif, 'executionParam') && isstruct(classif.executionParam)
        sources{end+1} = classif.executionParam;
    end
catch
end
for s = 1:numel(sources)
    src = sources{s};
    opts = copyNumericField(opts, src, 'resolution');
    opts = copyNumericField(opts, src, 'maxNumObjects');
    opts = copyNumericField(opts, src, 'minScore');
    opts = copyNumericField(opts, src, 'videoScoreThreshold');
    opts = copyNumericField(opts, src, 'videoNewDetThreshold');
    opts = copyNumericField(opts, src, 'videoDetNmsThreshold');
    opts = copyNumericField(opts, src, 'videoAssocIouThreshold');
    if isfield(src, 'backend') && ~isempty(src.backend)
        opts.backend = char(string(src.backend));
    end
end
try
    if isprop(classif, 'channelName') && ~isempty(classif.channelName)
        pix = roiChannelFromName(classif.channelName, classif);
        if ~isempty(pix)
            opts.inputPix = pix;
        end
    end
catch
end
end

function opts = copyNumericField(opts, src, name)
try
    if isfield(src, name) && ~isempty(src.(name))
        value = str2double(char(string(src.(name))));
        if isfinite(value)
            opts.(name) = value;
        end
    end
catch
end
end

function pix = roiChannelFromName(channelName, classif)
pix = [];
try
    if isprop(classif, 'roi') && ~isempty(classif.roi)
        r = classif.roi;
        if iscell(r), r = r{1}; end
        names = cellstr(string(channelName));
        for i = 1:numel(names)
            candidate = r.findChannelID(names{i});
            if ~isempty(candidate)
                pix = candidate(1);
                return;
            end
        end
    end
catch
end
end

function pix = defaultSam31InputPix(roi, annotationPix)
pix = [];
try
    if isa(roi.parent, 'classi') && isprop(roi.parent, 'channelName') && ~isempty(roi.parent.channelName)
        names = cellstr(string(roi.parent.channelName));
        for i = 1:numel(names)
            candidate = roi.findChannelID(names{i});
            if ~isempty(candidate)
                pix = candidate(1);
                return;
            end
        end
    end
catch
end

try
    nChannels = size(roi.image,3);
    candidates = setdiff(1:nChannels, annotationPix, 'stable');
    if ~isempty(candidates)
        pix = candidates(1);
    end
catch
end
end

function summary = applySam31TrackPropagationResult(roi, pix, oldLab, result, opts)
frames = double(result.frames(:)');
masks = result.candidateMasks;
if ndims(masks) == 4
    masks = squeeze(masks(:,:,1,:));
end
if ndims(masks) == 2
    masks = reshape(masks, size(masks,1), size(masks,2), 1);
end

summary = struct('totalTargetFrames', 0, 'appliedFrames', 0, ...
    'clippedFrames', 0, 'skippedFrames', 0, 'emptyCandidateFrames', 0);
for k = 1:numel(frames)
    f = frames(k);
    if f <= opts.startFrame || f < 1 || f > size(roi.image,4)
        continue;
    end
    summary.totalTargetFrames = summary.totalTargetFrames + 1;
    candidate = masks(:,:,k) > 0;
    if ~any(candidate(:))
        summary.emptyCandidateFrames = summary.emptyCandidateFrames + 1;
        continue;
    end
    M = roi.image(:,:,pix,f);
    selfMask = (M == oldLab);
    otherMask = (M > 0) & (M ~= oldLab);
    overlap = candidate & otherMask;
    overlapFraction = nnz(overlap) / max(1, nnz(candidate));
    if overlapFraction > opts.collisionThreshold
        summary.skippedFrames = summary.skippedFrames + 1;
        continue;
    end
    if any(overlap(:))
        candidate(overlap) = false;
        summary.clippedFrames = summary.clippedFrames + 1;
    end
    M(selfMask) = 0;
    M(candidate) = oldLab;
    roi.image(:,:,pix,f) = M;
    summary.appliedFrames = summary.appliedFrames + 1;
end
end

function openRelabelDialog(app, roi, chIdx, pix, frm, mode)
% mode: 'frame-only' (default), 'to-last', 'all-frames'
if nargin<6 || isempty(mode), mode = 'frame-only'; end

oldLab = app.SelectedObjectLabelCell;
chName = roi.display.channel{chIdx};

% --- Scope message + bouton selon mode
switch mode
    case 'frame-only'
        scopeMsg = 'Scope: current frame only';
        okText   = 'Apply (this frame)';
    case 'to-last'
        scopeMsg = 'Scope: from current frame to last appearance';
        okText   = 'Apply (to last)';
    case 'all-frames'
        scopeMsg = 'Scope: all frames where the object exists';
        okText   = 'Apply (all frames)';
    otherwise
        scopeMsg = 'Scope: current frame only';
        okText   = 'Apply';
end

% ---- UI (identique, sauf textes) ----
dlgW = 380; dlgH = 170;
d = dialog('Name','Renumber mask object', ...
    'Position',[100 100 dlgW dlgH], 'WindowStyle','modal');

uicontrol('Parent',d,'Style','text', ...
    'String',sprintf('Object #%d   |   Channel: %s', oldLab, chName), ...
    'FontWeight','bold','HorizontalAlignment','left', ...
    'Position',[12 dlgH-40 dlgW-24 22]);

uicontrol('Parent',d,'Style','text','String','New mask ID:', ...
    'HorizontalAlignment','left','Position',[12 dlgH-75 90 20]);

% Suggestion = prochain ID libre GLOBAL, pas oldLab+1
suggestID = nextGlobalFreeLabel(roi, pix);

ef = uicontrol('Parent',d,'Style','edit','String',num2str(suggestID), ...
    'Position',[110 dlgH-78 80 24], 'BackgroundColor',[1 1 1]);

uicontrol('Parent',d,'Style','text','String',scopeMsg, ...
    'HorizontalAlignment','left', 'Position',[12 dlgH-105 dlgW-24 18]);

uicontrol('Parent',d,'Style','pushbutton','String',okText, ...
    'Position',[dlgW-220 12 110 28], 'Callback',@onOK);
uicontrol('Parent',d,'Style','pushbutton','String','Cancel', ...
    'Position',[dlgW-100 12 90 28], 'Callback',@(s,e) delete(d));

set(d,'KeyPressFcn',@keyHandler);

    function keyHandler(~,evt)
        switch lower(evt.Key)
            case {'return','enter'}, onOK();
            case {'escape'}, delete(d);
        end
    end

    function onOK(~,~)
        newLab = str2double(get(ef,'String'));
        if ~isfinite(newLab)
    newLab = nextGlobalFreeLabel(roi, pix);
        end

        if ~isfinite(newLab) || newLab<1 || newLab~=round(newLab)
            beep; warndlg('Please enter a positive integer ID.','Invalid ID'); return;
        end
        newLab = round(newLab);
        if newLab==oldLab, delete(d); return; end

        % --- Vérif conflit dans le SCOPE CHOISI
        existsConflict = newLabelExistsInScope_mode(roi, pix, oldLab, newLab, frm, mode);
        action = 'merge';
        if existsConflict
            resp = questdlg( ...
                sprintf('ID %d already exists in the selected scope.\nDo you want to OVERWRITE (merge) or CORRECT?', newLab), ...
                'ID already exists', 'Overwrite','Correct','Cancel','Correct');
            switch resp
                case 'Correct', warndlg('Choose a non-used ID for this scope.','Correct ID'); return;
                case 'Cancel', delete(d); return;
                case 'Overwrite', action = 'merge';
            end
        end

        % Update structured references before changing authoritative pixels.
        [model, modelStatus] = score_getCellModel(roi);
        modelChanged = false;
        if strcmp(modelStatus, 'ok')
            [~, selectedDisplayChannel] = score_selectedObjectChannel(app);
            cfg = score_getObjectDisplayConfig(roi, selectedDisplayChannel);
            [~, familyId] = score_resolveCellModelFamily( ...
                model, cfg, selectedDisplayChannel);
            if ~isempty(familyId)
                affectedFrames = relabelScopeFrames(roi, pix, frm, oldLab, mode);
                try
                    for affectedFrame = affectedFrames
                        [model, ~] = cellModel.relabelFrame(model, familyId, ...
                            affectedFrame, oldLab, newLab, action);
                    end
                    modelChanged = true;
                catch ME
                    errordlg(sprintf('Cell model relabel failed: %s', ME.message), ...
                        'Relabel object');
                    return;
                end
            end
        end

        reviewFrames = affectedFramesForReview(roi, pix, frm, oldLab, mode);

        % --- Application selon scope
        switch mode
            case 'frame-only'
                relabelOneFrame(roi, pix, frm, oldLab, newLab, action);
            case 'to-last'
                relabelFromFrameToLast(roi, pix, frm, oldLab, newLab, action);
            case 'all-frames'
                relabelAllFrames(roi, pix, oldLab, newLab, action);
        end
        if modelChanged
            roi.saveCellModel(model);
            syncLineageDisplayBindingAfterEdit(app);
        end

        app.notifyAnnotationChanged(chName, reviewFrames);

        % --- Update sélection + refresh
        app.SelectedObjectLabelCell = newLab;
        score_updateSelectedObjectFields(app);
        score_display(app,'fast');
        delete(d);
    end
end

function frames = affectedFramesForReview(roi, pix, frm, oldLab, mode)
frames = relabelScopeFrames(roi, pix, frm, oldLab, mode);
if isempty(frames), frames = frm; end
end

function frames = relabelScopeFrames(roi, pix, frm, oldLab, mode)
switch mode
    case 'frame-only'
        frames = frm;
    case 'to-last'
        lastFrame = frm - 1;
        for f = frm:size(roi.image,4)
            if any(roi.image(:,:,pix,f) == oldLab, 'all')
                lastFrame = f;
            else
                break;
            end
        end
        frames = frm:lastFrame;
    otherwise
        frames = [];
        for f = 1:size(roi.image,4)
            if any(roi.image(:,:,pix,f) == oldLab, 'all')
                frames(end+1) = f; %#ok<AGROW>
            end
        end
end
end


function out = ternary(cond, a, b)
if cond, out = a; else, out = b; end
end

function tf = newLabelExistsInScope_mode(roi, pix, oldLab, newLab, frm, mode)
% True si newLab existe déjà dans le scope demandé
tf = false;
switch mode
    case 'frame-only'
        M = roi.image(:,:,pix,frm);
        tf = any(M(:)==newLab);
        return;

    case 'to-last'
        nf = size(roi.image,4);
        % On parcourt à partir de frm jusqu'à la DERNIÈRE frame où oldLab est présent
        lastF = frm;
        for f = frm:nf
            if any(roi.image(:,:,pix,f)==oldLab,'all')
                lastF = f;
            else
                % Dès que l'objet n'est plus présent, on arrête (continuité)
                break;
            end
        end
        % Vérifie présence de newLab dans cette tranche [frm..lastF]
        for f = frm:lastF
            if any(roi.image(:,:,pix,f)==newLab,'all')
                tf = true; return;
            end
        end
        return;

    case 'all-frames'
        nf = size(roi.image,4);
        for f = 1:nf
            M = roi.image(:,:,pix,f);
            if any(M(:)==oldLab) && any(M(:)==newLab)
                tf = true; return;
            end
        end
        return;
end
end



function relabelFromFrameToLast(roi, pix, frm, oldLab, newLab, action)
% Renumérote de la frame courante jusqu'à la DERNIÈRE frame où oldLab est encore présent
nf = size(roi.image,4);

% Déterminer la dernière frame de présence CONTINUE de oldLab à partir de frm
lastF = frm;
for f = frm:nf
    if any(roi.image(:,:,pix,f)==oldLab,'all')
        lastF = f;
    else
        break; % on arrête à la première absence
    end
end

for f = frm:lastF
    M = roi.image(:,:,pix,f);
    hasOld = any(M(:)==oldLab);
    hasNew = any(M(:)==newLab);
    if ~hasOld && ~hasNew, continue; end
    switch action
        case 'merge'
            if hasOld, M(M==oldLab) = newLab; end
        case 'swap'
            t = max(M(:)) + 1;
            if hasNew, M(M==newLab) = t; end
            if hasOld, M(M==oldLab) = newLab; end
            if any(M(:)==t), M(M==t) = oldLab; end
    end
    roi.image(:,:,pix,f) = M;
end
end


function relabelOneFrame(roi, pix, frm, oldLab, newLab, action)
M = roi.image(:,:,pix,frm);
switch action
    case 'merge'
        M(M==oldLab) = newLab;
    case 'swap'
        t = max(M(:)) + 1;
        if any(M(:)==newLab), M(M==newLab) = t; end
        if any(M(:)==oldLab), M(M==oldLab) = newLab; end
        if any(M(:)==t),      M(M==t)      = oldLab; end
end
roi.image(:,:,pix,frm) = M;
end

function relabelAllFrames(roi, pix, oldLab, newLab, action)
nf = size(roi.image,4);
for f = 1:nf
    M = roi.image(:,:,pix,f);
    if ~any(M(:)==oldLab) && ~any(M(:)==newLab), continue; end
    switch action
        case 'merge'
            if any(M(:)==oldLab), M(M==oldLab) = newLab; end
        case 'swap'
            t = max(M(:)) + 1;
            if any(M(:)==newLab), M(M==newLab) = t; end
            if any(M(:)==oldLab), M(M==oldLab) = newLab; end
            if any(M(:)==t),      M(M==t)      = oldLab; end
    end
    roi.image(:,:,pix,f) = M;
end
end

%% ==== Overlay handle helpers (compatibles containers.Map / cell / struct / array) ====
function h = getOverlayImageHandle(app)
oh = app.graphicsHandles.overlayHandles;
h = [];
if isa(oh,'containers.Map')
    ks = oh.keys;
    if ~isempty(ks)
        h = oh(ks{1});                 % valeur associée à la 1ère clé
        if iscell(h) && ~isempty(h), h = h{1}; end
        if ~isempty(h) && numel(h)>1 && ~iscell(h), h = h(1); end
    end
elseif iscell(oh)
    if ~isempty(oh), h = oh{1}; end
elseif isstruct(oh)
    f = fieldnames(oh);
    if ~isempty(f), h = oh.(f{1}); end
else
    if ~isempty(oh), h = oh(1); end
end
end

function ax = getOverlayAxes(app)
h = getOverlayImageHandle(app);
ax = [];
if ~isempty(h) && isgraphics(h)
    if isa(h,'matlab.graphics.axis.Axes')
        ax = h;
    else
        ax = ancestor(h,'axes');
    end
end
end


function splitSelectedObjectWatershed(app, roi, ~, pix, frm)
% Split disconnected pieces directly; use watershed only for a connected mask.

oldLab = app.SelectedObjectLabelCell;
if isempty(oldLab) || isnan(oldLab) || oldLab<=0
    warndlg('No object is currently selected.','Split object'); return;
end

M = roi.image(:,:,pix,frm);
if ~any(M(:) == oldLab)
    warndlg('Selected object is not present on this frame.','Split object'); return;
end

[M, splitReport] = score_splitMaskObject(M, oldLab, ...
    'UsedLabels', getGlobalUsedLabels(roi, pix));
if ~strcmp(splitReport.status, 'split')
    warndlg('Nothing to split: this object forms a single component.','Split object');
    return;
end

roi.image(:,:,pix,frm) = M;
[~, selectedDisplayChannel] = score_selectedObjectChannel(app);
score_syncCellModelFrames(roi, selectedDisplayChannel, frm);
app.notifyAnnotationChanged(selectedDisplayChannel, frm);

% Keep selection on the kept component and refresh
app.SelectedObjectLabelCell = oldLab;
flashStatus(app, sprintf('Object %d split into %d parts; new ID(s): %s', ...
    oldLab, splitReport.componentCount, ...
    strjoin(cellstr(string(splitReport.newLabels)), ', ')));
score_display(app,'fast');
end

function deleteSelectedObjectFrame(app, roi, pix, frm)
% Delete the selected object on the current frame only.
oldLab = app.SelectedObjectLabelCell;
if isempty(oldLab) || isnan(oldLab) || oldLab<=0
    warndlg('No object is currently selected.','Delete object'); return;
end

resp = questdlg( ...
    sprintf('Delete object #%d on the current frame?', oldLab), ...
    'Confirm deletion', 'Delete','Cancel','Cancel');
if ~strcmp(resp,'Delete'), return; end

M = roi.image(:,:,pix,frm);
if ~any(M(:)==oldLab)
    warndlg('Selected object is not present on this frame.','Delete object');
    return;
end

M(M==oldLab) = 0;                 % remove label on this frame
roi.image(:,:,pix,frm) = M;
[~, selectedDisplayChannel] = score_selectedObjectChannel(app);
score_syncCellModelFrames(roi, selectedDisplayChannel, frm);

% Clear selection + refresh
safeClearSelection(app,roi,frm);
app.KeepSelection = false;
score_display(app,'fast');
end


function deleteSelectedObjectAllFrames(app, roi, pix,frm)
% Delete the selected object on every frame where it exists.
oldLab = app.SelectedObjectLabelCell;
if isempty(oldLab) || isnan(oldLab) || oldLab<=0
    warndlg('No object is currently selected.','Delete object'); return;
end

resp = questdlg( ...
    sprintf('Delete object #%d on ALL frames where it exists?', oldLab), ...
    'Confirm deletion (all frames)', 'Delete','Cancel','Cancel');
if ~strcmp(resp,'Delete'), return; end

nf = size(roi.image,4);
for f = 1:nf
    M = roi.image(:,:,pix,f);
    if any(M(:)==oldLab)
        M(M==oldLab) = 0;         % remove label on this frame
        roi.image(:,:,pix,f) = M;
    end
end
[~, selectedDisplayChannel] = score_selectedObjectChannel(app);
score_syncCellModelFrames(roi, selectedDisplayChannel, 1:nf);

% Clear selection + refresh
safeClearSelection(app,roi,frm);
app.KeepSelection = false;
score_display(app,'fast');
end

function used = getGlobalUsedLabels(roi, pix)
% Ensemble des labels >0 utilisés sur TOUTES les frames de ce canal (pix)
nf = size(roi.image,4);
used = [];
for f = 1:nf
    M = roi.image(:,:,pix,f);
    uv = unique(M); 
    uv(uv==0) = [];
    if ~isempty(uv), used = [used; uv(:)]; end %#ok<AGROW>
end
used = unique(double(used(:))).';  % row, double
end

function nextID = nextGlobalFreeLabel(roi, pix)
% Retourne le plus petit entier positif NON utilisé globalement
used = getGlobalUsedLabels(roi, pix);
if isempty(used)
    nextID = 1;
    return;
end
% Cherche le plus petit "trou" dès 1, sinon max+1
cand = 1;
while ismember(cand, used)
    cand = cand + 1;
end
nextID = cand;
end

function cmap = getPalette(n)
% Palette qualitative de 16 couleurs bien distinctes, sans gris clair.
% Remplacement du gris (0.498,0.498,0.498) par un or vif (1.000,0.835,0.000).

base = [ ...
    0.121 0.466 0.705;  % bleu
    1.000 0.498 0.054;  % orange
    0.172 0.627 0.172;  % vert
    0.839 0.152 0.156;  % rouge
    0.580 0.404 0.741;  % violet
    0.549 0.337 0.294;  % brun
    0.890 0.466 0.760;  % rose
    1.000 0.835 0.000;  % OR vif (remplace le gris)
    0.737 0.741 0.133;  % olive
    0.090 0.745 0.811;  % cyan
    0.650 0.810 0.890;  % bleu clair
    1.000 0.733 0.470;  % orange clair
    0.596 0.874 0.541;  % vert clair
    1.000 0.596 0.588;  % rouge clair
    0.770 0.690 0.835;  % violet clair
    0.900 0.770 0.580]; % beige/tan

if n <= size(base,1)
    cmap = base(1:n,:);
else
    reps = ceil(n/size(base,1));
    cmap = repmat(base, reps, 1);
    cmap = cmap(1:n, :);
end
end


function col = label2color(id)
% map ID entier >0 -> couleur palette 16, stable et déterministe
pal = getPalette(16);
idx = 1 + mod(max(1,round(id))-1, size(pal,1));
col = pal(idx,:);
end

function col = selectedIdentityColor(app, maskLabel)
% Match transient brush feedback to the stable track-colored render.
trackId = NaN;
try trackId = double(app.SelectedTrackIDCell); catch, end
if isfinite(trackId) && trackId > 0
    col = label2color(trackId);
else
    col = label2color(maskLabel);
end
end

function rgb = mask2rgb_stable(L)
% Convertit un masque de labels (uint16/double) en RGB via label2color(id)
L = double(L);
[H,W] = size(L);
rgb = zeros(H,W,3,'double');
ids = unique(L); ids(ids==0) = [];
for id = ids(:)'   % boucle sur labels présents
    c = label2color(id);
    m = (L==id);
    % affectation vectorisée
    rgb(:,:,1) = rgb(:,:,1) + m.*c(1);
    rgb(:,:,2) = rgb(:,:,2) + m.*c(2);
    rgb(:,:,3) = rgb(:,:,3) + m.*c(3);
end
end

function tf = hasSelectedObject(app, roi)
% Vrai si un ID est sélectionné pour cette ROI (même sans rectangle)
tf = isprop(app,'SelectedObjectLabelCell') && ~isempty(app.SelectedObjectLabelCell) && ...
     ~isnan(app.SelectedObjectLabelCell) && app.SelectedObjectLabelCell>0 && ...
     isprop(app,'SelectedObjectRoiId') && (app.SelectedObjectRoiId == string(roi.id)) && ...
     isprop(app,'SelectedObjectChannelIdx') && ~isnan(app.SelectedObjectChannelIdx);
end

function present = selectionPresentOnFrame(app, roi, pix, frm)
lab = app.SelectedObjectLabelCell;
present = ~isempty(lab) && ~isnan(lab) && lab>0 && any(roi.image(:,:,pix,frm)==lab,'all');
end

function hideSelectionVisual(app)
% Supprime juste les éléments UI (rectangle, menus overlay) sans toucher l'ID stocké
if isprop(app,'SelectedObjectRectangle') && ~isempty(app.SelectedObjectRectangle) && isgraphics(app.SelectedObjectRectangle)
    delete(app.SelectedObjectRectangle);
end
h = getOverlayImageHandle(app);
if ~isempty(h) && isgraphics(h)
    try
        set(h,'PickableParts','all');     % l'overlay redevient cliquable
        set(h,'UIContextMenu',[]);        % pas de menu résiduel
    catch
    end %#ok<TRYNC>
end
end



function flashStatus(app, msg)
shown = false;
try
    if isprop(app,'StatusLabel') && ~isempty(app.StatusLabel) && isgraphics(app.StatusLabel)
        app.StatusLabel.Text = msg;
        shown = true;
    elseif isprop(app,'CellModelStatusLabel') && ...
            ~isempty(app.CellModelStatusLabel) && isgraphics(app.CellModelStatusLabel)
        app.CellModelStatusLabel.Text = msg;
        app.CellModelStatusLabel.Tooltip = msg;
        shown = true;
    end
catch
end
if ~shown, disp(msg); end
drawnow limitrate nocallbacks;
end

function restoreFigurePointer(fig, pointer)
try
    if isgraphics(fig), fig.Pointer = pointer; end
catch
end
end

function syncLineageDisplayBindingAfterEdit(app)
% Keep external editors compatible with Score instances opened before the
% public display-sync bridge was added. The subsequent fast overlay refresh
% remains sufficient for those already-running legacy instances.
if ismethod(app, 'syncLineageDisplayAfterEdit')
    app.syncLineageDisplayAfterEdit();
end
end


function refreshLineageAfterEdit(app, roi, frm)
try
    if ~isprop(app, 'graphicsHandles') || isempty(app.graphicsHandles) || ...
            ~isprop(app, 'layoutOptions') || isempty(app.layoutOptions) || ...
            isempty(app.displayHandles)
        score_display(app, 'fast');
        return;
    end

    opts = app.layoutOptions;
    try
        lineageUI = score_lineageDisplayOptions(app);
        opts.ShowBudPairingOverlay = lineageUI.showBudPairing;
        opts.ShowLineageOverlay = lineageUI.showGenealogy;
        opts.BudLinkColor = lineageUI.budLinkColor;
        opts.GenealogyLinkColor = lineageUI.genealogyLinkColor;
    catch
    end
    opts.LineageUseViewport = true;
    app.layoutOptions = opts;

    refreshLineageOverlays(app.graphicsHandles, roi, opts, app.displayHandles, frm);
    drawnow limitrate;
catch ME
    warning('score:LineageEditRefresh', ...
        'Fast lineage refresh failed, falling back to score_display: %s', ME.message);
    score_display(app, 'fast');
end
end

function ds = getCellInfoDataseries(roi)
% Retourne le handle du dataseries groupid='cell_information' (assuré existant)
ensureCellInformationDataseries(roi);
idx = find(arrayfun(@(x) isprop(x,'groupid') && strcmp(x.groupid,'cell_information'), roi.data),1,'first');
ds  = roi.data(idx);
end

function setLineageChannel(roi, channelName, pix, sourceHint)
if nargin < 4 || isempty(sourceHint)
    sourceHint = channelName;
end
activateLineageSourceForChannel(roi, channelName, pix, ...
    'sourceHint', sourceHint, ...
    'exclusive', false);
return;
% Enregistre le canal servant aux labels de lineage
ds = getCellInfoDataseries(roi);
if ~isprop(ds,'userData') || isempty(ds.userData) || ~isstruct(ds.userData)
    ds.userData = struct();
end
% On stocke **les deux**: nom (robuste aux ré-ordres) + pix (fallback rapide)
ds.userData.lineageChannelName = string(channelName);
ds.userData.lineageChannelPix  = double(pix);
if ~isfield(ds.userData, 'lineageSources') || ~isstruct(ds.userData.lineageSources)
    ds.userData.lineageSources = struct();
end
if ~isfield(ds.userData, 'motherOf') || isempty(ds.userData.motherOf)
    ds.userData.motherOf = containers.Map('KeyType','int32','ValueType','double');
end
ds.userData.lineageSources.manual = struct( ...
    'motherOf', ds.userData.motherOf, ...
    'channelName', char(string(channelName)), ...
    'outputName', 'manual', ...
    'sourceClassifierStrid', '', ...
    'displayName', 'manual', ...
    'show', true, ...
    'version', 1, ...
    'mode', 'score_manual_lineage');
ds.userData.activeLineageSource = 'manual';
end



