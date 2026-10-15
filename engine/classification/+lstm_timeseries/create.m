function c = create(parentFolder, name, id, classes)
%CREATE Independent classifier ready for ROI import in classifierGUI.
if nargin<2||isempty(name),name='numeric_state';end
if nargin<3||isempty(id),id=1;end
if nargin<4,classes={};end
target=fullfile(parentFolder,[char(string(name)) '_' num2str(id)]);
assert(~isfolder(target),'lstm_timeseries:AlreadyExists','Refuse to replace an existing classifier: %s',target);
c=classi(parentFolder,char(string(name)),id);
lstm_timeseries.ensureClassMetadata(c);c.trainingParam=lstm_timeseries.setparam();
c.classes=cellstr(string(classes(:).'));c.colormap=shallowColormap(max(1,numel(c.classes)));
c.channel=[];c.channelName={};c.output=0;c.dataset.classes=c.classes;c.dataset.channels={};
c.executionParam=struct('outputName',c.strid,'executionEnvironment','module_default');
end
