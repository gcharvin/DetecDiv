function set(obj,stringid,varargin)
% this function calls operations to pe performed on the classification 

if nargin==1 | strcmp(stringid,'help')
    disp('You must provide a string argument to perform an operation:')
    disp('--------------------------------');
    disp('init : defines the properties of the classi objects')
%    disp('classes : sets the clasnames of the classification object ')
    disp('roi : adds ROIs to the classi object');
    disp('param : sets the training parameters');
    disp('gt : annotates ROI  - sets the groundtruth');
    disp('training : trains the classifier');
 %   disp('classifier : loads the classifier');
    disp('validation : applies classifier results to ROIs');
    disp('stats: Compute statistics and comparison between groundtruth and classification results');
    disp('movie : exports ROIs to .avi movie')
    disp('repository : exports classi object');
    
    
    return
end


switch stringid
    case 'init'
        obj.init;
     
    case 'roi'
        obj.addROI(varargin);
        
    case 'param'
        obj.setTrainingParam; 
        
    case 'gt'
        obj.userTraining(varargin);
        
    case 'training'
        obj.trainClassifier;
          
    case  'validation'
        obj.validateTrainingData;
        
    case 'stats'
        obj.stats;
        
    case 'movie'
        obj.export(varargin);
        
    case 'repository'
        obj.repository;
        
end
