classdef roi < handle
    properties
        id=''; % name of the ROI
        value % indicates the x, y, width height of the ROI in the original image
        path % indicates the absolute path of the image to be loaded with load() method
        image=[]; % 4-D image of the roi : x, y, channel, time
        channelid=1; % nx1 array of numbers that indicates how the channels are organized within the image; exemple : channelid: [1 1 1 2 3 4 5 6] means that the first channel is composed of 3 subchannels, and there are 6 channels in total
        parent=[] % reference of the parent field of view
        display=struct('intensity',[1 1 1],'frame',1,'selectedchannel',1,'binning',1,'rgb',[1 1 1],'channel',{'Channel 1'},'stretchlim',[],'displaylim',[0 ; 1]);

        % display struct structure : 
        % intensity: nx3 array, n is the number of channels; if all 3
        % elements are 0 for a given channel, then image is an indexed
        % image ; could be used t indicates the weight of an image. 
        % frame : current time frame to be displayed within the 4-D image
        % selectedchannel : nx1 array, n is the number of channels . If element == 1, then channel should be displayed, otherwise not. 
        %binning : n x 1 array, n is the number of channels. Indicats the binning number of the image 
        % rgb : n x 3 array, n is the number of channels, indicates the
        % color to use for display
        % channel : 1xn cell array of string; indicates the channel name; 
        %stretchlim : n x 2 array that indicates how the image limit are
        %computed before processing
        % displaylim : n x 2 array that indicates how the image limits are
        % computed 



        history=table('Size',[1 3],'VariableTypes',{'datetime','string','string'},'VariableNames',{'Date','Category','Message'});

        %unused properties : 
        proc=[];
        classes={};
        train=[] ; 
        results=[];

        data=dataseries; % array of dataseries objects

    end
    methods
        function obj = roi(id,roiarr)
            %%%% here
            if nargin==0
                id='';
                roiarr=[];
            end

            obj.id=id;
            obj.value=roiarr;
        end

        function dataout=getData(roiobj,str)

            if numel(roiobj.data)==0 || (numel(roiobj.data)==1 && numel(roiobj.data(1).data)==0)
                roiobj.load('data');
            end

            if nargin==2
                switch class(str)
                    case "char"
                        pixdata=find(arrayfun(@(x) strcmp(x.groupid, str),roiobj.data)); % find if object exists already
                    case "uint8"
                        pixdata=str;
                    case "uint16"
                        pixdata=str;
                    case "double"
                        pixdata=str;
                    otherwise
                        disp('please specificy a valid argument!');
                        dataout=[];
                        return;
                end

                if numel(pixdata)
                    dataout=roiobj.data(pixdata);
                else
                    dataout=[];
                    disp('Could not find those data in the ROI')
                end
            else
                t={};

                for i=1:numel(roiobj.data)
                    t{i,1}=i;
                    t{i,2}=roiobj.data(i).groupid;
                    t{i,3}=roiobj.data(i).type;
                    t{i,4}=roiobj.data(i).class;
                end

                t=cell2table(t);
                t.Properties.VariableNames={'Index' 'Groupid' 'Type' 'Class'};
                disp(t)
                dataout=roiobj.data;
            end
        end

        function [dataout, labelout]=getTrainingData(roiobj,classistr)

            dataout=[];
            labelout=[];

            if numel(roiobj.data)==0 || (numel(roiobj.data)==1 && numel(roiobj.data(1).data)==0)
                roiobj.load('data');
            end

           pixdata=find(arrayfun(@(x) strcmp(x.groupid, classistr),roiobj.data)); % find if object exists already
            
           datas=roiobj.data(pixdata);

           if numel(find(matches(datas.data.Properties.VariableNames,'id_training')))
           dataout=datas.data.('id_training');
           end
           if numel(find(matches(datas.data.Properties.VariableNames,'labels_training')))
           labelout=datas.data.('labels_training');
           end
        end
         function setTrainingData(roiobj,classistr,id)

            dataout=[];
            labelout=[];

            if numel(roiobj.data)==0 || (numel(roiobj.data)==1 && numel(roiobj.data(1).data)==0)
                roiobj.load('data');
            end

           pixdata=find(arrayfun(@(x) strcmp(x.groupid, classistr),roiobj.data)); % find if object exists already
            
           datas=roiobj.data(pixdata);

           crea=0;
           if numel(datas)==0
            crea=1;
            datas=dataseries;
           else
            if numel(find(matches(datas.data.Properties.VariableNames,'id_training')))==0
                crea=1;
            end
           end

          if crea==0
           datas.data.('id_training')=id;
           classess=datas.data.userData.classes;
           categoryArray = categorical(id, 1:numel(classess), classess);
           datas.data.('labels_training')=id;
           else % create new training set
                 if numel(roiobj.image)==0 
                     roiobj.load,
                 end

                 sz=size(roiobj.image,4);
                 datas.addData(zeros(sz,1),{'id_training'},'group',{'id'});
           end

           
         end


        function hp=getTrainingHandle(roiobj,classistr)

            hp=[];
            htraj=findobj('Type','Figure');
            for j=1:numel(htraj)

                z= htraj(j).Name;

                if contains(z,roiobj.id) && contains(z,classistr)
                    
                    li=findobj(htraj(j),'Tag',[roiobj.id '_track']);

                    if numel(li)==0
                        continue
                    end

                    hp=findobj(htraj(j),'Tag','labels_training');
                end
            end

        end
    end
end

