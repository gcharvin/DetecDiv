function processData(classiobj,roiobj,varargin)
% high level function to process data

% classiobj is a @classi obj
% roiobj is an array of @roi

% varargin :

% 'Frames': input an array of frame numbers or a cell array of frames with
% the same size as the array of @roi

% 'Progress' : specifiy a handle to a progree bar to be updated during
% classification

% 'Parallel' : usd for parallele computing


% results outputs the array of future objects with information about errors
% etc...


para=0;
frames=[];
p=[];

gpu=0;


for i=1:numel(varargin)

    if strcmp(varargin{i},'Frames') % is a cell array with the same number of elements as number of rois. If it s a numeric array, then apply to all rois
        frames=varargin{i+1};
    end

    if strcmp(varargin{i},'Progress') % update progress bar
        p=varargin{i+1};
    end

    if strcmp(varargin{i},'Parallel') % parallel computing
        para=1;
    end

     if strcmp(varargin{i},'GPU') % classify with GPU
        gpu=1;
    end
end

classi=classiobj;
classifyFun=classi.processFun;
fhandle=eval(['@' classifyFun]);
param=classi.processArg;

disp(['Prcoessing roi data using ' classifyFun]);

if numel(p)
    p.Value=0.1;
    p.Message='Preparing processing....';
end


if numel(p)
    p.Value=0.2;
    p.Message='Processor is loaded.';
end

disp([num2str(numel(roiobj)) ' ROIs to process, be patient...']);

if para
    logparf(1:numel(roiobj))= parallel.FevalFuture;
else

    logparf=1;
end


for i=1:numel(roiobj) %size(roilist,2) % loop on all ROIs using parrallel computing



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

        if fra~=-1
       % fra=intersect(fra,1:size(roiobj(i).image,4));
        else
          if numel(roiobj(i).image)==0
             roiobj(i).load;
          end

         fra=1:size(roiobj(i).image,4);
    %    fra=1:size(roiobj(i).image,4);
        end

        if numel(p)
            p.Value=0.9* double(i)./numel(roiobj);

            p.Message=['Processing ROI  ' roiobj(i).id];
        end

        % roiobj(i).classes=classi.classes;

        if para % parallel computing
                logparf(i)=parfeval(fhandle,2,param,roiobj(i),fra); % launch the training function for classification
        else
               [paramout,data,image]=feval(fhandle,param,roiobj(i),fra); % launch the training function for classification
                disp(['Classified' num2str(roiobj(i).id)]);

              ROIManagement(roiobj(i),image,data);
           
        end

  
end

if para % parallel computing
    disp('Waiting for job to complete...');
    if numel(p)
        p.Message='Waiting for job to complete...';
    end

%wait(logparf);

for i=1:numel(logparf)
 %   [results,image]=fetchOutputs(logparf(i));

    [idx,param,data,image]=fetchNext(logparf(i));


    ROIManagement(roiobj(idx),data);
%     roiobj(idx).results=results; 
% 
%     roiobj(idx).image=image; 
%     roiobj(idx).save
%     roiobj(idx).clear;

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


function ROIManagement(roiobj,image,data)

 roiobj.data=data; 
 roiobj.image=image; 
 roiobj.save('data'); 
 roiobj.clear,
%disp('You must save the shallow project to save these classified data !');