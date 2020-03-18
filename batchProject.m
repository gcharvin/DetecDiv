function batchProject(obj,varargin)

% perform batch operation on movi and arrays of moviesfor i=1:numel(varargin)

%index: provides the list of movie index to be processed

task={};

cc=1;
pixclassifierpath=[];
objclassifierpath=[];
divclassifierpath=[];

ind=1:numel(obj);

for i=1:numel(varargin)
    
    if strcmp(varargin{i},'index')
        ind=varargin{i+1};
        cc=cc+1;
    end
    
    if strcmp(varargin{i},'identifyTraps')
        task{cc}='identifyTraps';
        pattern=varargin{i+1};
        cc=cc+1;
    end
    
     if strcmp(varargin{i},'fakeNuclei')
        task{cc}='fakeNuclei';
        inputpoly=varargin{i+1};
        cc=cc+1;
     end
    
    if strcmp(varargin{i},'loadpixclassifier')
        task{cc}='loadpixclassifier';
        pixclassifierpath=varargin{i+1};
        cc=cc+1;
    end
    
    if strcmp(varargin{i},'appendpixclassifier')
        task{cc}='appendpixclassifier';
        
        pixclassifierpath=varargin{i+1};
        
        cc=cc+1;
    end
    
    if strcmp(varargin{i},'savepixclassifier')
        task{cc}='savepixclassifier';
        
        pixclassifierpath=varargin{i+1};
        
        cc=cc+1;
    end
    
    if strcmp(varargin{i},'pixclassify')
        task{cc}='pixclassify';
        cc=cc+1;
    end
    
        if strcmp(varargin{i},'computefluo')
        task{cc}='computefluo';
        cc=cc+1;
    end
    
    if strcmp(varargin{i},'loadobjclassifier')
        task{cc}='loadobjclassifier';
        objclassifierpath=varargin{i+1};
        cc=cc+1;
    end
    
    if strcmp(varargin{i},'appendobjclassifier')
        task{cc}='appendobjclassifier';
        
        objclassifierpath=varargin{i+1};
        
        cc=cc+1;
    end
    
    if strcmp(varargin{i},'saveobjclassifier')
        task{cc}='saveobjclassifier';
        
        objclassifierpath=varargin{i+1};
        
        cc=cc+1;
    end
    
    if strcmp(varargin{i},'objclassify')
        task{cc}='objclassify';
        cc=cc+1;
    end
    
    if strcmp(varargin{i},'loaddivclassifier')
        task{cc}='loaddivclassifier';
        divclassifierpath=varargin{i+1};
        cc=cc+1;
    end
    
    if strcmp(varargin{i},'appenddivclassifier')
        task{cc}='appenddivclassifier';
        
        divclassifierpath=varargin{i+1};
        
        cc=cc+1;
    end
    
    if strcmp(varargin{i},'savedivclassifier')
        task{cc}='savedivclassifier';
        
        divclassifierpath=varargin{i+1};
        
        cc=cc+1;
    end
    
    if strcmp(varargin{i},'divclassify')
        task{cc}='divclassify';
        cc=cc+1;
    end
    
    
end


