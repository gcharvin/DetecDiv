function showDrift(obj,range)

% displays XY drift computed in saveCroppedImage function and computes the
% RMS

% range is an optional argument to indicate the frame interval to consider;
%   

if nargin==1
    range=1:numel(obj.drift.x);
end

x=obj.drift.x(range);
y=obj.drift.y(range);

figure; 
subplot(2,1,1);  plot( x ,'Color','r','LineWidth',2);
%xlabel('Frames');
ylabel('X Drift (pixels)');
title(['RMS =' num2str(std(x)) ' pixels']);

subplot(2,1,2); plot( y, 'Color','r','LineWidth',2);
ylabel('Y Drift (pixels)');
xlabel('Frames');
title(['RMS =' num2str(std(y)) ' pixels']);



