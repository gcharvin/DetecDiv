function status(obj,varargin)

% displays the status of the shallow project in the workspace
display=[0 0 0 0]  ;
for i=1:numel(varargin)
    
    if strcmp(varargin{i},'general')
        display(1)=1;
    end
    if strcmp(varargin{i},'fov')
        display(2)=1;
    end
    if strcmp(varargin{i},'roi')
        display(2)=1;
    end
    if strcmp(varargin{i},'processing')
        display(3)=1;
    end
end

if nargin==1
    display=[1 1 1 1]  ;
end

if display(1)
    
    disp('*------------------------------------------*');
    disp('*--------------- GENERAL ------------------*');
    disp('*------------------------------------------*');
    disp(' ');
    disp(['Current project path: ' num2str(obj.io.path) '/' num2str(obj.io.file)]);
    
    l=dir([num2str(obj.io.path) '/' num2str(obj.io.file) '.mat']);
    
    disp(['Last saving data: ' l.date]);
    
    disp(['Use shallowSave function to save project: shallowSave(myshallowobject)']);
    disp(' ');
end

if display(1)
    
    disp('*------------------------------------------*');
    disp('*--------------- FOV(s) ------------------*');
    disp('*------------------------------------------*');
    disp(' ');
    
    n=numel(obj.fov);
    if n==1
        if numel(obj.fov(1).id)==0
            n=0;
        end
    end
    
    disp(['Project currently has: ' num2str(n) ' Field(s) of view']);
    disp(' ');
    disp(['To add fields of view, use the addData method: myshallowproject.addData']);
end

if display(2)
    disp('*------------------------------------------*');
    disp('*--------------- ROI(s) ------------------*');
    disp('*------------------------------------------*');
    
    nfov=numel(obj.fov);
    if nfov==1
        if numel(obj.fov(1).id)==0
            nfov=0;
        end
    end
    
    nroi=[];
    for i=1:numel(obj.fov)
        n=numel(obj.fov(i).roi);
        if n==1
            if numel(obj.fov(i).roi(1).id)==0
                n=0;
            end
        end
        
        nroi(i)=n;
    end
    
        disp('List of ROIs for each FOV:');
        disp(num2str(1:1:numel(nfov)));
        disp(num2str(nroi));
        disp(['To display ROIs for a given FOV, use the view method: myshallowproject.fov(FOVnumber).view']);
        disp(['To add ROIs to a given FOV, use the GUI (displayed by the view method above)']);
        disp(['To remove ROIs from a given FOV, use the removeROI method: myshallowproject.fov(FOVnumber).removeROI(ROInumberstoberemoved)']);
        disp('Crop and save list of images for a specific ROI using : myshallowproject.fov(FOVnumber).saveCroppedImages(FOVnumber)');
        disp(' ');
        disp(['Automated ROI detection:']);
        disp(' ');
        disp('1) Define an ROI using method above to create a pattern');
        disp('2) Set a pattern using shallowObj method: myshallowObject.setPattern(FOVid,ROIid)');
        disp('where FOVid is the id of the FOV in which the ROI was defined');
        disp('where ROIid is the id of the defined ROI');
        disp('3) automatically identify ROIs in a specfic FOV using: myshallowObject.identifyROIs(FOVid)');
        disp('5) crop and save images: myshallowproject.fov(FOVnumber).saveCroppedImages(FOVid)');
end
    
    
