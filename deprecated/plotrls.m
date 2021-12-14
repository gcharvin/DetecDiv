function plotrls(obj,varargin)
% calculate the RLS of a cell in a given trap and plot it , based on
% division analysis
% if axis handle is provided, RLS is plot in a given axis handle

plot=0;
handle=[];

fprintf(['Calculating RLS for trap ' obj.id '\n']);

% rultemp=struct('check',1,'test',-1,'frames',3);
% 
% 
% % check : whether rule should apply or not
% % test: whether the tested cell passed the test (1) or not (0); =-1 is the
% % check==0;
% % frames : parameters that specify over how many frames the rules should
% % apply
% % rules :
% 
% %1) number of consecutive dead divisions is large than n (n=3 ?) DONE
% 
% %2) cell is no longer within mov.trap.data.cavity polygo defined during n
% %consecutive divisions n> 5 ?  DONE
% 
% %3) mean division timing is to high --> cutoff DONE
% % trap 3 in pos1 180316 is a problem
% % in this case discard the cell
% 
% %4) mother cell replacement by daughter : isfirst variable goes to 0,
% %dist to 0 and cavity to 0 but not necessarily for a number of consecutive frames > 3 ?
% % trap 4
% 
% %5) division smoothing : if long disivions is surrounded by short division
% % --> possible loss of division event ??? DONE
% 
% %6) no nucleus and dist=0 during a long time
% 
% rules=rultemp;
% 
% for i=1:5
%     rules(i)=rultemp;
% end
% 
% %
% rules(1).frames=3; % if 3 consecutive dead division --> dead
% rules(2).frames=5; % if 5 frames with cells out of cavity --> dead
% rules(5).frames=1.5; % scale factor for abnormal divisions
% rules(3).frames=10; % cutoff division timining : if division timing is longer than 10 frames, then rls should be discarded
% 
for i=1:numel(varargin)
    if strcmp(varargin{i},'plot')
        plot=1;
    end
    if strcmp(varargin{i},'handle')
        handle=varargin{i+1};
    end
    
    if strcmp(varargin{i},'rules') % input own rules
        rules=varargin{i+1};
    end
    
end
% 
% [divtime,rules]=checkrules(obj,rules);

deepLSTM=obj.div.deepLSTM;
ddeep=diff(deepLSTM);

pix=find(ddeep<0);
divtime=diff(pix);


% plot rls as a trajectory

param=setparam(obj);

rls.div=divtime;
rls.sep=[];
rls.fluo=[];
rls.trap='';
rls.ndiv=numel(divtime);
rls.totaltime=cumsum(divtime);
rls.rules=[];

if numel(pix)>0
param.startX=pix(1);
else
param.startX=0;    
end

obj.rls=rls;


if numel(divtime)==0
    return
end

if plot==1
    if numel(handle)==0
        handle=figure;
    end
 
    plotRLS(handle,rls,param);
end


