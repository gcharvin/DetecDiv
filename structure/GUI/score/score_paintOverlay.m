function score_paintOverlay(src, event, app)
% Peinture + sélection + menu contextuel (relabel) sur la figure d'affichage.
% - Clic gauche : peindre (gomme avec Shift/Ctrl)
% - Double-clic : sélectionner objet + bbox + attacher menu
% - Clic droit à l'intérieur de la bbox : menu contextuel (2 options)
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
fullChannelName = [annotationPart, '_', classPart];
channelIdx = find(strcmp(roi.display.channel, fullChannelName), 1);
if isempty(channelIdx), disp('Selected annotation channel not found'); return; end
pix = roi.findChannelID(roi.display.channel{channelIdx});
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
        % s'assurer que le dataseries existe
        ensureCellInformationDataseries(roi);
        setLineageChannel(roi, fullChannelName, pix, annotationPart);

        daughterID = int32(app.SelectedObjectLabelCell);
        labAt      = currentMask(yinit,xinit);

        if labAt > 0 && labAt ~= daughterID
            setCellMother(roi, daughterID, double(labAt), 'birthFrame', frm);
            flashStatus(app, sprintf('Mère de #%d → #%d (frame %d)', daughterID, labAt, frm));
        else
            removeCellMother(roi, daughterID);
            flashStatus(app, sprintf('Mère retirée pour #%d', daughterID));
        end
        refreshLineageAfterEdit(app, roi, frm);
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
    displaySelectedObject(app, roi, channelIdx, pix, frm, axOverlay, hOverlayImg, xinit, yinit);
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

src.WindowButtonMotionFcn = @wbmcb;
src.WindowButtonUpFcn     = @wbucb;

    function wbmcb(~, ~)
        % re-force le curseur à chaque mouvement
        src.Pointer = 'cross';

        cpMotion = get(axOverlay,'CurrentPoint');
        x = round(cpMotion(1,1));
        y = round(cpMotion(1,2));

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
        paintColor_locked = label2color(paintValue_locked);   % mapping stable
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

        drawnow;
    end

  function wbucb(~, ~)
    src.Pointer = 'arrow';
    src.WindowButtonMotionFcn = '';
    src.WindowButtonUpFcn     = '';
    if exist('iptPointerManager','file')==2, iptPointerManager(src,'enable'); end
    % --- NEW: fin de trait -> on libère l'ID/couleur verrouillés
    paintValue_locked = [];
    paintColor_locked = [];
    drawnow;
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


app.SelectedobjectindexEditField.Value = 0;
app.SelectedObjectLabelCell  = NaN;
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

function displaySelectedObject(app, roi, channelIdx, pix, frm, axOverlay, hOverlayImg, xinit, yinit)
currentMask = roi.image(:,:,pix,frm);

[H,W] = size(currentMask);
if xinit<1 || xinit>W || yinit<1 || yinit>H
    app.SelectedobjectindexEditField.Value = 0; return;
end
objLabel = currentMask(yinit,xinit);
if objLabel==0
    app.SelectedobjectindexEditField.Value = 0; return;
end

% Mémos sélection
app.SelectedobjectindexEditField.Value = double(objLabel);
app.SelectedObjectLabelCell  = double(objLabel);
app.SelectedObjectChannelIdx = channelIdx;
app.SelectedObjectRoiId      = string(roi.id);
app.KeepSelection            = true;

% image title
str='';
if ~isnan(app.SelectedObjectLabelCell)
    str=' - Selected cell: ';
    str=[str num2str(app.SelectedObjectLabelCell)];
end
tmp=['ROI:' char(app.SelectedObjectRoiId) ' -  Frame: ' num2str(frm) '/' num2str(size(roi.image,4)) str];
app.ImageFigure.Name = tmp;


% Surbrillance de la composante cliquée (optionnel)
[L,nlab] = bwlabel(currentMask==objLabel);
colo = label2color(objLabel);

