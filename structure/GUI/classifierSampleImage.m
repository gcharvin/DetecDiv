function pixels = classifierSampleImage(classif)
%CLASSIFIERSAMPLEIMAGE Adapt classifier previews to the main image panel.
% Package previews can return pixels, an image object or a plot figure.
% Only figures created by this invocation are temporary; never close gcf.
filename=fullfile(classif.path,'sampleImage.png');
if isfile(filename),pixels=imread(filename);return;end
before=findall(groot,'Type','figure');current=get(groot,'CurrentFigure');
cleanup=onCleanup(@()finishPreview(before,current)); %#ok<NASGU>
[~,preview]=classif.displayFormattedTrainingSet('Display','Nimages',9);
if isempty(preview)
    pixels=[];
elseif isgraphics(preview,'figure')
    pixels=print(preview,'-RGBImage','-r100');
elseif isgraphics(preview,'image')
    pixels=preview.CData;
else
    pixels=preview;
end
assert(isnumeric(pixels)||islogical(pixels),'detecdiv:InvalidClassifierPreview', ...
    'Classifier preview must provide numeric pixels, an image object, or a figure.');
end

function finishPreview(before,current)
figures=findall(groot,'Type','figure');
for k=1:numel(figures)
    if ~any(figures(k)==before),delete(figures(k));end
end
if ~isempty(current)&&isgraphics(current,'figure'),set(groot,'CurrentFigure',current);end
end
