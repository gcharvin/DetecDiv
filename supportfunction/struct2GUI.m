function struct2GUI(pstruct,position,varargin)
% generates a GUI to set user defined parameters

f=fieldnames(pstruct);

handle=[];
flag=[];
tip=cellstr('');
tip=repmat(tip,1,numel(f));
wid=150;

for i=1:numel(varargin)
    if strcmp(varargin{i},'Handle') % insert struct in a given gui
    handle=varargin{i+1};
    end
     if strcmp(varargin{i},'Flag') % indicate the handle to modify the color of a button when any field has been modifed
    flag=varargin{i+1};
     end
      if strcmp(varargin{i},'Tip') % indicate tips to be displayed when rolling over parameter. Must be a cell array of string, same size as the structure
    tip =varargin{i+1};
      end
       if strcmp(varargin{i},'Width') % indicate tips to be displayed when rolling over parameter. Must be a cell array of string, same size as the structure
  wid=varargin{i+1};
      end
end

if numel(tip)~=numel(f)
    errordlg('The number of items in the tips field is different than that of the dialog box!')
    return
end

if numel(handle)==0
    handle=uifigure;
end




handle.UserData=pstruct;

cc=1;

col=0;
%cd=1;

space=28;


for i=1:numel(f)
  tmp=  pstruct.(f{i});
    classe=class(tmp);
    
    switch classe
        
        case 'logical' % check box, editable

            
            t = uicheckbox(handle,'Text',f{i},'Value',pstruct.(f{i}),'Tag',f{i},'Position',[position(1)+(2*wid+20)*col position(2)-(cc-1)*space wid 22],'Tooltip',tip{i});
             
            t.ValueChangedFcn={@checkchanged,flag,'bool'};

        case {'char'} % string field
            
            tmp=pstruct.(f{i});
            if ~ischar(tmp)
                tmp=num2str(tmp);
            end
            
            s = uilabel(handle,'Text',[ f{i} ':'],'Position',[position(1)+(2*wid+20)*col position(2)-(cc-1)*space wid 22]);
            
            t = uieditfield(handle,'text','Value',tmp,'Tag',f{i},'Position',[position(1)+wid+(2*wid+20)*col position(2)-(cc-1)*space wid 22],'Tooltip',tip{i});
            t.ValueChangedFcn={@checkchanged,flag,'char'};
            
          case {'double','uint8','uint16','single'} % string field
            
            tmp=pstruct.(f{i});
            if ~ischar(tmp)
                tmp=num2str(tmp);
            end
            
            s = uilabel(handle,'Text',[ f{i} ':'],'Position',[position(1)+(2*wid+20)*col position(2)-(cc-1)*space wid 22]);
            
            t = uieditfield(handle,'text','Value',tmp,'Tag',f{i},'Position',[position(1)+wid+(2*wid+20)*col position(2)-(cc-1)*space wid 22],'Tooltip',tip{i});
            t.ValueChangedFcn={@checkchanged,flag,'num'};
            
            
          case 'cell' % drop down list, selectable
              
            s = uilabel(handle,'Text',[ f{i} ':'],'Position',[position(1)+(2*wid+20)*col position(2)-(cc-1)*space wid 22]);
            
            t = uidropdown(handle,'Items',pstruct.(f{i})(1:end-1),'Value',pstruct.(f{i}){end},'Tag',f{i},'Position',[position(1)+wid+(2*wid+20)*col position(2)-(cc-1)*space wid 22],'Tooltip',tip{i});
            t.ValueChangedFcn={@dropchanged,flag};
            
        case 'string' % string field, not editable 
            
          tmp=cellstr(pstruct.(f{i}));
            
          str='';
          for i=1:numel(tmp)
            str=[str char(tmp(i))];
          end
            
            s = uilabel(handle,'Text',[ f{i} ':'],'Position',[position(1)+(2*wid+20)*col position(2)-(cc-1)*space wid 22]);
            
            t = uieditfield(handle,'text','Value',str,'Tag',f{i},'Position',[position(1)+wid+(2*wid+20)*col position(2)-(cc-1)*space wid 22],'Tooltip',tip{i});
            t.Editable='off';
              
    end
    
   
    if (cc+2)*space>=handle.Position(4)

        col=col+1;
        cc=1;
    else
        cc=cc+1;
    end
 %   cc=cc+1;
end


function checkchanged(src,event,flag,typ)

switch typ
    case 'bool'
src.Parent.UserData.(src.Tag)=logical(src.Value); 
    case 'char'
    src.Parent.UserData.(src.Tag)=src.Value; 
    case 'num'
   src.Parent.UserData.(src.Tag)=str2num(src.Value);      
end


if numel(flag)
flag.Color=[1 0 0];
end


function dropchanged(src,event,flag)

src.Parent.UserData.(src.Tag)=[src.Parent.UserData.(src.Tag)(1:end-1) src.Value];

if numel(flag)
flag.Color=[1 0 0];
end

