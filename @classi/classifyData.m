function logparf=classifyData(classiobj,roiobj,varargin)
% high level function to classify data

% classiobj is a @classi obj
% roiobj is an array of @roi

% varargin :

% 'Classifier'  : specify a valid classifier object

%'ClassifierCNN' : in case a cnn and an lstm are to be compared

% 'Frames': input an array of frame numbers or a cell array of frames with
% the same size as the array of @roi

% 'Channel' : a cell array of channel strings to be used as input for
% classification . If not provided, will use the channelName of the
% @classiObj
% The channel can have the same number of items as the @roi array. If only
% one item is provided, it will be used for

% 'Progress' : specifiy a handle to a progree bar to be updated during
% classification

% 'Parallel' : usd for parallele computing


% results outputs the array of future objects with information about errors
% etc...

%'Classifier' uses a classifier provdied as input

para=0;
frames=[];
p=[];
channel=[]; %classiobj.channelName;
classifierCNN=[];
classifier=[];
CNNflag=0;
roiwithgt=0;
goclassif=1;
gpu=0;


for i=1:numel(varargin)
    if strcmp(varargin{i},'Classifier')
        classifier=varargin{i+1};
    end
    if strcmp(varargin{i},'ClassifierCNN')
        % classifierCNN=varargin{i+1};
        CNNflag=1;
    end

    if strcmp(varargin{i},'Frames') % is a cell array with the same number of elements as number of rois. If it s a numeric array, then apply to all rois
        frames=varargin{i+1};
    end

    if strcmp(varargin{i},'Progress') % update progress bar
        p=varargin{i+1};
    end

    if strcmp(varargin{i},'Channel') % specify a different channel to classify
        channel=varargin{i+1}; % channel is a cell array with the same size as the number of rois; if not, will apply the same number to all ROIs
    end

    if strcmp(varargin{i},'Parallel') % parallel computing
        para=1;
    end

    if strcmp(varargin{i},'RoiWithGT') % classify only ROIs and frames that have a groundtruth available
        roiwithgt=1;
    end

     if strcmp(varargin{i},'GPU') % classify with GPU
        gpu=1;
    end
end

classifierStore=classifier;

classi=classiobj;
classifyFun=classi.classifyFun;
fhandle=eval(['@' classifyFun]);

disp(['Classifying roi data using ' classifyFun]);

if numel(p)
    p.Value=0.1;
    p.Message='Preparing classification....';
end

mustload=0;
if numel(classifier)==0
    mustload=1;
end

if CNNflag==1
    str=fullfile(classi.path,['netCNN_' classi.strid '.mat']);
    if exist(str)
        load(str);
        disp(['Loading CNN classifier: ' str]);
        classifierCNN=classifier;
    else
        classifierCNN=[];
    end
else
    classifierCNN=[];
end

if mustload==1
    disp(['Loading classifier: ' classi.strid]);
    % str=[path '/' name '.mat'];
    classifier=[];
    classifier=classi.loadClassifier('force'); % to prevent pb if classifier is already loaded in the workspace
    classifierStore=classifier;

    if numel(classifierStore)==0
        disp('could not load main classifier.... quitting');
        %%
        return;
    end
end


if numel(p)
    p.Value=0.2;
    p.Message='Classifier is loaded.';
end

disp([num2str(numel(roiobj)) ' ROIs to classify, be patient...']);

if para
    logparf(1:numel(roiobj))= parallel.FevalFuture;
else

    logparf=1;
end