for j=1:nlab
    bwc = (L==j);
    if bwc(yinit,xinit)
        filled = imfill(bwc,'holes');
        yRange = 1:size(filled,1); xRange = 1:size(filled,2);
        for c=1:3
            hOverlayImg.CData(yRange,xRange,c) = ...
                hOverlayImg.CData(yRange,xRange,c).*double(~filled) + double(filled)*colo(c);
        end
        hOverlayImg.AlphaData(yRange,xRange) = ...
            hOverlayImg.AlphaData(yRange,xRange).*double(~filled) + double(filled)*app.Transparency.Value;
        roi.image(yRange,xRange,pix,frm) = ...
            uint16(~filled).*roi.image(yRange,xRange,pix,frm) + uint16(filled)*objLabel;
        break
    end
end

% Bbox + rectangle
stats = regionprops(currentMask==objLabel,'BoundingBox');
if isempty(stats), return; end
bb = stats(1).BoundingBox;

if isprop(app,'SelectedObjectRectangle') && ~isempty(app.SelectedObjectRectangle) && isgraphics(app.SelectedObjectRectangle)
    delete(app.SelectedObjectRectangle);
end
app.SelectedObjectRectangle = rectangle(axOverlay, 'Position', bb, ...
    'EdgeColor','w','LineWidth',2,'LineStyle','--', ...
    'HitTest','on','PickableParts','all');  % capter les clics

% Attacher le menu (2 entrées) sur rect + overlay
cm = buildDisplayContextMenu(app.ImageFigure, app, roi, channelIdx, pix, frm);
app.SelectedObjectRectangle.UIContextMenu = cm;


%h = getOverlayImageHandle(app);
%if ~isempty(h) && isgraphics(h), h.UIContextMenu = cm; end
drawnow;
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
% Menu local à la figure (2 choix : frame only / all frames)
old = findall(fig,'Type','uicontextmenu','Tag','DisplayContextMenu');
if ~isempty(old), delete(old); end
cm = uicontextmenu(fig,'Tag','DisplayContextMenu');
uimenu(cm,'Text','Relabel (current frame)...', ...
    'MenuSelectedFcn', @(~,~) openRelabelDialog(app, roi, chIdx, pix, frm, 'frame-only'));
uimenu(cm,'Text','Relabel (this frame --> last appearance)...', ...
    'MenuSelectedFcn', @(~,~) openRelabelDialog(app, roi, chIdx, pix, frm, 'to-last'));
uimenu(cm,'Text','Relabel (all frames)...', ...
    'MenuSelectedFcn', @(~,~) openRelabelDialog(app, roi, chIdx, pix, frm, 'all-frames'));
uimenu(cm,'Separator','on','Text','Split object (watershed)', ...
    'MenuSelectedFcn', @(~,~) splitSelectedObjectWatershed(app, roi, chIdx, pix, frm));
% --- Delete actions ---
uimenu(cm,'Separator','on','Text','Delete object (this frame)', ...
    'MenuSelectedFcn', @(~,~) deleteSelectedObjectFrame(app, roi, pix, frm));
uimenu(cm,'Text','Delete object (all frames)', ...
    'MenuSelectedFcn', @(~,~) deleteSelectedObjectAllFrames(app, roi, pix,frm));

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
d = dialog('Name','Relabel object', ...
    'Position',[100 100 dlgW dlgH], 'WindowStyle','modal');

uicontrol('Parent',d,'Style','text', ...
    'String',sprintf('Object #%d   |   Channel: %s', oldLab, chName), ...
    'FontWeight','bold','HorizontalAlignment','left', ...
    'Position',[12 dlgH-40 dlgW-24 22]);

