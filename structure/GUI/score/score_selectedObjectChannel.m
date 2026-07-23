function [roiobj, channelName, channelIdx] = score_selectedObjectChannel(app)
%SCORE_SELECTEDOBJECTCHANNEL Resolve the selected ROI and annotation channel.

roiobj = [];
channelName = '';
channelIdx = [];
try
    if isempty(app.content.ROIList) || isempty(app.UIROITable.Data)
        return;
    end
    roiIdx = find(cell2mat(app.UIROITable.Data(:,1)), 1, 'first');
    if isempty(roiIdx)
        return;
    end
    roiobj = app.content.ROIList{roiIdx};
    selection = app.UIAnnotationTable.Selection;
    if isempty(selection) || isempty(app.UIAnnotationTable.Data)
        return;
    end
    row = selection(1);
    annotation = char(string(app.UIAnnotationTable.Data{row, 2}));
    className = char(string(app.UIAnnotationTable.Data{row, 3}));
    if isempty(className)
        channelName = annotation;
    else
        channelName = [annotation '_' className];
    end
    channelIdx = find(strcmp(cellstr(string(roiobj.display.channel)), channelName), 1, 'first');
    if isempty(channelIdx)
        channelName = '';
    end
catch
    roiobj = [];
    channelName = '';
    channelIdx = [];
end
end
