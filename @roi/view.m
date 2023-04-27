function view(obj,frame,classif)
% view for ROI objects
% category defines what kind of menu is displayed in order to perform the
% training on existing data
% category== 'Image' : Image classification can be performed using keyboard
% category== 'Pixel' : Pixel classification can be performed using painting
% tool

if numel(obj.image)==0
    obj.load
end

if numel(obj.image)==0
    disp('Impossible to display object !');
    return;
end

if nargin>=2
    obj.display.frame=frame;
end

if nargin<3
   classif=[];
end

frame=obj.display.frame;

if numel(findobj('Tag',['ROI' obj.id])) % handle exists already
    h=findobj('Tag',['ROI' obj.id]);
    %'ok'

else
    h=figure('Tag',['ROI' obj.id],'Units', 'Normalized','Position',[0 0.1 0.3 0.3]);%'Toolbar','none');%,'MenuBar','none');%,'Toolbar','none');
   %movegui(h,'center')
end

 draw(obj,h,classif);
end
