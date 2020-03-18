function inheritProject(projectin, projectout)
% this function transmits information from one project to another 

load(projectin) % loads mov variable into memory 

movtemp=mov(1); 

load(projectout) %load mov variable into memory

for i=1:numel(mov)
   % mov(i).filename=movtemp.filename;
   % mov(i).pathname=movtemp.pathname;
    mov(i).GFPChannel=movtemp.GFPChannel;
    mov(i).PhaseChannel=movtemp.PhaseChannel;
    mov(i).pattern=movtemp.pattern;      
    mov(i).imsize=movtemp.imsize;             
    mov(i).nframes=movtemp.nframes;   
    mov(i).pixclassifier=movtemp.pixclassifier; 
    mov(i).pixclassifierpath=movtemp.pixclassifierpath;  
    mov(i).objclassifier=movtemp.objclassifier; 
    mov(i).objclassifierpath=movtemp.objclassifierpath; 
    mov(i).divclassifier=movtemp.divclassifier;   
    mov(i).divclassifierpath=movtemp.divclassifierpath;

end

eval(['save ' projectout ' mov']);