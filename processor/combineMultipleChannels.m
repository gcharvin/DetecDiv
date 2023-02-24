function paramout=combineMultipleChannels(param,roiobj,frames)


% listChannels=['N/A', listChannels];
environment='pc' ;

if nargin==0
     listChannels=listAvailableChannels;
    paramout=[];
    
    tip={};
    cc=1;
    for i=1:numel(listChannels)
       %
       %paramout
        tip{cc}= 'Check this box if this channel should be combined into a new channel'; cc=cc+1;
        paramout.(listChannels{i})=false;
        tip{cc}= 'Enter the RGB triplet for this channel in t the output channel eg: [1 0 0]; Discard if channel is not selected'; cc=cc+1;
        paramout.(['RGB_' listChannels{i}])=[0 0 0];
    end

    paramout.outputChannelName='CombinedChannel';
   tip{end+1}='Please enter the name of the output channel';

    paramout.listChannelName=[listChannels listChannels{end}];
   tip{end+1}='Do not edit';

    paramout.tip=tip;
  
    return;
else
paramout=param; 
end

obj=roiobj;

args={};

f=fieldnames(param);

listChannels=param.listChannelName(1:end-1);

cha={};
rgb={};

for i=1:numel(f)-1
        pix=find(matches(listChannels,f{i}));

        if numel(pix)
                if param.(f{i})==true
                           cha=[cha listChannels{pix}];
                            rgb=[rgb param.(f{i+1})];
                end
        end
end

roiobj.combineChannels('channels',cha,'rgb',rgb,'name',param.outputChannelName);

%roiobj.combineChannels({'channels',{'ch000-st000'    'ch000-st001'    'ch000-st002'},'rgb',{[1 0 0] [0 1 0] [0 0 1]}})