for i=1:numel(roiobj) %size(roilist,2) % loop on all ROIs using parrallel computing

    if roiwithgt==1 % checks if goclassif truth data are avaiable for this ROI, otherwise skips the ROI
        switch classif.category{1}
            case 'Pixel' % pixel classification


                ch= roiobj(i).findChannelID(classif.strid);

                if numel(ch)>0 % groundtruth channel exists
                    % checks if at least one image has been annotated  first!

                    if numel( roiobj(i).image)==0 % loads the image
                        roiobj(i).load;
                    end

                    im= roiobj(i).image;
                    fram=1:size(im,4);

                    imch=im(:,:,ch,:);

                    if sum(imch(:))>0 % at least one image was annotated
                        goclassif=1;
                        flag=[];
                        for f=fram
                            if max(max(imch(:,:,1,f)))>0 %takes only frames with cells annotated
                                flag=[flag, f];
                            end
                        end
                        % frames=flag;%frames to classify - disabled to
                        % classify all frames

                    else
                        goclassif=0;
                    end
                end

            otherwise % image classification
                classistr=classif.strid;
                % if roi was used for user training, display the training data first
                if numel( roiobj(i).train)~=0
                    if isfield(roiobj(i).train,classistr)
                        if numel(roiobj(i).train.(classistr).id) > 0
                            if sum(roiobj(i).train.(classistr).id)>0 ||  ( numel(roiobj(i).train.(classistr).id)==1 && ~isnan(roiobj(i).train.(classistr).id))  % training exists for this ROI ! put a condition if there is only one element
                                goclassif=1;
                            else
                                goclassif=0;
                            end
                        end
                    end
                end
        end
    end

    if goclassif==1

        if numel(roiobj(i).image)==0
            roiobj(i).load;
        end

        fra=1:size(roiobj(i).image,4);

        if numel(frames)>0
            if iscell(frames)
                if numel(frames)>=i
                    fra=frames{i};
                end
            else
                fra=frames;
            end
        end

        % check that the requested number of frames is compatible with that of
        % the roi

        fra=intersect(fra,1:size(roiobj(i).image,4));


        if numel(channel)==0
            cha=classiobj.channelName;
        else
            cha=channel{i};
        end

        if numel(p)
            p.Value=0.9* double(i)./numel(roiobj);

            p.Message=['Classifying ROI  ' roiobj(i).id];
        end

        % roiobj(i).classes=classi.classes;

        if para % parallel computing
            if numel(classifierCNN)
                if numel(roiobj(i).image)==0
                 roiobj(i).load;
                end
                logparf(i)=parfeval(fhandle,2,roiobj(i),classi,classifierStore,'classifierCNN',classifierCNN,'Frames',fra,'Channel',cha,'Exec',gpu); % launch the training function for classification
            else
                 if numel(roiobj(i).image)==0
                 roiobj(i).load;
                 end

                %disp(['Starting classification of ' num2str(roiobj(i).id)]);
                logparf(i)=parfeval(fhandle,2,roiobj(i),classi,classifierStore,'Frames',fra,'Channel',cha,'Exec',gpu); % launch the training function for classification
            end
        else
            if  numel(classifierCNN)
                [results,image]=feval(fhandle,roiobj(i),classi,classifierStore,'classifierCNN',classifierCNN,'Frames',fra,'Channel',cha,'Exec',gpu); % launch the training function for classification
                disp(['Classified with separate CNN ' num2str(roiobj(i).id)]);
            else
               [results,image]=feval(fhandle,roiobj(i),classi,classifierStore,'Frames',fra,'Channel',cha,'Exec',gpu); % launch the training function for classification
                disp(['Classified' num2str(roiobj(i).id)]);
            end

            roiobj(i).results=results; 
            roiobj(i).image=image; 
            roiobj(i).save; 
            roiobj(i).clear,
        end

    elseif goclassif==0
        disp(['There is no groundtruth available for roi ' num2str(roiobj(i).id) ' , skipping roi...']);
    end
end


% if para  % not implemented
%     maxFuture = afterEach(logparf, @(r) max(r), 1);
%
%     minFuture = afterAll(maxFuture, @(r) min(r), 1);
%
% end

% HERE : parallel mode works but not the serial mode !!!!!

if para % parallel computing
    disp('Waiting for job to complete...');
    logparf
    if numel(p)
        p.Message='Waiting for job to complete...';
    end
wait(logparf);

for i=1:numel(logparf)
    [results,image]=fetchOutputs(logparf(i));

    roiobj(i).results=results; 

    roiobj(i).image=image; 
    roiobj(i).save
    roiobj(i).clear;

 %   aa=results.my_classi_1.id
    % here image is empty !!!!
  %  roiout.save; 
  %  roiout.clear,
end
end

if numel(p)
    p.Value=0.9;
    p.Message='Saving project...Please wait...';
end



%disp('You must save the shallow project to save these classified data !');
