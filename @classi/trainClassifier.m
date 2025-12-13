function trainClassifier(classif, setparam)
% trainClassifier  Entry point for classifier training and parameter init.
%
% nargin == 1 : launch actual training
% nargin == 2 : initialize / set training parameters

trainingFun = classif.trainingFun;

if nargin == 1
    disp(['Launching training procedure with ' trainingFun]);

    % ============================================================
    % START RUN (TRAINING)
    % ============================================================
    classif.runStart(trainingFun, classif.trainingParam, 'Tag', 'Train');
    classif.runMsg('trainClassifier started (nargin=1)');
    classif.runMsg('Classifier: %s', classif.strid);

    try
        % --- Actual training ---
        feval(trainingFun, classif);

        classif.runMsg('Training finished successfully');

        try
            classif.runCopyArtifacts();
        catch ME
            classif.runMsg('WARN runCopyArtifacts failed: %s', ME.message);
        end

    catch ME
        % --- Log error with full stack ---
        classif.runMsg('ERROR during training:');
        classif.runMsg('%s', ME.getReport('extended','hyperlinks','off'));

        classif.runStop();
        rethrow(ME);
    end

    % ============================================================
    % STOP RUN
    % ============================================================
    %classif.runStop();

else
    disp(['Setting parameters for ' trainingFun]);

    % ============================================================
    % PARAMETER INITIALIZATION
    % ============================================================
    feval(trainingFun, classif, setparam);

    % Backward compatibility: ensure transfer_learning exists
    if ~isfield(classif.trainingParam,'transfer_learning')
        [t,~] = classif.version;
        str = t(:,1);
        str = ['ImageNet', str', 'ImageNet'];

        classif.trainingParam.transfer_learning = str;
        classif.trainingParam.tip{end+1} = ...
            'Select version of the classifier to be used';
    end

    % ============================================================
    % LOG PARAMETERIZATION AS A RUN (LIGHTWEIGHT)
    % ============================================================
    classif.runStart(trainingFun, classif.trainingParam, 'Tag', 'InitParam');
    classif.runMsg('Training parameters initialized (nargin=2)');
    classif.runMsg('Saved trainingParam snapshot');

    % Optional but useful for diffing runs
    classif.runSaveStruct('trainingParam.mat', classif.trainingParam);

    classif.runStop();
end
end
