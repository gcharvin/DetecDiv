function [htext, hvector]= score_displayVectorGraphics(ax, f, ch, vContours , param)
% Affiche les textes et contours vectoriels sur l'image.
frames = param.frames;
scalingFactor = param.scalingFactor;
fontsize = param.fontSize;
hideStamp = param.hideStamp;
timeoffset = param.timeOffset;
framerate = param.framerate;
textColor = param.textColor;
hold(ax, 'on');

htext=[];
hvector=[];

if ch == 1 && ~hideStamp
    if timeoffset
        ts = [num2str((frames(f)-frames(1))*framerate) 'min'];
    else
        ts = [num2str(frames(f)*framerate) 'min'];
    end
    htext=text(ax, 0.01, 0.99, ts, 'FontName', 'Arial', 'FontSize', floor(sqrt(scalingFactor)*fontsize), ...
         'Color', textColor, 'Units', 'normalized', 'HorizontalAlignment', 'left', ...
         'VerticalAlignment', 'top', 'Interpreter', 'none');
end

vc = vContours;
cc=1;
for k = 1:length(vc)
    if ~isempty(vc(k).x) && all(isfinite(vc(k).x)) && all(isfinite(vc(k).y)) && all(vc(k).LineWidth(:) > 0)
        faceColor = double(vc(k).FaceColor); if any(faceColor > 1), faceColor = faceColor/255; end
        faceAlpha = double(vc(k).FaceAlpha);
        patchArgs = {'XData', vc(k).x, 'YData', vc(k).y, 'FaceColor', faceColor, 'FaceAlpha', faceAlpha};
        if ~(ischar(vc(k).EdgeColor) && strcmp(vc(k).EdgeColor, 'none')) && ~isempty(vc(k).LineWidth)
            edgeColor = double(vc(k).EdgeColor); if any(edgeColor > 1), edgeColor = edgeColor/255; end
            patchArgs = [patchArgs, {'EdgeColor', edgeColor, 'LineWidth', double(vc(k).LineWidth)}];
        else
            patchArgs = [patchArgs, {'LineStyle', 'none'}];
        end
       
        hvector(cc)=patch(ax, patchArgs{:});
        cc=cc+1;
    end
end
hold(ax, 'off');
end