uicontrol('Parent',d,'Style','text','String','New ID:', ...
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

        % --- Application selon scope
        switch mode
            case 'frame-only'
                relabelOneFrame(roi, pix, frm, oldLab, newLab, action);
            case 'to-last'
                relabelFromFrameToLast(roi, pix, frm, oldLab, newLab, action);
            case 'all-frames'
                relabelAllFrames(roi, pix, oldLab, newLab, action);
        end

        % --- Update sélection + refresh
        app.SelectedObjectLabelCell = newLab;
        score_display(app,'fast');
        delete(d);
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


function splitSelectedObjectWatershed(app, roi, chIdx, pix, frm)
% Split the currently selected object on THIS frame using watershed.
% Keep old ID for the best-matching component; give new IDs to others.

oldLab = app.SelectedObjectLabelCell;
if isempty(oldLab) || isnan(oldLab) || oldLab<=0
    warndlg('No object is currently selected.','Split object'); return;
end

M = roi.image(:,:,pix,frm);
origMask = (M == oldLab);
if ~any(origMask(:))
    warndlg('Selected object is not present on this frame.','Split object'); return;
end

% --- Watershed split using your legacy pipeline ---
% Params you can tune:
params.rClose = 2;   % radius for imclose (disk)
params.hMax   = 1;   % h for imhmax (plateau suppression)
params.conn   = 8;   % connectivity

[Lsplit, nComp] = watershedSplitMaskLegacy(origMask, params);

if nComp <= 1
    warndlg('Nothing to split: this object forms a single component.','Split object');
    return;
end

% --- Choose which component keeps the old ID (max IoU => largest area)
S = regionprops(Lsplit,'Area'); areas = [S.Area];
[~, keepIdx] = max(areas);  % IoU(comp, orig) = area(comp)/area(orig) -> same argmax

% --- Relabel in the mask image: old label cleared, kept gets old ID, others new IDs
M(M==oldLab) = 0;
nextID = double(max(M(:))) + 1;

for k = 1:nComp
    if k == keepIdx
        M(Lsplit == k) = oldLab;    % keep original id
    else
        M(Lsplit == k) = nextID;    % assign fresh id
        nextID = nextID + 1;
    end
end

roi.image(:,:,pix,frm) = M;

% Keep selection on the kept component and refresh
app.SelectedObjectLabelCell = oldLab;
score_display(app,'fast');
end


function [Lout, nComp] = watershedSplitMaskLegacy(fgMask, params)
% Split a single binary foreground mask into multiple parts using:
%   D = bwdist(~fgMask) -> imclose(D, disk(r)) -> imhmax(D, h) -> watershed(-D)
% Return a labeled image Lout (1..nComp inside fgMask, 0 elsewhere). All DOUBLE.

fgMask = logical(fgMask);
if ~any(fgMask(:))
    Lout = zeros(size(fgMask), 'double');
    nComp = 0;
    return;
end

% Distance inside the foreground
D = bwdist(~fgMask);


% Smoothing and h-minima to control over-segmentation
if params.rClose > 0
    D = imclose(D, strel('disk', params.rClose));
end
if params.hMax > 0
    D = imhmax(D, params.hMax);
end

% Watershed on the negated distance; restrict to foreground
Lws = watershed(-D, params.conn);
Lws(~fgMask) = 0;


% Remap watershed regions to consecutive labels (and ensure connectivity)
vals = unique(Lws);
vals(vals==0) = [];

% Keep everything as DOUBLE to avoid class-mismatch errors
Lout  = zeros(size(Lws), 'double');
nComp = 0;

for i = 1:numel(vals)
    m = (Lws == vals(i));
    if any(m(:))
        % bwlabel returns DOUBLE
        [ci, ni] = bwlabel(m, params.conn);
        if ni > 0
            % Shift labels to continue numbering
            ci(ci>0) = ci(ci>0) + nComp;
            % Accumulate in DOUBLE
            Lout = Lout + ci;
            nComp = nComp + ni;
        end
    end
end

% Safety: keep only inside the original mask
Lout(~fgMask) = 0;
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
try
    if isprop(app,'StatusLabel') && ~isempty(app.StatusLabel) && isgraphics(app.StatusLabel)
        app.StatusLabel.Text = msg;
    else
        disp(msg);
    end
catch
    disp(msg);
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
        if isprop(app, 'DisplayBudPairingCheckBox') && ~isempty(app.DisplayBudPairingCheckBox) && isvalid(app.DisplayBudPairingCheckBox)
            opts.ShowBudPairingOverlay = logical(app.DisplayBudPairingCheckBox.Value);
        end
        if isprop(app, 'DisplayLineageCheckBox') && ~isempty(app.DisplayLineageCheckBox) && isvalid(app.DisplayLineageCheckBox)
            opts.ShowLineageOverlay = logical(app.DisplayLineageCheckBox.Value);
        end
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



