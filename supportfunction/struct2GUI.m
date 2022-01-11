function struct2GUI(pstruct,position,handle)
% generates a GUI to set user defined parameters

if nargin==2
  
    handle=uifigure; 
end 

f=fieldnames(pstruct);
handle.UserData=pstruct;

cc=1;

for i=1:numel(f)
    
    switch class(pstruct.(f{i}))
        case 'logical'
        
            t = uicheckbox(handle,'Text',f{i},'Value',pstruct.(f{i}),'Tag',f{i},'Position',[position(1) position(2)-(cc-1)*25 150 22]);
            t.ValueChangedFcn={@checkchanged,pstruct.(f{i})};

        case 'char'
            
            s = uilabel(handle,'Text',[ f{i} ':'],'Position',[position(1) position(2)-(cc-1)*25 150 22]);
            
            t = uieditfield(handle,'text','Value',pstruct.(f{i}),'Tag',f{i},'Position',[position(1)+150 position(2)-(cc-1)*25 200 22]);
            t.ValueChangedFcn={@checkchanged};
            
          case 'cell'
              
            s = uilabel(handle,'Text',[ f{i} ':'],'Position',[position(1) position(2)-(cc-1)*25 150 22]);
            
            t = uidropdown(handle,'Items',pstruct.(f{i}),'Value',pstruct.(f{i}){end},'Tag',f{i},'Position',[position(1)+150 position(2)-(cc-1)*25 200 22]);
            t.ValueChangedFcn={@dropchanged};
              
    end
    
    cc=cc+1;
end


function checkchanged(src,event)

src.Parent.UserData.(src.Tag)=src.Value; 

function dropchanged(src,event)

src.Parent.UserData.(src.Tag)=[src.Parent.UserData.(src.Tag)(1:end-1) src.Value]; 

