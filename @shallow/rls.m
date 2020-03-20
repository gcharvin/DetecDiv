function rls(obj, listoftraps)

% plot rls for selected traps. If no arguments, all traps are plotted

if nargin<=1
    listoftraps=1:numel(obj.trap);
end

rls=[];
rls.div=[];
rls.sep=[];
rls.fluo=[];
rls.ndiv=[];
rls.totaltime=[];
rls.rules=struct('check',1,'test',-1,'frames',3);
rls.trap=[];

% div: [1×13 double]
%           sep: []
%          fluo: []
%          trap: []
%          ndiv: 13
%     totaltime: [1×13 double]
%         rules: [1×5 struct]
        

fprintf('Collect individual RLS\n');
cc=1;

for i=listoftraps
   fprintf('.');
   %obj.trap(i).cleartraining;
   %obj.trap(i).plotrls([],0);
   obj.trap(i).plotrls;
   
   if obj.trap(i).rls.ndiv<5
       continue
   end
   
 %  aa=obj.trap(i).rls
   
   rls(cc)=obj.trap(i).rls;
   rls(cc).trap=obj.trap(i).id;
   
   
   if mod(cc,50)==0
      fprintf('\n'); 
   end
   
   cc=cc+1;
   
   
end

param=setparam;

fprintf('\n Plotting RLS\n');

hrls=plotRLS([],rls,param);



function param=setparam

    param=[];
    
 l=linspace(0.15,0.85,256);
cmap2=zeros(256,3);
cmap2(:,2)=(fliplr(l))';
cmap2(:,1)=(fliplr(l))';
cmap2(:,3)=(fliplr(l))';

    param.colormap=cmap2; % should be a colormap with 256 x 3 elements 
    
    param.colorbar=1 ; % or 1 if colorbar to be printed
    param.colorbarlegend='Division time (frames)'; 
    
    param.findSEP=0; % 1: use find sep to find SEP
    param.align=0; % 1 : align with respect to SEP
    param.time=0; %0 : generations; 1 : physical time
    param.plotfluo=0 ; %1 if fluo to be plotted instead of divisions
    param.gradientWidth=0;
    param.cellwidth=1;
    param.sepwidth=0.1; % separation between events
    param.sepcolor=[0 0 0];
    param.spacing=1.5; % separation between traces
    
    param.minmax=[8 8*3]; % min and max values for display;
    param.startY=0; % origin of Y axis for plot
    param.startX=0;
    param.figure=[];
    param.figure.Position=[100 100 1000 300];
    param.xlim=[];
    param.ylim=[];
    
    param.sort=1;
    
    