% function [divtime , rules]=checkrules(obj,rules)
% 
% %default RL is based on div classification result
% divpos=find(obj.div.classi==1);
% 
% if numel(divpos)==0
%     fprintf('no division found : either object is crap, or div were not classified !\n');
%     divtime=[];
%     return;
% end
% 
% divtime=diff(divpos);
% lastdiv=divpos(end);
% 
% i=1;% more than n "dead" division in a row
% 
% if rules(i).check==1
%     
%     totdiv=find(obj.div.raw);
%     dead=obj.div.dead(totdiv);
%     
%     [l n]=bwlabel(dead);
%     
%     ok=0;
%     for j=1:n
%         pix=l==j;
%         
%         if sum(pix)>=rules(i).frames % number of consecutive dead divisions is larger than 2
%             ok=1;
%             break;
%         end
%     end
%     
%     if ok==1 % set of dead divisions
%        % pix
%         pix=find(pix==1,1,'first');
%         div=totdiv(pix-1);
%         %div=pix-1;
%         rules(i).test=0;
%     else
%         div= totdiv(end); % lateest division found
%         %div=numel(totdiv);
%         rules(i).test=1;
%     end
%     
%     lastdiv=div;
%     %divpos=find(obj.div.classi(1:div)==1);
%     %divtime=diff(divpos);
%     % divtime=0;
% else
%     rules(i).test=-1;
% end
% 
% %lastdiv
% 
% i=2;
% 
% if rules(i).check==1
%     
%     totdiv=find(obj.div.raw);
%     
%     [l n]=bwlabel(~obj.data.incavity);
%     
%     ok=0;
%     for j=1:n
%         pix=l==j;
%         
%         if sum(pix)>=rules(i).frames & find(pix==1,1,'first')>50 % number of consecutive frames with cell out of th ecavity larger than n , after frame 50
%             ok=1;
%             break;
%         end
%     end
%    
%     
%     if ok==1 % set of dead divisions
%         pix=find(pix==1,1,'first');
%         
%         div=find(obj.div.classi==1);
%         
%         last= find(div> pix,1,'first');
%         
%         if numel(last)==0
%         last=div(end);    
%         else
%         last=div(last-1);
%         end
%         
%         rules(i).test=0;
%     else
%         last= totdiv(end); % latest division found
%         rules(i).test=1;
%     end
%     
%         lastdiv=min(lastdiv,last);
% else
%     rules(i).test=-1;
% end
% 
% %divtime
% %lastdiv
% 
% i=3; % remove cells with division timing too high
% 
% if rules(i).check==1
%     %mean(divtime(1:10))
%     
%     madiv=min(length(divtime),10);
%     
%     if mean(divtime(1:madiv))>=rules(3).frames % first 10 divisions are too large
%       %  'ok'
%        rules(i).test=0; 
%     else
%        rules(i).test=1; 
%     end
% else
%     rules(i).test=-1;
% end
% 
% i=4; %removes cells that are replaced by their daughters
% 
% if rules(i).check==1
%     
%     totdiv=find(obj.div.raw);
%     
%     %[l n]=bwlabel(~obj.data.incavity);
%     
%     ok=0;
%     
%     for j=1:length(obj.data.incavity)
% %         if  j==199
% %            % aa=obj.data.isfirst(j)
% %            % bb=obj.data.dist(j)
% %            % cc=obj.data.incavity(j)
% %         end
%         if obj.data.incavity(j)==0 && obj.data.isfirst(j)==0 && obj.data.dist(j)==0 && j>50 % %number o larger than n , after frame 50
%             
%             ok=1;
%             break;
%         end
%     end
%    
%     
%     if ok==1 % set of dead divisions
%         
%         div=find(obj.div.classi==1);
%         
%         last= find(div> j,1,'first');
%         
%         if numel(last)==0
%         last=div(end);    
%         else
%         last=div(last-1);
%         end
%         
%         rules(i).test=0;
%     else
%         last= totdiv(end); % latest division found
%         rules(i).test=1;
%     end
%     
%         lastdiv=min(lastdiv,last);
% else
%     rules(i).test=-1;
% end
% 
% %divtime
% %lastdiv
% 
% %
% divpos=find(obj.div.classi(1:lastdiv)==1);
% divtime=diff(divpos);
% %
% 
% i=5; % division smoothing
% 
% if rules(i).check==1
%     ok=0;
%     cc=1;
%     
%     while ok==0
%         for j=2:numel(divtime)-1
%             mea=0.5*(divtime(j+1)+divtime(j-1));
%             
%             if divtime(j)>=rules(i).frames*mea % division was missing --> adding ghost division to fil up gap
%                 n=round(divtime(j)/mea);
%                 divtime=[divtime(1:j-1) mea*ones(1,n) divtime(j+1:end)];
%                 %ok=0;
%                 
%                 rules(i).test=0;
%                 break;
%                 
%             end
%         end
%         
%         cc=cc+1;
%         
%         if cc==10
%             ok=1;
%         end
%     end
% else
%     rules(i).test=-1;
% end



function param=setparam(obj)

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
param.time=1; %0 : generations; 1 : physical time
param.plotfluo=0 ; %1 if fluo to be plotted instead of divisions
param.gradientWidth=0;
param.cellwidth=1;
param.sepwidth=1;

if param.time==0
    param.sepwidth=0.1; % separation between events
end

param.sepcolor=[0 1 0];
param.spacing=1.5; % separation between traces

param.minmax=[9 9*3]; % min and max values for display;
param.startY=0; % origin of Y axis for plot

param.startX=find(obj.div.classi==1,1,'first');


if param.time==0
    param.startX=0;
end

param.figure=[];
param.figure.Position=[100 100 1000 300];
param.xlim=[];
param.ylim=[];
param.sort=0;
