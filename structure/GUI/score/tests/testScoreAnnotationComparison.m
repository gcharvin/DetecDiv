function tests = testScoreAnnotationComparison
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))));
addpath(root);
startup;
testCase.TestData.visibility = get(groot,'DefaultFigureVisible');
set(groot,'DefaultFigureVisible','off');
end

function teardownOnce(testCase)
set(groot,'DefaultFigureVisible',testCase.TestData.visibility);
end

function testIndependentRasterMasksAndNavigation(testCase)
for overlay = [false true]
    [r, opts] = fixture('display', overlay);
    dh = score_createDisplayHandles(opts);
    cleanup = onCleanup(@() close(dh.Figure)); %#ok<NASGU>
    gh = score_renderFinalFrame(dh,r,opts);
    verifyEqual(testCase,dh.ROI_rows,2);
    verifyEqual(testCase,double(gh.imgHandles.Count),2*(1+~overlay));
    verifyMaskRows(testCase,gh,1);
    score_updateRender(gh,r,opts,dh,2);
    verifyMaskRows(testCase,gh,2);
    % Each base image is repeated identically in the two annotation rows.
    a = gh.comparisonPanels(1);
    b = gh.comparisonPanels(1+(1+~overlay));
    verifyEqual(testCase,gh.imgHandles(a.tile).CData,gh.imgHandles(b.tile).CData);
    delete(gh.imgHandles(a.tile));
    verifyError(testCase,@() score_updateRender(gh,r,opts,dh,2), ...
        'score_updateRender:InvalidImageHandle');
end
end

function verifyMaskRows(testCase, gh, frame)
for p = gh.comparisonPanels
    h = gh.overlayHandles(p.tile);
    verifyEqual(testCase,h.Parent.UserData.annotationChannel,h.UserData.annotationChannel);
    if p.row == 1
        verifyGreaterThan(testCase,h.AlphaData(4+frame,4),0);
        verifyEqual(testCase,h.AlphaData(14+frame,14),0);
    else
        verifyEqual(testCase,h.AlphaData(4+frame,4),0);
        verifyGreaterThan(testCase,h.AlphaData(14+frame,14),0);
    end
end
end

function testSequenceGroupsAndVectorPdf(testCase)
for overlay = [false true]
    [r,opts] = fixture('sequence',overlay);
    opts.name = [tempname '.pdf'];
    cleanupFile = onCleanup(@() deleteIfPresent(opts.name)); %#ok<NASGU>
    dh = score_createDisplayHandles(opts);
    cleanup = onCleanup(@() close(dh.Figure)); %#ok<NASGU>
    gh = score_renderFinalFrame(dh,r,opts);
    verifyEqual(testCase,dh.ROI_rows,2*(1+~overlay));
    verifyEqual(testCase,dh.ROI_cols,2);
    verifyEqual(testCase,double(gh.imgHandles.Count),4*(1+~overlay));
    verifyTrue(testCase,isfile(opts.name));
    for p = gh.comparisonPanels
        h = gh.imgHandles(p.tile);
        patches = findall(h.Parent,'Type','patch');
        verifyNotEmpty(testCase,patches);
        xs = [patches.XData];
        if p.row == 1, verifyLessThan(testCase,max(xs(:)),10);
        else, verifyGreaterThan(testCase,min(xs(:)),10); end
    end
end
end

function testMovieGridAndFrameUpdates(testCase)
for overlay = [false true]
    [r,opts] = fixture('movie',overlay);
    [r2,~] = fixture('movie',overlay);
    [r3,~] = fixture('movie',overlay);
    opts.Nrow = 2; opts.Ncol = 2;
    opts.name = [tempname '.avi'];
    opts.movieProfile = 'Motion JPEG AVI';
    cleanupFile = onCleanup(@() deleteIfPresent(opts.name)); %#ok<NASGU>
    dh = score_createDisplayHandles(opts);
    cleanup = onCleanup(@() close(dh.Figure)); %#ok<NASGU>
    gh = score_renderFinalFrame(dh,[r r2 r3],opts);
    verifyEqual(testCase,double(gh.imgHandles.Count),6*(1+~overlay));
    movie = VideoReader(opts.name);
    verifyGreaterThan(testCase,movie.Duration,0);
    verifyGreaterThan(testCase,movie.Height,0);
    clear movie;
    % The writer has already advanced every ROI to the second frame.
    for p = gh.comparisonPanels
        h = gh.imgHandles(p.tile);
        patches = findall(h.Parent,'Type','patch');
        verifyNotEmpty(testCase,patches);
        ys = [patches.YData];
        if p.row == 1, verifyEqual(testCase,min(ys(:)),6);
        else, verifyEqual(testCase,min(ys(:)),16); end
    end
