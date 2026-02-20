classdef Traj < handle
    % new class to display the trajectory of dividing cells
    
    properties
        color=[]; % rgb colors used
        colorIndex=[]; % array that sets the sequence of color indices
        rec=[]; %array of rectangles width to be displayed
        
        edgeColor=[] % same as above with edge color
        edgeColorIndex=[];
        edgeWidth=[]; % width of edge lines
        
        sepColor=[];
        sepBottomColor=[];
        sepTopColor=[]
        sepWidth=[];
        
        startX=[]; %starting coordinates of the traj
        startY=[]; %starting coordinates of the traj
        
        topColor=[];
        topColorIndex=[];
        
        bottomColor=[];
        bottomColorIndex=[];
        
        gradientWidth=[]; % width of the gradient area
        colorMode='' % 'flat' or 'interp'
        width=[]; % width of the rectangle to be used
        
        hPatch=[]; % handle to patch
        hLine1=[]; % handle to top line
        hLine2=[]; % handle to bottom line
        hSep=[]; % handle to separation line
        
        orientation='';
        tag='';
        
    end
    
    properties (Dependent = true)
        
    end
    
    methods
        %constructor function
        function t = Traj(rec,varargin)
            
            %default property values
            t.color=[0 0 0.5; 0.5 0 0];
            t.colorIndex=[1 2];
            t.rec=rec;
            
            t.edgeColor=[0 0 0];
            t.edgeColorIndex=1;
            t.edgeWidth=0;
            
            t.sepColor=[0.3 0.3 0.3];
            t.sepBottomColor=[0 0 0];
            t.sepTopColor=[1 1 1];
            t.sepWidth=3;
            
            t.startX=0;
            t.startY=0;
            
            t.topColor=[1 1 1];
            t.topColorIndex=1;
            
            t.bottomColor=[0 0 0];
            t.bottomColorIndex=1;
            
            
            t.colorMode='interp'; % flat
            t.width=1;
            t.gradientWidth=4*t.width;
            
            t.orientation='horizontal';
            t.tag='no tag';
            % varargin parsing
            
            i=1;
            handle=[];
            
            while i<=numel(varargin)
                
                if ischar(varargin{i}) && strcmpi(varargin{i},'color')
                    t.color=varargin{i+1};
                    %t.bottomColor=[0.1 0.1 0];
                    %t.topColor=[1 1 1];
                    warning off all;
                    
                    t.colorIndex=ones(1,numel(t.rec(:,1)));
                    warning on all;
                    t.topColorIndex=t.colorIndex;
                    t.bottomColorIndex=t.colorIndex;
                    t.edgeColorIndex=t.colorIndex;
                    %t.top
                    
                    i=i+2;
                    if i>numel(varargin)
                        break
                    end
                end
                if ischar(varargin{i}) && strcmpi(varargin{i},'colorIndex')
                    t.colorIndex=varargin{i+1};
                    i=i+2;
                    if i>numel(varargin)
                        break
                    end
                end
                
                if ischar(varargin{i}) && strcmpi(varargin{i},'bottomColor')
                    t.bottomColor=varargin{i+1};
                    i=i+2;
                    if i>numel(varargin)
                        break
                    end
                end
                
                if ischar(varargin{i}) && strcmpi(varargin{i},'topColor')
                    t.topColor=varargin{i+1};
                    i=i+2;
                    if i>numel(varargin)
                        break
                    end
                end
                
                if ischar(varargin{i}) && strcmpi(varargin{i},'bottomColorIndex')
                    t.bottomColorIndex=varargin{i+1};
                    i=i+2;
                    if i>numel(varargin)
                        break
                    end
                end
                
                if ischar(varargin{i}) && strcmpi(varargin{i},'topColorIndex')
                    t.topColorIndex=varargin{i+1};
                    i=i+2;
                    if i>numel(varargin)
                        break
                    end
                end
                
                if ischar(varargin{i}) && strcmpi(varargin{i},'edgeColor')
                    t.edgeColor=varargin{i+1};
                    t.edgeColorIndex=ones(1,size(rec(:,1)));
                    i=i+2;
                    if i>numel(varargin)
                        break
                    end
                end
                if ischar(varargin{i}) && strcmpi(varargin{i},'edgeColorIndex')
                    t.edgeColorIndex=varargin{i+1};
                    i=i+2;
                    if i>numel(varargin)
                        break
                    end
                end
                if ischar(varargin{i}) && strcmpi(varargin{i},'edgeWidth')
                    t.edgeWidth=varargin{i+1};
                    i=i+2;
                    if i>numel(varargin)
                        break
                    end
                end
                if ischar(varargin{i}) && strcmpi(varargin{i},'sepWidth')
                    t.sepWidth=varargin{i+1};
                    i=i+2;
                    if i>numel(varargin)
                        break
                    end
                end
                if ischar(varargin{i}) && strcmpi(varargin{i},'sepColor')
                    t.sepColor=varargin{i+1};
                    i=i+2;
                    if i>numel(varargin)
                        break
                    end
                end
                if ischar(varargin{i}) && strcmpi(varargin{i},'sepBottomColor')
                    t.sepBottomColor=varargin{i+1};
                    i=i+2;
                    if i>numel(varargin)
                        break
                    end
                end
                if ischar(varargin{i}) && strcmpi(varargin{i},'sepTopColor')
                    t.sepTopColor=varargin{i+1};
                    i=i+2;
                    if i>numel(varargin)
                        break
                    end
                end
                if ischar(varargin{i}) && strcmpi(varargin{i},'startx')
                    t.startX=varargin{i+1};
                    i=i+2;
                    if i>numel(varargin)
                        break
                    end
                end
                if ischar(varargin{i}) && strcmpi(varargin{i},'starty')
                    t.startY=varargin{i+1};
                    i=i+2;
                    if i>numel(varargin)
                        break
                    end
                end
                if ischar(varargin{i}) && strcmpi(varargin{i},'width')
                    t.width=varargin{i+1};
                    t.gradientWidth=4*t.width;
                    i=i+2;
                    if i>numel(varargin)
                        break
                    end
                end
                if ischar(varargin{i}) && strcmpi(varargin{i},'gradientwidth')
                    t.gradientWidth=varargin{i+1};
                    i=i+2;
                    if i>numel(varargin)
                        break
                    end
                end
                if ischar(varargin{i}) && strcmpi(varargin{i},'orientation')
                    t.orientation=varargin{i+1};
                    i=i+2;
                    if i>numel(varargin)
                        break
                    end
                end
                if ischar(varargin{i}) && strcmpi(varargin{i},'startx')
                    t.startX=varargin{i+1};
                    i=i+2;
                    if i>numel(varargin)
                        break
                    end
                end
                if ischar(varargin{i}) && strcmpi(varargin{i},'starty')
                    t.startY=varargin{i+1};
                    i=i+2;
                    if i>numel(varargin)
                        break
                    end
                end
                if ischar(varargin{i}) && strcmpi(varargin{i},'tag')
                    t.tag=varargin{i+1};
                    i=i+2;
                    if i>numel(varargin)
                        break
                    end
                end
                if ishandle(varargin{i})
                    handle=varargin{i};
                    handlestruct=varargin{i+1};
                    %figure(handle)
                    % phyloCell handle is provided
                    i=i+2;
                    if i>numel(varargin)
                        break
                    end
                end
                if i>=numel(varargin)
                    break
                end
            end
            
            if numel(handle)==0
                handle=gca;
                handlestruct=[];
            end
            
            
            
            % plotting traj
            
            for i=1:size(t.rec,1)
                
                % draw patch
                
                vecXMinMax=t.rec(i,:);
                vecYMinMax=[0 t.width];
                
                vecV= [0 0.5; 1 0.5; 1 -0.5; 0 -0.5];
                vecFaceOrder = [1 2 3 4];
                cdata=[t.color(t.colorIndex(i),:); t.color(t.colorIndex(i),:); t.color(t.colorIndex(i),:); t.color(t.colorIndex(i),:)];
                
                if t.gradientWidth~=0
                    r=0.5*t.gradientWidth/t.width;
                    vecV= [vecV ; 0 0.5+r; 1 0.5+r; 1 -0.5-r; 0 -0.5-r];
                    vecFaceOrder = [vecFaceOrder; 1 5 6 2; 3 7 8 4];
                    cdata=[cdata; t.topColor(t.topColorIndex(i),:); t.topColor(t.topColorIndex(i),:); t.bottomColor(t.bottomColorIndex(i),:); t.bottomColor(t.bottomColorIndex(i),:)];
                end
                
                vecV(:,1) = vecV(:,1)*(vecXMinMax(2)-vecXMinMax(1))+vecXMinMax(1);
                vecV(:,2) = vecV(:,2)*(vecYMinMax(2)-vecYMinMax(1))+vecYMinMax(1);
                
                
                
                
                switch lower(t.orientation)
                    case 'horizontal'
                        
                    case 'vertical'
                        vecV = -fliplr(vecV);
                        
                        temp=vecXMinMax;
                        vecXMinMax=vecYMinMax;
                        vecYMinMax=temp;
                    otherwise
                        error('unrecognised typeHorzVert, must be horizontal or vertical');
                end
                
                
                vecV(:,1)=vecV(:,1)+t.startX;
                vecV(:,2)=vecV(:,2)+t.startY;
                
                
                vecXMinMax=sort(vecXMinMax)+t.startX;
                vecYMinMax=sort(vecYMinMax)+t.startY-t.width/2;
                
                if vecXMinMax==vecXMinMax(2)
                    continue
                end
                
                
                
                %t.hPatch(i) =patch('Faces',vecFaceOrder,'Vertices',vecV,'FaceColor',t.colorMode,'FaceVertexCData',cdata,'EdgeColor','none','Tag',[t.tag ' - seg :' num2str(i) '/' num2str(numel(t.rec(:,1))) ' - length :' num2str(t.rec(i,2)-t.rec(i,1)) ' ']);
                t.hPatch(i) =rectangle('Position',[vecXMinMax(1) vecYMinMax(1) vecXMinMax(2)-vecXMinMax(1) vecYMinMax(2)-vecYMinMax(1)],'FaceColor',t.color(t.colorIndex(i),:),'EdgeColor','none','Tag',[t.tag ' - seg :' num2str(i) '/' num2str(numel(t.rec(:,1))) ' - length :' num2str(t.rec(i,2)-t.rec(i,1)) ' ']);
                % t.color(t.colorIndex(i),:)
                
                set(t.hPatch(i),'ButtonDownFcn',{@test,handle,handlestruct});
                
                %function myCallback(src,eventdata,arg1
            end
            
            if t.sepWidth
                for i=1:size(t.rec,1)
                    % draw separation patch
                    
                    vecXMinMax=[0 t.sepWidth];
                    vecYMinMax=[0 t.width];
                    
                    vecV2= [-0.5 0.5; 0.5 0.5; 0.5 -0.5; -0.5 -0.5];
                    vecFaceOrder = [1 2 3 4];
                    cdata=[t.sepColor; t.sepColor; t.sepColor; t.sepColor];
                    
                    if t.gradientWidth~=0
                        r=0.5*t.gradientWidth/t.width;
                        vecV2= [vecV2 ; -0.5 0.5+r; 0.5 0.5+r; 0.5 -0.5-r; -0.5 -0.5-r];
                        vecFaceOrder = [vecFaceOrder; 1 5 6 2; 3 7 8 4];
                        cdata=[cdata; t.sepTopColor; t.sepTopColor; t.sepBottomColor; t.sepBottomColor];
                    end
                    
                    vecV2(:,1) = vecV2(:,1)*(vecXMinMax(2)-vecXMinMax(1))+vecXMinMax(1);
                    vecV2(:,2) = vecV2(:,2)*(vecYMinMax(2)-vecYMinMax(1))+vecYMinMax(1);
                    
                    
                    switch lower(t.orientation)
                        case 'horizontal'
                            vecV2(:,1)=vecV2(:,1)+t.startX+t.rec(i,2); %-t.sepWidth/2;
                            vecV2(:,2)=vecV2(:,2)+t.startY;
                        case 'vertical'
                            vecV2 = -fliplr(vecV2);
                            vecV2(:,1)=vecV2(:,1)+t.startX;
                            vecV2(:,2)=vecV2(:,2)+t.startY-t.rec(i,2); %+t.sepWidth/2;
                        otherwise
                            error('unrecognised typeHorzVert, must be horizontal or vertical');
                    end
                    
                    vecXMinMax=sort(vecXMinMax)+t.startX+t.rec(i,1);
                    vecYMinMax=sort(vecYMinMax)+t.startY-t.width/2;
                    
                    % t.hSep(i) =patch('Faces',vecFaceOrder,'Vertices',vecV2,'FaceColor',t.colorMode,'FaceVertexCData',cdata,'EdgeColor','none');
                    
                    %t.hPatch(i) =patch('Faces',vecFaceOrder,'Vertices',vecV,'FaceColor',t.colorMode,'FaceVertexCData',cdata,'EdgeColor','none','Tag',[t.tag ' - seg :' num2str(i) '/' num2str(numel(t.rec(:,1))) ' - length :' num2str(t.rec(i,2)-t.rec(i,1)) ' ']);
                    
                    t.hSep(i) =rectangle('Position',[vecXMinMax(1) vecYMinMax(1) vecXMinMax(2)-vecXMinMax(1) vecYMinMax(2)-vecYMinMax(1)],'FaceColor',t.sepColor,'EdgeColor','none','EdgeColor','none');
                    
                    
                end
            end
            
            if t.edgeWidth
                for i=1:size(t.rec,1)
                    
                    % draw edge line
                    
                    vecXMinMax=t.rec(i,:);
                    vecYMinMax=[0 t.width];
                    
                    vecV= [0 0.5; 1 0.5; 1 -0.5; 0 -0.5];
                    vecFaceOrder = [1 2 3 4];
                    cdata=[t.color(t.colorIndex(i),:); t.color(t.colorIndex(i),:); t.color(t.colorIndex(i),:); t.color(t.colorIndex(i),:)];
                    
                    if t.gradientWidth~=0
                        r=0.5*t.gradientWidth/t.width;
                        vecV= [vecV ; 0 0.5+r; 1 0.5+r; 1 -0.5-r; 0 -0.5-r];
                        vecFaceOrder = [vecFaceOrder; 1 5 6 2; 3 7 8 4];
                        cdata=[cdata; t.topColor(t.topColorIndex(i),:); t.topColor(t.topColorIndex(i),:); t.bottomColor(t.bottomColorIndex(i),:); t.bottomColor(t.bottomColorIndex(i),:)];
                    end
                    
                    vecV(:,1) = vecV(:,1)*(vecXMinMax(2)-vecXMinMax(1))+vecXMinMax(1);
                    vecV(:,2) = vecV(:,2)*(vecYMinMax(2)-vecYMinMax(1))+vecYMinMax(1);
                    
                    
                    switch lower(t.orientation)
                        case 'horizontal'
                            
                        case 'vertical'
                            vecV = -fliplr(vecV);
                        otherwise
                            error('unrecognised typeHorzVert, must be horizontal or vertical');
                    end
                    
                    
                    vecV(:,1)=vecV(:,1)+t.startX;
                    vecV(:,2)=vecV(:,2)+t.startY;
                    %a=t.edgeColorIndex(i)
                    vecBorderColor=t.edgeColor(t.edgeColorIndex(i),:);
                    linewidth=t.edgeWidth;
                    
                    
                    minx=min(vecV(:,1));
                    maxx=max(vecV(:,1));
                    miny=min(vecV(:,2));
                    maxy=max(vecV(:,2));
                    
                    switch lower(t.orientation)
                        case 'horizontal'
                            t.hLine1(i)=line([minx;maxx],[miny; miny],'color',vecBorderColor,'linewidth',linewidth);
                            t.hLine2(i)=line([minx;maxx],[maxy; maxy],'color',vecBorderColor,'linewidth',linewidth);
                        case 'vertical'
                            t.hLine1(i)=line([minx;minx],[miny; maxy],'color',vecBorderColor,'linewidth',linewidth);
                            t.hLine2(i)=line([maxx;maxx],[miny; maxy],'color',vecBorderColor,'linewidth',linewidth);
                    end
                end
                
                % todo : draw lines at each extremity of the traj
                
                % hLine(3)=line([vecXMinMax(1);vecXMinMax(2)],[vecYMinMax(1);vecYMinMax(1)],'color',vecBorderColor,'linewidth',0.1);
                % hLine(4)=line([vecXMinMax(1);vecXMinMax(2)],[vecYMinMax(2);vecYMinMax(2)]
                % ,'color',vecBorderColor,'linewidth',0.1);
            end
            
            %gca;
            %axis tight;
            %axis equal;
        end % Traj object
        
        
        % function depData = get.dependentData(obj)
        %     depData = obj.area;
        % end
        
        % axis tight equal : to focus on the plot itself
        
    end
end


function test(obj, event, handles,handlesstruct)

if isstruct(handlesstruct)
    global segmentation
    pt = get(gca, 'CurrentPoint');
    frame=round(pt(1,1));
    
    src=get(obj,'Tag');
    f1=strfind(src,':');
    f2=strfind(src,'-');
    nObject=str2num(src(f1+1:f2-1));

    
    if ~isempty(segmentation.selectedTObj)  %if exist a selected tobject then delesect it
        strObj=segmentation.selectedType;
        segmentation.selectedTObj.deselect();
        segmentation.selectedTObj={};
    else
       return; 
    end
    
    if ~isempty(segmentation.selectedObj) %if exist a selected object then deselect it
        segmentation.selectedObj.selected=0;
        segmentation.selectedObj={};
    end
    
    
    
    if nObject<=length(segmentation.(['t' strObj])) && nObject>=1 %if it is in the limits
        if segmentation.(['t' strObj])(nObject).N==nObject %check if it was deleted (.N==0)
            segmentation.(['t' strObj])(nObject).select(); %select the new cell
            segmentation.selectedTObj=segmentation.(['t' strObj])(nObject); % copy it
           
            phy_change_Disp1(frame,handlesstruct);
        end
    end
    
    
    
else
    src=get(obj,'Tag');
    axes(handles);
    title(src);
end
end