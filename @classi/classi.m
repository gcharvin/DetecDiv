classdef classi < handle
    properties
        id=[] % number that identifies the classification algo
        
        typeid=1; % default category for classification found the classilist.mat file in the classification folde
        trainingset=[]; % % list of ROI ids used for training
        path='' %  path where 
        strid='';
    end
    methods
        function obj = classi(path,name,id)
            
            if nargin<2
               name='myclassif'; 
               id=1;
            end
            % ask user which method he wants to use
            str=which('shallowNew.m');
            [pth file ext]=fileparts(str);
            str=[pth '/classification/classlist.mat'];
            load(str);
            disp(classlist)
            
            prompt='Please enter the number associated with the classification you wish to do ?';
            str= input(prompt);
            
            if str >0 && str< size(classlist,2)
            
            obj.typeid=str;
            obj.id=id;
            obj.strid=[name '_' num2str(id)];
            
            mkdir(path,'classification');
            obj.path=[path '/classification'];
            
            mkdir(obj.path,obj.strid);
            
            else
                disp('Error: wrong clasification umber entered !');
            return;    
            end
            %obj.path=mkdir(
        end
        
        function addTrainingData(obj,list)
           % list is provdided as a list  of FOVid x ROIs 
           % HERE add training data 
           obj.trainingset=list;
           
           % save roi dataset to local folder for training ?? --> make a
           % list of mat files corresponding to local ROIs 
           
           % update GUI to include classification capabilities
        end
        
    end
end
    