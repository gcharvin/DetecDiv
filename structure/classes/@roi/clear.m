function clear(obj)

% remove attached variables from main movie project.

obj.normalizeDisplayCache();
obj.image = [];
obj.data = dataseries;

obj.log('Image was cleared off', 'Saving');

% obj.classi=[];
% obj.train=[];
% obj.traintrack=[];
% obj.track=[];
end
