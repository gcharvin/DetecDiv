classdef roi < handle
    properties
        % default properties with values
        id='';
        value %
        %gfp % list of grayscale images that contain gfp data (m x n x time x channel)
        %gfpchannel
        %phasechannel
        path
        %intensity=0.2; % intensity of fluoresecence displayed on view gui
        %brushSize=3;
        %phc % list of grayscale images that contain ph data

        image=[]; % . images for field of view
        channelid=1;
        % imagestr={}; % contains the description for each image
        proc=[]; % sturct that contains all possible prcessing data

        parent=[] % reference of the parent field of view

        display=struct('intensity',[1 1 1],'frame',1,'selectedchannel',1,'binning',1,'rgb',[1 1 1],'channel',{'Channel 1'},'stretchlim',[],'displaylim',[0 1]);

        % stretchlim : is the levels used to perform preprocessing
        % displaylim are the levels used to display the images

        history=table('Size',[1 3],'VariableTypes',{'datetime','string','string'},'VariableNames',{'Date','Category','Message'});

        classes={};
        train=[] ; %1D array that has the size of the 4rd dim of the image array and contains assigned classes; is defined when ROI is assigned to classification

        results=[]; %display results if based on classification-> an array that has the same size as the number of frames

        data=dataseries; % array of dataseries objects

        % displays a list of channels in RGB channels
        %train=[] % list of rgb images that contain pixel training data
        %classi=[] % list of rgb images that contain pixel classification RGB image , only second channel is useful
        %traintrack=[]; % list of grayscale images that contains training for nucleus tracking results
        %track=[] % array that contains 1) the nucleus index to be tracked (classification result) : 0 if no tracking 2) other information related to tracking : division etc...

        %cavity=[]; % geometrical information avout cavity
        %area=[]; % area of nucleus in trajectory NOT USED
        %param=[]; % predictors used ? NOT USED

        %data=struct('fluo',[],'area',[]);
        %data.fluo=[]; % quantification of total fluorescence in mother nucleus

        %rls=[];

        %div=struct('reject',[],'raw',[],'classi',[],'tree',[],'dead',[],'daughter',[],'stop',[]) % structure that contains all relevant info about division, including training and classification

        %frame=1; %current frame being displayed;
        %pixtree % pix classifier
        %objtree % object trajectory classifier
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
            %  obj.gfp=gfp;
            %obj.phc=phc;

            %obj.classi=uint8(zeros(size(gfp,1),size(gfp,2),3,size(gfp,3)));
            %obj.train= uint8(zeros(size(gfp,1),size(gfp,2),3,size(gfp,3)));
            %obj.traintrack= uint8(zeros(size(gfp,1),size(gfp,2),3,size(gfp,3)));
            %obj.track= uint8(zeros(size(gfp,1),size(gfp,2),size(gfp,3)));
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

