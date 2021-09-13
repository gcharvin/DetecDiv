function pixresults=findChannelID(obj,str,option)

% returns the index of the channel with name str
% if option is provided, then list all channels with *at least * str in their name

pixresults=[];

pixe = strfind(obj.display.channel, str);
cc=[];

for j=1:numel(pixe)
    if numel(pixe{j})~=0
        test=obj.display.channel{j};
        
        if nargin==2
            if strcmp(test,str)
                cc=j;
                break
            end
        else % list all channels
            cc=[cc j];
        end
    end
end

if numel(cc)>0
    if nargin==2
        pixresults=find(obj.channelid==cc);
    else
        pixresults=[];
        for i=1:numel(cc)
        pixresults=[pixresults find(obj.channelid==cc(i))];
        end
    end
end

