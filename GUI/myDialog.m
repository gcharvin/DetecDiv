function results=myDialog(names,default,varargin)


% param : a cell array that specifies the names of the fields to be
% displayed

% default : the default values


title='Please choose';
tip={};
pos=[];

for i=1:numel(varargin)

    if strcmp(varargin{i},'Tip')
        tip=varargin{i+1};
    end

    if strcmp(varargin{i},'Title')
        title=varargin{i+1};
    end

    if strcmp(varargin{i},'CallingApp')
        app=varargin{i+1};
        pos=app.Position;

    end
end


% returns the handles to the dialog box


if nargin==0
    param=[];

    param.myfield1=true;
    param.myfield2='test';
    param.myfield3=10;
    param.myfield4={'choice1','choice2','choice3','choice3'};

    tip={'This is check box','This is a string input field','This is a numeric input field','this is multiple choice input field'};
else
    param=[];

    if numel(names)~=numel(default)
        disp('the number of default values is inconsistent with the nmber of params');
        return;
    end

    for i=1:numel(names)
        param.(names{i})=default{i};
    end
end

%
%         tip={'Keyboard shortcuts used to assign a class to an image; Please enter space-separated letters; Please restart the ROI viewer after modification',...
%                 'Keyboard shortcuts used to correct GT vs prediction discrepancies; Please enter space-separated letters; Please restart the ROI viewer after modification',...
%                 'Keyboard shortcuts used to set frames bounds: only frames within the bounds will be considered for training; Please enter space-separated letters; Please restart the ROI viewer after modification',...
%                 'Keyboard shortcuts used to quickly jump between frames',....
%                  'Keyboard shortcuts used to fill holes when painting',...
%                  'Keyboard shortcuts used to change painting transparency',...
%                  'Size in pixels of the brush size used when using the left mouse button;  Please restart the ROI viewer after modification',...
%         'Size in pixels of the brush size used when using the right mouse button;  Please restart the ROI viewer after modification',...
%         'Size in pixels of the brush size used when using the mouse wheel button;  Please restart the ROI viewer after modification'};
%
%     userprefs=struct('roi_view_shortcut_keys','a z e r t y u i',...
%         'roi_view_corr_shortcut_keys','j k',...
%         'roi_view_bounds_shortcut_keys','w x',...
%         'roi_view_frames_jump_size','l m',...
%         'painting_fill_holes_shortcut','k',...
%         'painting_transparency_shortcut','2 8',...
%         'painting_large_brush_size', 9,...
%         'painting_small_brush_size', 1,...
%         'painting_huge_brush_size', 49,...
%         'tip',{tip});
%

nfields=fieldnames(param);
siz=25*numel(nfields)+50;


if numel(tip)==0
    for i=1:numel(nfields)
        tip{i}='';
    end
end

param.tip=tip;


if numel(pos)==0
    posi=[100 100 400 siz];
else
    posi=pos;
    posi(1)=posi(1)+10;
    posi(2)=posi(2)+pos(4)-siz-20;
    posi(3)=500;
    posi(4)=siz;

end

h=uifigure('Position',posi,'Name',title,'WindowStyle','modal','CloseRequestFcn',{@fdel});

% create structure;
%
%    trainingParam=userprefs;
tip=param.tip;
param=rmfield(param,'tip');
h.UserData=[];
si=h.Position(4);
struct2GUI(param,[10 si-25],'Handle',h,'Tip',tip,'Width',200);

bok=uibutton(h,'Text','OK','ButtonPushedFcn',{@fcnok,h},'Position',[200 5 50 25 ]);
bcancel=uibutton(h,'Text','Cancel','ButtonPushedFcn',{@fcncancel,h},'Position',[270 5 50 25 ]);

uiwait(h);

if strcmp(h.Tag,'ok')
    results=h.UserData;
else
    results=[];
end
delete(h);

    function fcnok(handle,event,hfig)
        hfig.Tag='ok';
        uiresume(hfig);
    end

    function fcncancel(handle,event,hfig)
        hfig.Tag='cancel';
       uiresume(hfig);
    end

    function fdel(handle,event,hfig)
        uiresume(handle)
    end


end