end
end

function testSequenceTypographyAndWholeCanvas(testCase)
for variant = 1:3
    [r,opts] = fixture('sequence',variant == 2);
    opts.fontSize = 28;
    opts.title = 'Sequence comparison'; opts.ROITitle = true;
    opts.hideStamp = false; opts.timeOffset = true;
    opts.channelLabel = {'0 TL_z2','SB GFP10_z2', ...
        'results_cellposeSAM_cell','MotherLineageViterbi_cell'};
    states = {'unclassified','clog','empty','dead','large','small','new bud'};
    r.data = dataseries(table(categorical(states(:),states,states), ...
        linspace(0.8,0.2,7)',linspace(0.3,0.7,7)', ...
        'VariableNames',{'label','ratio','reference'}));
    r.data.plotProperties = {true,'label','label','auto',1,'label'; ...
        true,'ratio','ratio','auto',1,'ratio';true,'reference','ratio','auto',1,'ratio'};
    opts.Ndataseries = 2; opts.ngroup = 2;
    opts.plotidx = {1,[2 3]}; opts.dataidx = {1,1};
    opts.plotidxgroup = {'label','Ratio Mean NoBckg SB GFP10_z2 / Pow1_z2'};
    opts.tileW = 24; opts.tileH = 24;
    rois = r;
    if variant == 1
        opts.Nrow = 2; rois = [r r];
        opts.tileW = 180; opts.tileH = 180; opts.Nbrick = 2;
    elseif variant == 3
        opts.channel = opts.channel(1:3); opts.levels = opts.levels(1:3);
        opts.RGB = opts.RGB(1:3); opts.channelLabel = opts.channelLabel(1:3);
    end
    opts.name = [tempname '.pdf'];
    cleanupFile = onCleanup(@() deleteIfPresent(opts.name)); %#ok<NASGU>
    dh = score_createDisplayHandles(opts);
    cleanup = onCleanup(@() close(dh.Figure)); %#ok<NASGU>
    dh.Figure.Position(3:4) = [300 200];
    gh = score_renderFinalFrame(dh,rois,opts);
    canvas = gh.sequenceLayout.canvasSize;
    if variant == 1, verifyGreaterThan(testCase,canvas(2),2000); end
    dpi = get(groot,'ScreenPixelsPerInch');
    verifyEqual(testCase,dh.Figure.PaperSize,canvas/dpi,'AbsTol',1e-8);
    pdf = fileread(opts.name);
    box = regexp(pdf,'/MediaBox\s*\[([^\]]+)\]','tokens','once');
    verifyNotEmpty(testCase,box);
    verifyEqual(testCase,sscanf(box{1},'%f')',[0 0 canvas*72/dpi],'AbsTol',1);
    [nMasks,~,~] = score_annotationRows(opts);
    nChannels = opts.Nchannel;
    if opts.overlay, nChannels = 1; end
    verifyEqual(testCase,double(gh.imgHandles.Count),numel(rois)*nMasks*nChannels*numel(opts.frames));
    verifyNumElements(testCase,findall(dh.Figure,'Tag','AnnotationRowLabel'),numel(rois)*nMasks);
    verifyNumElements(testCase,findall(dh.Figure,'Tag','ScoreSequenceHeader'),numel(rois));
    stamps = findall(dh.Figure,'Tag','ScoreSequenceTimestamp');
    verifyNumElements(testCase,stamps,numel(rois)*numel(opts.frames));
    verifyTrue(testCase,any(arrayfun(@(h) strcmp(h.String,'0 min'),stamps)));
    rectangles = zeros(0,4);
    for key = gh.imgHandles.keys
        position = gh.imgHandles(key{1}).Parent.Position;
        verifyGreaterThanOrEqual(testCase,position(1:2),[0 0]);
        verifyLessThanOrEqual(testCase,position(1:2)+position(3:4),[1 1]);
        for previous = rectangles'
            intersection = min(position(1:2)+position(3:4),previous(1:2)'+previous(3:4)') - ...
                max(position(1:2),previous(1:2)');
            verifyTrue(testCase,any(intersection <= 0));
        end
        rectangles(end+1,:) = position; %#ok<AGROW>
    end
    for p = gh.sequenceLayout.plots
        verifyEqual(testCase,p.ax.XTickLabelRotation,0);
        verifyEmpty(testCase,p.ax.YLabel.String);
        if p.index < opts.Ndataseries, verifyEmpty(testCase,p.ax.XTickLabel); end
    end
end
end

function testImageOnlyMovieGridUsesSpaceForImages(testCase)
for overlay = [false true]
    [r,opts] = fixture('movie',overlay);
    opts.channel = opts.channel([1 3]); opts.levels = opts.levels([1 3]);
    opts.RGB = {[1 1 1],opts.RGB{3}};
    opts.Nchannel = 1; opts.Nrow = 2; opts.Ncol = 2;
    opts.tileW = 180; opts.tileH = 180;
    opts.title = ''; opts.ROITitle = false; opts.hideStamp = false;
    opts.background = [1 1 1]; opts.textColor = [0 0 0];
    opts.channelLabel = {'Channel1_z2','results_hoct_multidomain_null_20261012_v001'};
    rois = r;
    levels = [10000 22000 38000 55000];
    for k = 1:4
        [rois(k),~] = fixture('movie',overlay);
        rois(k).image(:,:,1,:) = levels(k);
    end
    opts.name = [tempname '.avi']; opts.movieProfile = 'Motion JPEG AVI';
    cleanupFile = onCleanup(@() deleteIfPresent(opts.name)); %#ok<NASGU>
    dh = score_createDisplayHandles(opts);
    cleanup = onCleanup(@() close(dh.Figure)); %#ok<NASGU>
    gh = score_renderFinalFrame(dh,rois,opts);
    canvas = gh.movieLayout.canvasSize;
    % Tighten the canvas by removing whitespace, while keeping every image
    % at the same resolution and preserving its complete field of view.
    verifyLessThan(testCase,prod(canvas),4*opts.tileW*opts.tileH/0.55);
    verifyEmpty(testCase,gh.movieLayout.plots);
    verifyNumElements(testCase,gh.movieLayout.timeHandles,1);
    verifyEqual(testCase,gh.movieLayout.timeHandles.String,'10 min');
    reader = VideoReader(opts.name);
    rgb = readFrame(reader);
    clear reader;
    keys = sort(cell2mat(gh.imgHandles.keys));
    for k = 1:numel(keys)
        ax = gh.imgHandles(keys(k)).Parent;
        verifyEqual(testCase,ax.Position(3:4).*canvas,[180 180],'AbsTol',1e-8);
        verifyEqual(testCase,ax.XLim,[0.5 24.5]);
        verifyEqual(testCase,ax.YLim,[0.5 24.5]);
        verifyImageCenter(testCase,rgb,ax,repmat(255*levels(k)/65535,1,3));
    end
    for tag = {'AnnotationRowLabel','ScoreMovieChannelLabel','ScoreMovieGlobalHeader','ScoreMovieTimestamp'}
        for h = reshape(findall(dh.Figure,'Tag',tag{1}),1,[])
            if strlength(strjoin(string(h.String))) == 0, continue; end
            extent = h.Extent;
            verifyGreaterThanOrEqual(testCase,extent(1:2),[-1 -1]);
            verifyLessThanOrEqual(testCase,extent(1:2)+extent(3:4), ...
                [h.Parent.XLim(2) h.Parent.YLim(2)]+1);
        end
    end
end
end

function testMaskOnlyAndLegacyRowCounts(testCase)
[r,opts] = fixture('display',false);
opts.channel = opts.channel(3:4); opts.levels = opts.levels(3:4);
opts.RGB = opts.RGB(3:4); opts.Nchannel = 1;
dh = score_createDisplayHandles(opts);
cleanup = onCleanup(@() close(dh.Figure)); %#ok<NASGU>
gh = score_renderFinalFrame(dh,r,opts);
verifyEqual(testCase,double(gh.imgHandles.Count),2);
verifyMaskRows(testCase,gh,1);
opts.levels = opts.levels(1);
verifyEqual(testCase,score_annotationRows(opts),1);
opts.levels = {[0 65535]};
verifyEqual(testCase,score_annotationRows(opts),1);
end

function testMovieTypographyFitsSmallImagesAndCategoricalData(testCase)
[r,opts] = fixture('movie',false);
opts.fontSize = 28;
opts.title = 'My movie'; opts.ROITitle = true;
opts.hideStamp = false;
opts.channelLabel = {'0 TL_z2','SB GFP10_z2', ...
    'results_cellposeSAM_cell','MotherLineageViterbi_cell'};
states = {'unclassified','clog','empty','dead','large','small','new bud'};
r.data = dataseries(table(categorical(states(:),states,states), ...
    linspace(0.8,0.2,7)',linspace(0.3,0.7,7)', ...
    'VariableNames',{'label','Ratio_Mean_NoBckg_SB_GFP10_z2','Reference_signal_channel'}));
r.data.plotProperties = {true,'label','label','auto',1,'label'; ...
    true,'ratio','ratio','auto',1,'ratio';true,'reference','ratio','auto',1,'ratio'};
opts.Ndataseries = 2; opts.ngroup = 2;
opts.plotidx = {1,[2 3]}; opts.dataidx = {1,1};
opts.plotidxgroup = {'label','Ratio Mean NoBckg SB GFP10_z2 / Pow1_z2'};
opts.tileH = 24; opts.tileW = 24;
opts.name = [tempname '.avi']; opts.movieProfile = 'Motion JPEG AVI';
cleanupFile = onCleanup(@() deleteIfPresent(opts.name)); %#ok<NASGU>
dh = score_createDisplayHandles(opts);
cleanup = onCleanup(@() close(dh.Figure)); %#ok<NASGU>
gh = score_renderFinalFrame(dh,r,opts);
verifyTrue(testCase,isfield(gh,'movieLayout'));
stamp = findall(dh.Figure,'Tag','ScoreMovieTimestamp');
verifyNumElements(testCase,stamp,1);
verifyEqual(testCase,stamp.String,'10 min');
labels = findall(dh.Figure,'Tag','AnnotationRowLabel');
verifyNumElements(testCase,labels,2);
for h = labels(:)'
    verifyFalse(testCase,any(contains(string(h.String),'My movie'),'all'));
end
headers = findall(dh.Figure,'Tag','ScoreMovieHeader');
verifyNumElements(testCase,headers,1);
for tag = {'AnnotationRowLabel','ScoreMovieHeader','ScoreMovieChannelLabel','ScoreMovieDataLabel'}
    for h = reshape(findall(dh.Figure,'Tag',tag{1}),1,[])
        e = h.Extent;
        verifyGreaterThanOrEqual(testCase,e(1),-1);
        verifyGreaterThanOrEqual(testCase,e(2),-1);
        verifyLessThanOrEqual(testCase,e(1)+e(3),h.Parent.XLim(2)+1);
        verifyLessThanOrEqual(testCase,e(2)+e(4),h.Parent.YLim(2)+1);
    end
end
for p = gh.movieLayout.plots
    verifyEqual(testCase,p.ax.XTickLabelRotation,0);
    verifyLessThanOrEqual(testCase,p.ax.FontSize,14);
    verifyEmpty(testCase,p.ax.YLabel.String);
    for tile = gh.imgHandles.keys
        imageAxes = gh.imgHandles(tile{1}).Parent;
        verifyGreaterThanOrEqual(testCase,imageAxes.Position(2), ...
            p.ax.Position(2)+p.ax.Position(4));
    end
end
movie = VideoReader(opts.name);
verifyEqual(testCase,[double(movie.Width) double(movie.Height)],gh.movieLayout.canvasSize);
clear movie;
% A caller can update using its original options; timestamps stay in headers.
score_updateRender(gh,r,opts,dh,1);
verifyEqual(testCase,stamp.String,'5 min');
for tile = gh.vectorHandles.keys
    verifyFalse(testCase,any(isgraphics(gh.vectorHandles(tile{1}),'text')));
end
end

function testMovieHeaderWithSingleMask(testCase)
[r,opts] = fixture('movie',false);
opts.channel = opts.channel(1:3); opts.levels = opts.levels(1:3);
opts.RGB = opts.RGB(1:3);
opts.title = 'My movie'; opts.hideStamp = false;
opts.name = [tempname '.avi']; opts.movieProfile = 'Motion JPEG AVI';
cleanupFile = onCleanup(@() deleteIfPresent(opts.name)); %#ok<NASGU>
dh = score_createDisplayHandles(opts);
cleanup = onCleanup(@() close(dh.Figure)); %#ok<NASGU>
gh = score_renderFinalFrame(dh,r,opts);
verifyTrue(testCase,isfield(gh,'movieLayout'));
verifyNumElements(testCase,findall(dh.Figure,'Tag','ScoreMovieHeader'),1);
verifyNumElements(testCase,findall(dh.Figure,'Tag','AnnotationRowLabel'),1);
verifyNumElements(testCase,findall(dh.Figure,'Tag','ScoreMovieTimestamp'),1);
end

function testMovieCaptureIncludesFirstAndLastRowsBeyondViewport(testCase)
[r,opts] = fixture('movie',false);
[r2,~] = fixture('movie',false);
opts.Nrow = 2; opts.Ncol = 1;
opts.tileW = 180; opts.tileH = 600;
dh = score_createDisplayHandles(opts);
cleanup = onCleanup(@() close(dh.Figure)); %#ok<NASGU>
gh = score_renderAnnotationComparison(dh,[r r2],opts);
[gh,~] = score_layoutMovie(gh,dh,[r r2],opts);
first = gh.imgHandles(gh.comparisonPanels(1).tile);
last = gh.imgHandles(gh.comparisonPanels(end).tile);
first.CData = repmat(reshape(uint8([255 0 255]),1,1,3),24,24);
last.CData = repmat(reshape(uint8([0 255 255]),1,1,3),24,24);
% Simulate a desktop/window smaller than the requested movie canvas.
dh.Figure.Position(3:4) = [400 300];
drawnow;
rgb = score_captureMovieFrame(dh.Figure,gh);
verifyEqual(testCase,[size(rgb,2) size(rgb,1)],gh.movieLayout.canvasSize);
verifyGreaterThan(testCase,size(rgb,1),2000);
verifyImageCenter(testCase,rgb,first.Parent,[255 0 255]);
verifyImageCenter(testCase,rgb,last.Parent,[0 255 255]);
path = [tempname '.avi'];
cleanupFile = onCleanup(@() deleteIfPresent(path)); %#ok<NASGU>
writer = VideoWriter(path,'Motion JPEG AVI');
open(writer); writeVideo(writer,rgb); close(writer);
reader = VideoReader(path);
decoded = readFrame(reader);
clear reader;
verifyEqual(testCase,size(decoded),size(rgb));
verifyImageCenter(testCase,decoded,first.Parent,[255 0 255]);
verifyImageCenter(testCase,decoded,last.Parent,[0 255 255]);
end

function verifyImageCenter(testCase,rgb,ax,color)
position = ax.Position; % normalized logical-canvas coordinates
x = round((position(1)+position(3)/2)*size(rgb,2));
y = round((1-position(2)-position(4)/2)*size(rgb,1));
sample = reshape(rgb(y-2:y+2,x-2:x+2,:),[],3);
verifyEqual(testCase,mean(double(sample),1),color,'AbsTol',15);
end

function testDataPanelsRemainBelowAllMaskRows(testCase)
for mode = {'display','sequence','movie'}
    [r,opts] = fixture(mode{1},false);
    r.data = dataseries(table([10;20],'VariableNames',{'area'}));
    r.data.plotProperties = {true,'area','area','auto',1,'metrics'};
    opts.Ndataseries = 1;
    opts.ngroup = 1;
    opts.plotidx = {1}; opts.dataidx = {1}; opts.plotidxgroup = {'metrics'};
    opts.legend = false;
    dh = score_createDisplayHandles(opts);
    cleanup = onCleanup(@() close(dh.Figure)); %#ok<NASGU>
    % Render directly to exercise sequence/movie geometry without encoding
    % another file; the dedicated export tests exercise those finalizers.
    gh = score_renderAnnotationComparison(dh,r,opts);
    [~,~,imageRows] = score_annotationRows(opts);
    dataTile = imageRows*dh.MasterCols + 1;
    verifyTrue(testCase,isKey(gh.dataAxes,dataTile));
    verifyEqual(testCase,dh.ROI_rows,imageRows+1);
    if ~strcmp(mode{1},'sequence')
        score_updateRender(gh,r,opts,dh,2);
        lines = gh.lineHandles(dataTile);
        marker = lines(arrayfun(@(h) strcmp(h.Marker,'o'),lines));
        verifyEqual(testCase,marker.XData,10);
        verifyEqual(testCase,marker.YData,20);
    end
end
end

function testScoreRebuildsAfterMaskSelectionChanges(testCase)
[r,~] = fixture('display',false);
folder = tempname;
mkdir(folder);
cleanupFolder = onCleanup(@() rmdir(folder,'s')); %#ok<NASGU>
r.path = folder;
r.display.intensity = [1 1 1;1 1 1;0 0 0;0 0 0];
r.display.alpha = [1 1 0.5 0.5];
r.display.width = ones(1,4);
r.display.displaylim = repmat([0;1],1,4);
r.save([],false);
app = score(r);
cleanupApp = onCleanup(@() deleteApp(app)); %#ok<NASGU>
score_display(app,'slow');
verifyTrue(testCase,isfield(app.graphicsHandles,'comparisonPanels'));
r.display.frame = 2;
score_display(app,'fast');
verifyMaskRows(testCase,app.graphicsHandles,2);
r.display.selectedchannel(4) = false;
app.UIAnnotationTable.Data{2,1} = false;
score_display(app,'fast');
verifyFalse(testCase,isfield(app.graphicsHandles,'comparisonPanels'));
r.display.selectedchannel(4) = true;
app.UIAnnotationTable.Data{2,1} = true;
score_display(app,'fast');
verifyTrue(testCase,isfield(app.graphicsHandles,'comparisonPanels'));
end

function testOverlayAlignmentSurvivesZoomResizeAndRestacking(testCase)
for comparison = [false true]
    [r,opts] = fixture('display',false);
    if ~comparison
        opts.channel = opts.channel(1:3);
        opts.levels = opts.levels(1:3);
        opts.RGB = opts.RGB(1:3);
    end
    dh = score_createDisplayHandles(opts);
    cleanup = onCleanup(@() close(dh.Figure)); %#ok<NASGU>
    gh = score_renderFinalFrame(dh,r,opts);
    drawnow;
    keys = gh.overlayHandles.keys;
    firstImage = gh.imgHandles(keys{1});
    firstImage.Parent.XLim = [3 18];
    firstImage.Parent.YLim = [2 20];
    dh.Figure.Position(3:4) = [500 400];
    drawnow;
    overlay = gh.overlayHandles(keys{1});
    uistack(overlay.Parent,'bottom');
    % Settle the deliberate external restack before testing synchronization.
    drawnow;
    score_syncOverlayAxes(gh);
    drawnow;
    for key = keys
        h = gh.overlayHandles(key{1});
        base = gh.imgHandles(key{1});
        verifyEqual(testCase,getpixelposition(h.Parent,true), ...
            getpixelposition(base.Parent,true),'AbsTol',1e-8);
        verifyEqual(testCase,h.Parent.XLim,[3 18]);
        verifyEqual(testCase,h.Parent.YLim,[2 20]);
        children = dh.Figure.Children;
        verifyLessThan(testCase,find(children == h.Parent,1), ...
            find(children == dh.masterTiledLayout,1));
    end
    score_syncOverlayAxes(gh);
    verifyEqual(testCase,gh.overlayHandles(keys{1}),overlay);
end
end

function deleteApp(app)
if ~isvalid(app), return; end
imageFigure = app.ImageFigure;
if isgraphics(imageFigure)
    imageFigure.KeyPressFcn = [];
    imageFigure.WindowKeyPressFcn = [];
end
delete(app);
if isgraphics(imageFigure), delete(imageFigure); end
end

function [r,opts] = fixture(mode,overlay)
r = roi('comparison',[1 1 24 24]);
r.image = zeros(24,24,4,2,'uint16');
r.image(:,:,1,:) = 16000;
r.image(:,:,2,:) = 32000;
for f = 1:2
    r.image(4+f:7+f,4:7,3,f) = 2;
    r.image(14+f:17+f,14:17,4,f) = 3;
end
r.channelid = 1:4;
r.display.channel = {'raw','fluorescence','maskA','maskB'};
r.display.indexed = [false false true true];
r.display.rgb = [1 1 1;0 1 0;1 0 0;0 0 1];
r.display.selectedchannel = true(1,4);
r.display.contour = [false false true true];
opts = score_collectDisplayOptions('mode',mode,'overlay',overlay, ...
    'frames',[1 2],'Nrow',1,'Ncol',1,'Nchannel',2,'hideStamp',true);
opts.channel = r.display.channel;
opts.levels = {[0 65535],[0 65535],{'-1','lines',0.5,true,1},{'-1','lines',0.5,true,1}};
opts.RGB = {[1 1 1],[0 1 0],[1 0 0],[0 0 1]};
opts.tileH = 120; opts.tileW = 120;
opts.scale = [false false];
end

function deleteIfPresent(path)
if isfile(path), delete(path); end
end
