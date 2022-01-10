function struct2GUI(pstruct,handle)
% generates a GUI to set user defined parameters

if nargin==1
    handle=uifigure; 
end 

f=fieldnames(pstruct);

handle.UserData.data=pstruct;

t = uicheckbox(handle,'Text',f{1},'Value',1,'Tag',f{1});
t.ValueChangedFcn={@checkchanged,pstruct.text};

handle.UserData=pstruct;

function checkchanged(src,event,out)

src.Parent.UserData.data.(src.Tag)=src.Value; 

