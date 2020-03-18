function analysis(obj,option)

% calculate readout regarding traps of given movie


% first extract distribution of division times

if strcmp(option,'division')
    % displays histogram fro all divisions in movie
    
m=[];
for i=1:numel(obj.trap)
    
   div=find(obj.trap(i).div.classi);
   div=diff(div);
   
   m=[m div];
end

m=10*m;
%bins=0:1:50;


figure, nhist(m,'binfactor',4);
title('All division times');
xlabel('Division time (min)')
ylabel('# Events');

text(300,100,['median=' num2str(median(m),2) 'min (N=' num2str(numel(m)) ')'],'FontSize',20);
set(gca,'FontSize',20);

end


if strcmp(option,'traj')
    % displays all trajectories in movie
    
end
    