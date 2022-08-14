function paramout=deleteChannels(param,roiobj,frames)

 listChannels=listAvailableChannels;
% listChannels=['N/A', listChannels];
environment='pc' ;

if nargin==0
    paramout=[];
    
    tip={};
    cc=1;
    for i=1:numel(listChannels)
        tip{cc}= 'Check this box if this channel should be deleted'; cc=cc+1;
        paramout.(listChannels{i})=false;
    end

    paramout.tip=tip;
  
    return;
else
paramout=param; 
end

obj=roiobj;

args={};

f=fieldnames(param);

cha={};

for i=1:numel(f)-1
        pix=find(matches(listChannels,f{i}));

        if numel(pix)
                if param.(f{i})==true
                           cha=[cha listChannels{pix}];
                       
                end
        end
end

for i=1:numel(cha)
roiobj.removeChannel(cha{i});
end