for i=1:numel(task)
    
    
    if numel(pixclassifierpath)==0
        pixclassifierpath=obj(i).pixclassifierpath;
    end
    if numel(objclassifierpath)==0
       objclassifierpath=obj(i).objclassifierpath;
    end
    if numel(divclassifierpath)==0
       divclassifierpath=obj(i).divclassifierpath;
    end
    
    % collect all new information and append
    if strcmp(task{i},'appendpixclassifier')
        for j=1:numel(obj)
            fprintf(['Pix: Gathering observation for movi ' num2str(j) ' / ' num2str( numel(obj)) '\n']);
            %fprintf(['Currently, N= ' num2str(obj(j).pixclassifier.NumObservations) ' observations\n']);
            obj(j).setpixclassifier(pixclassifierpath,'append')
        end
    end
    
     % collect all new information and append
    if strcmp(task{i},'appendobjclassifier')
        for j=1:numel(obj)
            fprintf(['Obj: Gathering observation for movi ' num2str(j) ' / ' num2str( numel(obj)) '\n']);
            %fprintf(['Currently, N= ' num2str(obj(j).pixclassifier.NumObservations) ' observations\n']);
            obj(j).setobjectclassifier(objclassifierpath,'append')
        end
    end
    
     % collect all new information and append
    if strcmp(task{i},'appenddivclassifier')
        for j=1:numel(obj)
            fprintf(['Div: Gathering observation for movi ' num2str(j) ' / ' num2str( numel(obj)) '\n']);
            %fprintf(['Currently, N= ' num2str(obj(j).pixclassifier.NumObservations) ' observations\n']);
            obj(j).setdivclassifier(divclassifierpath,'append')
        end
    end
    
    
    if strcmp(task{i},'savepixclassifier')
        %obj(1).setpixclassifier(pixclassifierpath,'save') % first save file
        
        for j=1:numel(obj)
            fprintf(['Pix: Gathering observation for movi ' num2str(j) ' / ' num2str( numel(obj)) '\n']);
            %fprintf(['Currently, N= ' num2str(obj(j).pixclassifier.NumObservations) ' observations\n']);
            obj(j).setpixclassifier(pixclassifierpath,'append')
        
        
        end
        
        %obj(j).pixclassifier
        
        if numel(obj(j).pixclassifier)~=0
        fprintf(['New pix training set with N= ' num2str(obj(j).pixclassifier.NumObservations) ' observations\n']);
        end
        
    end
    
    if strcmp(task{i},'saveobjclassifier')
        obj(1).setobjectclassifier(objclassifierpath,'save') % first save file
        
        for j=1:numel(obj)
            fprintf(['Obj: Gathering observation for movi ' num2str(j) ' / ' num2str( numel(obj)) '\n']);
            %fprintf(['Currently, N= ' num2str(obj(j).pixclassifier.NumObservations) ' observations\n']);
            obj(j).setobjectclassifier(objclassifierpath,'append')
         
        end
        
        if numel(obj(j).objclassifier)~=0
        fprintf(['New obj training set with N= ' num2str(obj(j).objclassifier.NumObservations) ' observations\n']);
        end
    end
    
     if strcmp(task{i},'savedivclassifier')
        obj(1).setdivclassifier(divclassifierpath,'save') % first save file
        
        for j=1:numel(obj)
            fprintf(['Div: Gathering observation for movi ' num2str(j) ' / ' num2str( numel(obj)) '\n']);
            %fprintf(['Currently, N= ' num2str(obj(j).pixclassifier.NumObservations) ' observations\n']);
            obj(j).setdivclassifier(divclassifierpath,'append')
         
        end
        
        if numel(obj(j).divclassifier)~=0
        fprintf(['New obj training set with N= ' num2str(obj(j).divclassifier.NumObservations) ' observations\n']);
        end
    end
    
     
    
    for j=ind
        fprintf(['Processing movi: ' num2str(j) ' / ' num2str( numel(obj)) '\n']);
        
        if strcmp(task{i},'identifyTraps')
            obj(j).pattern=pattern;
            obj(j).identifyTraps;
        end
        
        if strcmp(task{i},'fakeNuclei')
            obj(j).inputpoly=inputpoly;
            obj(i).fakeNuclei(1,inputpoly);
        end
        
        if strcmp(task{i},'loadpixclassifier')
           
            
            obj(j).setpixclassifier(pixclassifierpath,'load');
            
            if numel(obj(j).pixclassifier)~=0
            fprintf(['There are N= ' num2str(obj(j).pixclassifier.NumObservations) ' observations in the pix training set\n']);
            end
        end
        
        if strcmp(task{i},'appendpixclassifier')
            
            if numel(obj(j).pixclassifier)~=0
            obj(j).setpixclassifier(pixclassifierpath,'load') % load updated classifier for each position
            end
            
            fprintf(['Now, N= ' num2str(obj(j).pixclassifier.NumObservations) ' observations in the pix training set\n']);
        end
        
         if strcmp(task{i},'savepixclassifier')
            obj(j).setpixclassifier(pixclassifierpath,'load') % load updated classifier for each position
            
            if numel(obj(j).pixclassifier)~=0
            fprintf(['Now, N= ' num2str(obj(j).pixclassifier.NumObservations) ' observations in the pix training set\n']);
            end
        end
        
        
        if strcmp(task{i},'pixclassify')
            obj(j).pixclassify;
        end
        
        if strcmp(task{i},'loadobjclassifier')
            obj(j).setobjectclassifier(objclassifierpath,'load');
            
            if numel(obj(j).objclassifier)~=0
            fprintf(['There are N= ' num2str(obj(j).objclassifier.NumObservations) ' observations in the obj training set\n']);
            end
        end
        
        if strcmp(task{i},'appendobjclassifier')
            obj(j).setobjectclassifier(objclassifierpath,'load') % load updated classifier for each position
            
            if numel(obj(j).objclassifier)~=0
            fprintf(['Now, N= ' num2str(obj(j).objclassifier.NumObservations) ' observations in the obj training set\n']);
            end
        end
        
        if strcmp(task{i},'saveobjclassifier')
            obj(j).setobjclassifier(objclassifierpath,'load') % load updated classifier for each position
            
            if numel(obj(j).objclassifier)~=0
            fprintf(['Now, N= ' num2str(obj(j).objclassifier.NumObservations) ' observations in the obj training set\n']);
            end
        end
        
        
        if strcmp(task{i},'objclassify')
            obj(j).objectclassify;
        end
        
        if strcmp(task{i},'computefluo')
            for k=1:numel(obj(j).trap)
             obj(j).trap(k).computefluo;
            end
        end
        
        if strcmp(task{i},'loaddivclassifier')
            obj(j).setdivclassifier(divclassifierpath,'load');
            
            if numel(obj(j).divclassifier)~=0
            fprintf(['There are N= ' num2str(obj(j).divclassifier.NumObservations) ' observations in the div training set\n']);
            end
        end
        
        if strcmp(task{i},'appenddivclassifier')
            obj(j).setdivclassifier(divclassifierpath,'load') % load updated classifier for each position
            
            if numel(obj(j).divclassifier)~=0
            fprintf(['Now, N= ' num2str(obj(j).divclassifier.NumObservations) ' observations in the obj training set\n']);
            end
        end
        
        if strcmp(task{i},'savedivclassifier')
            obj(j).setdivclassifier(divclassifierpath,'load') % load updated classifier for each position
            
            if numel(obj(j).divclassifier)~=0
            fprintf(['Now, N= ' num2str(obj(j).divclassifier.NumObservations) ' observations in the pix training set\n']);
            end
        end
        
        
        if strcmp(task{i},'divclassify')
            obj(j).divclassify;
        end
        
        
    end
    
end



