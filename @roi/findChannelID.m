function pixresults=findChannelID(obj,str)

pixresults=[];

pixe = strfind(obj.display.channel, str);
        cc=[];
        for j=1:numel(pixe)
            if numel(pixe{j})~=0
                test=obj.display.channel{j};
                
                if strcmp(test,str)
                cc=j;
                break
                end
            end
        end           

if numel(cc)>0     
pixresults=find(obj.channelid==cc);
end

