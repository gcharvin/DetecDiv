function [paramout, dataout, image]=core(param,roiobj,frames)
% computeRLS.core  Convert cell-state classifier output into RLS events.
%
% Input
% -----
% param.classification_data:
%   Selector for the classifier dataseries to read, typically 'div_1'.
%   Legacy GUI calls may provide this as a cell array with the selected
%   value in the last cell. Pipeline calls may provide it directly as char
%   or string. The selected dataseries must contain an 'id' column and,
%   when available, 'prob_<class>' columns.
%
% param.AverageFluoByDivision:
%   Optional logical flag. When true, computeRLS averages frame-level
%   computeMetrics dataseries over each RLS division/generation interval.
%   When false, only RLS event/status/QC columns are generated.
%
% param.metrics_data:
%   Optional selector for computeMetrics dataseries to aggregate. '<auto>'
%   uses the standard computeMetrics outputs: 'channel_quantification' and
%   all dataseries whose groupid contains 'mask_quantification'. A concrete
%   dataseries name can be used to aggregate only that metric source.
%
% param.ArrestThreshold:
%   Arrest threshold. When ExpectedDivisionPeriod = P is set, this is a
%   number of expected division periods and the active threshold is
%   round(ArrestThreshold * P). When ExpectedDivisionPeriod is empty/NaN,
%   this is interpreted as an absolute frame count.
%
% param.DeathThreshold:
%   Minimum run length of the 'dead' class needed to validate death, except
%   when death reaches the last frame or is followed by empty.
%
% param.ClogThreshold:
%   Minimum run length of the 'clog' class needed to validate clogging.
%
% param.EmptyThresholdDiscard:
%   Legacy parameter kept for compatibility. It is not currently used by
%   this core logic.
%
% param.EmptyThresholdNext:
%   If an empty run occurs very early after birth, the code searches after
%   that empty run for the next possible birth/RLS.
%
% State decoding and event validation
% -----------------------------------
% param.StateDecoder:
%   Optional state decoder. 'off' keeps the legacy argmax behavior. 'median'
%   applies a majority filter to the argmax labels. 'viterbi' decodes the
%   full class-probability sequence with a constrained HMM/Viterbi pass.
%   The Viterbi decoder uses probabilities as emissions and biological
%   transition rules as priors: live states may cycle, live states may enter
%   death/clog/empty, dead and clog are absorbing, and empty may refill into
%   a live state to preserve the existing cavity-empty/refill workflow.
%
% param.ExpectedDivisionPeriod:
%   Expected budding/division period P in frames. If set and
%   MinDivisionInterval is not set, the minimum accepted interval between
%   consecutive budding events is P * MinDivisionIntervalFactor. It also
%   makes arrest detection use ArrestThreshold * P.
%
% param.MinDivisionInterval:
%   Explicit minimum accepted interval between consecutive budding events.
%   Events closer than this are rejected after decoding. Leave NaN to use
%   ExpectedDivisionPeriod * MinDivisionIntervalFactor, or to disable this
%   rule when ExpectedDivisionPeriod is also NaN.
%
% param.MinDivisionIntervalFactor:
%   Factor used with ExpectedDivisionPeriod. Default 0.5 implements the
%   "cannot divide faster than P/2" rule.
%
% param.MedianFilterWindow:
%   Window length for StateDecoder='median'.
%
% param.ViterbiLiveSwitchPenalty / ViterbiTerminalPenalty /
% param.ViterbiUnexpectedTransitionPenalty / ViterbiRefillPenalty:
%   Log-domain transition penalties used by StateDecoder='viterbi'. They
%   discourage implausible switches without changing the raw QC evidence.
%
% QC parameters
% -------------
% The classifier state is assigned by argmax. QC does not reject frames
% because the max probability is below a fixed threshold. Instead, it
% measures ambiguity between the two most probable classes:
%
%   margin(frame) = top1_probability(frame) - top2_probability(frame)
%
% param.QCLowMarginThreshold:
%   Frame-level ambiguity threshold. A frame is flagged ambiguous when
%   margin < QCLowMarginThreshold.
%
% param.QCMinMeanMargin:
%   Interval-level threshold. A RLS interval is accepted only when the mean
%   margin across the interval is at least QCMinMeanMargin.
%
% param.QCMaxLowConfidenceFraction:
%   Interval-level threshold on the fraction of ambiguous frames. Despite
%   the historical name, this is currently an ambiguity fraction:
%   mean(margin < QCLowMarginThreshold). A RLS interval is accepted only
%   when this fraction is <= QCMaxLowConfidenceFraction.
%
% Output dataseries
% -----------------
% The output dataseries groupid is ['RLS_' classification_data] for
% predictions and ['RLS_GT_' classification_data] for manual training data.
% It is always created when classifier labels are available, even if no
% division is detected.
%
% Historical columns:
%   event       - Birth, Budding, terminal status, or NeverBorn.
%   divduration - Frame distance between consecutive budding events.
%   totaltime   - Event frame in the original ROI time axis.
%   birth       - Generation count from birth.
%   death       - Reverse generation count toward terminal event.
%   sep         - Optional senescence entry point alignment if computable.
%
% Status/QC columns:
%   status               - ROI status: stillAlive, noDivision, death,
%                          arrest, clog, emptied, neverBorn.
%   usable               - ROI-level logical combining structural status and
%                          interval QC.
%   reason               - Human-readable reason for usable=false or status.
%   nDiv                 - Number of detected budding events, preserving the
%                          legacy start-after-bud-emergence correction.
%   frameBirth/frameEnd  - Birth and terminal frames used by RLS detection.
%   endType              - Terminal condition from the state sequence.
%   decoder              - State decoder used for event calling.
%   minDivisionInterval  - Active minimum interval between budding events.
%   arrestThreshold      - Active arrest threshold in frames. It is
%                          ArrestThreshold * ExpectedDivisionPeriod
%                          when ExpectedDivisionPeriod is set, otherwise
%                          the ArrestThreshold frame count.
%   nRejectedDivisions   - Number of candidate budding events rejected by
%                          the minimum-interval rule.
%   qc_mean_confidence   - Mean top1 probability on the interval; diagnostic
%                          only, not thresholded.
%   qc_min_confidence    - Minimum top1 probability on the interval;
%                          diagnostic only, not thresholded.
%   qc_mean_margin       - Mean top1-top2 margin on the interval.
%   qc_low_fraction      - Fraction of ambiguous frames on the interval.
%   qc_score             - 1 - qc_low_fraction.
%   qc_interval_usable   - Interval-level logical based on mean margin and
%                          ambiguous-frame fraction.
%
% Optional fluo/metric aggregation:
%   If AverageFluoByDivision is true, channel_quantification and/or
%   mask_quantification dataseries from computeMetrics are averaged over RLS
%   intervals and appended to the same RLS dataseries.

image=[];

if nargin==0
    listout=listROIDataID("classification"); % lists all data that were generated using a classifier

    if numel(listout)==0
   listout='';
    else
    listout{end+1}=listout{end};
    end

    paramout=[];

    tip={'Classification data output name',...
        'Optional computeMetrics dataseries to average by generation', ...
        'Average computeMetrics fluorescence/metric values by generation', ...
        'Arrest threshold in expected division periods if ExpectedDivisionPeriod is set; otherwise frames',...
        'Death threshold frame number',...
        'Clog threshold frame number',...
        'Empty Threshold Discard frame number',...
        'EmptyThresholdNext',...
        'State decoder: off, viterbi, or median',...
        'Expected division/budding period in frames',...
        'Minimum division/budding interval in frames',...
        'Minimum interval factor when using expected period',...
        'Median decoder/filter window in frames',...
        'Viterbi live-state switch penalty',...
        'Viterbi terminal-state transition penalty',...
        'Viterbi unexpected transition penalty',...
        'Viterbi empty-to-live refill penalty',...
        'QC low-margin frame threshold',...
        'QC minimum mean probability margin',...
        'QC maximum low-confidence frame fraction',...
        };

    paramout.classification_data=listout;
    paramout.metrics_data={'<auto>','<auto>'};
    paramout.AverageFluoByDivision=false;
    % paramout.classes='unbud small large dead clog empty';
    %paramout.classiftype='bud';
    paramout.ArrestThreshold=3;
    paramout.DeathThreshold=3;
    paramout.ClogThreshold=1;
    paramout.EmptyThresholdDiscard=500; %discard roi if empty for more than this number of frames
    paramout.EmptyThresholdNext=100; %if encounter an empy after birth but before birth+EmptyThresholdNext, check the new RLS
    paramout.StateDecoder = {'off','viterbi','median','off'};
    paramout.ExpectedDivisionPeriod = 60;
    paramout.MinDivisionInterval = NaN;
    paramout.MinDivisionIntervalFactor = 0.5;
    paramout.MedianFilterWindow = 3;
    paramout.ViterbiLiveSwitchPenalty = 0.10;
    paramout.ViterbiTerminalPenalty = 0.25;
    paramout.ViterbiUnexpectedTransitionPenalty = 1.00;
    paramout.ViterbiRefillPenalty = 0.50;
    paramout.QCLowMarginThreshold = 0.05;
    paramout.QCMinMeanMargin = 0.05;
    paramout.QCMaxLowConfidenceFraction = 0.50;

    paramout.tip=tip;

    return;
else
    paramout=param;
end

disp('computeRLS processing...');
param=localEnsureQCDefaults(paramout);
classificationName=localTextParam(param,'classification_data','');
if isempty(strtrim(classificationName))
    error('computeRLS:MissingClassificationParameter', ...
        'computeRLS requires param.classification_data to name the classifier dataseries input.');
end

dataout=[];
fluo_data=[];
mask_data=[];

if localNeedsDataLoad(roiobj)
    roiobj.load('data');
end

tmp=roiobj.data;
if numel(tmp)==0
    roiobj.data=dataseries;
end
dataout=roiobj.data;

listdata={roiobj.data.groupid};
pix=find(matches(listdata,classificationName));

if numel(pix)==0
    disp('impossible to find the classified data, trying to reformat dataset...');
    formatInDataSeries.core(roiobj);
    dataout=roiobj.data;
    listdata={roiobj.data.groupid};
    pix=find(matches(listdata,classificationName));

    if numel(pix)==0
        roiId = '<unknown>';
        try
            roiId = char(string(roiobj.id));
        catch
        end
        available = '<none>';
        if ~isempty(listdata)
            available = strjoin(cellfun(@(x) char(string(x)), listdata, 'UniformOutput', false), ', ');
        end
        error('computeRLS:MissingClassificationData', ...
            'computeRLS could not find classification dataseries "%s" in ROI "%s". Available dataseries: %s.', ...
            classificationName, roiId, available);
    end
end



data=roiobj.data(pix);

if nargin~=3 %auto bounds
    if isfield(data.userData,'bounds')
        frames=data.userData.bounds;
    end
end

id =data.getData('id');

if ~exist('frames','var') || isempty(frames) || (isnumeric(frames) && all(frames == -1))
    frames = 1:numel(id);
end

% class id for classif output

id_training=data.getData('id_training');

% class id ouput for training;

grou={id, id_training};
nme={'_','_GT_'};
%id_rls=[];

if localBoolParam(param,'AverageFluoByDivision',false)
    [fluo_data, mask_data]=localSelectMetricDataSeries(roiobj.data, localMetricDataSelection(param));
end

for j=1:2 % loop on training and prediction data

    id=grou{j};

    if numel(id)~=0

        if isfield(data.userData,'classes')
            classes=data.userData.classes;
        else
            disp('could not identify classes used in the classification pipeline');
            return;
        end

        proba=[];

        if j==1 % not for groundtruth
            for i=1:numel(classes)
                str=['prob_' classes{i}];

                proba=[proba data.getData(str)];
            end
        end

        divTimes=computeDivtime(id,proba',classes,param,frames);

        if ~isempty(divTimes)

            hasDivision = numel(divTimes.framediv)>0 && ~isnan(divTimes.framediv(1));

            if hasDivision
                event="Budding";

                event=repmat(event,[1 1+numel(divTimes.duration)]);
                event=["Birth" event divTimes.endType];
                event=categorical(cellstr(event));
                durationForTable=divTimes.duration;
                if isempty(divTimes.duration)
                    divTimes.duration=NaN;
                end

            [syncPoint,~]=findSEP(divTimes.duration,1); %find SEP using classical xhi² fit based on div frequency

                divTimes.duration=durationForTable;
                divDuration=[NaN, divTimes.duration, NaN, NaN];

                count=[0:numel(divTimes.duration) NaN, NaN];
                death=[-numel(divTimes.duration):0, NaN,NaN];

                totaltime=[0, divTimes.framediv(1)-divTimes.frameBirth, cumsum(divTimes.duration)+divTimes.framediv(1)-divTimes.frameBirth , divTimes.frameEnd-divTimes.frameBirth];
                totaltime= totaltime+divTimes.frameBirth;
            elseif isnan(divTimes.frameBirth)
                event=categorical(cellstr(string(divTimes.endType)));
                syncPoint=NaN;
                divDuration=NaN;
                count=NaN;
                death=NaN;
                totaltime=divTimes.frameEnd;
                if isnan(totaltime)
                    totaltime=numel(id);
                end
            else
                event=categorical(cellstr(["Birth" string(divTimes.endType)]));
                syncPoint=NaN;
                divDuration=[NaN, NaN];
                count=[0, NaN];
                death=[0, NaN];
                totaltime=[divTimes.frameBirth, divTimes.frameEnd];
            end

            pixdata=find(arrayfun(@(x) strcmp(x.groupid, ['RLS' nme{j} classificationName]),dataout)); % find if object exists already
            %
            if numel(pixdata)
                cc=pixdata(1); % data to be overwritten
   
            else
                n=numel(dataout);
                if n==1 & numel(dataout.data)==0
                    cc=1; % replace empty dataset
                else
                    cc=numel(dataout)+1;
                end
            end



            %  id_rls(j)=cc;

            plotgroup={'events' 'divisions' 'time' 'count' 'count'};

            t=table;
            t{:,1}=event';
            t{:,2}=divDuration' ;
            t{:,3}= totaltime';
            t{:,4}= count';
            t{:,5}= death';

            t.Properties.VariableNames={'event', 'divduration' 'totaltime' 'birth' 'death'};

            temp=dataseries(t,{'event', 'divduration' 'totaltime' 'birth' 'death'},...
                'groupid',['RLS' nme{j} classificationName],'parentid',roiobj.id,'plot',{true true false false false},'groups',plotgroup);

            dataout(cc)=temp;
            dataout(cc).class="processing";
            dataout(cc).type="generation";
            dataout(cc).plotGroup={[] [] [] [] [] unique(plotgroup)};
            localAddRLSQCData(dataout(cc), t, divTimes, id, proba', classes, param);

            if numel(syncPoint) && ~isnan(syncPoint) % sep was found
                sep=count-syncPoint;
                dataout(cc).addData(sep',{'sep'},'plot',false,'groups','count');
            end

            if ~isempty(fluo_data) && localCanQuantifyIntervals(totaltime)

                totaltime_int=uint16(totaltime);

                indices = repelem(2:numel(totaltime_int), diff(totaltime_int))-1;

                varnames=fluo_data.data.Properties.VariableNames;

                for k=1:numel(varnames)
                    dat=fluo_data.data.(varnames{k});

                    if totaltime_int(end)-1 > numel(dat)
                        continue
                    end

                    dat=dat(totaltime_int(1):totaltime_int(end)-1);
                    % here put a condition if still alive 
                  
                    val = accumarray(indices',dat,[],@mean);

                    if totaltime_int(end-1)==totaltime_int(end) % if last event coincides with last frame
                        val=[val; NaN];
                    end

                    val=[val; NaN];
                    dataout(cc).addData(val,varnames(k),'plot',false,'groups','channel_quant');

                end

            end

            for l=1:numel(mask_data) % if mask quantification are present

                md=mask_data(l);

                if ~localCanQuantifyIntervals(totaltime)
                    continue
                end

                totaltime_int=uint16(totaltime);
                indices = repelem(2:numel(totaltime_int), diff(totaltime_int))-1;

                varnames=md.data.Properties.VariableNames;

                for k=1:numel(varnames)
                    dat=md.data.(varnames{k});

                    if totaltime_int(end)-1 > numel(dat)
                        continue
                    end

                    dat=dat(totaltime_int(1):totaltime_int(end)-1);

                    val = accumarray(indices',dat,[],@mean);

                       if totaltime_int(end-1)==totaltime_int(end) % if last event coincide with last frame
                        val=[val; NaN];
                       end

                    val=[val; NaN];

                    str='mask_quant';

                    if numel(find(contains(varnames{k},'Area'))) || numel(find(contains(varnames{k},'Surf')))
                        str='Area';
                    end
                      if numel(find(contains(varnames{k},'Vol'))) 
                        str='Volume';
                      end
                      if numel(find(contains(varnames{k},'Len'))) 
                        str='Length';
                      end
                     if numel(find(contains(varnames{k},'Eccentric'))) 
                        str='Number';
                    end


                    dataout(cc).addData(val,['mask' num2str(l) '_' varnames{k}],'plot',false,'groups',str);

                end
            end

        end
    end
end



%pixdata=find(arrayfun(@(x) strcmp(x.groupid, ['RLS' nme{j} param.classification_data{end}]),dataout));


%% HERE do compute fluo , starting with channel_quantification data
% to do : compute fluo, sync trajectories

%% =========================================DIVTIMES=================================================
end
function [divTimes]=computeDivtime(id,proba,classes,param,frames)

frameIdx = localNormalizeRLSFrames(frames, numel(id));
if ~isempty(proba) && ~(isscalar(proba) && proba == -1)
    maxFrame = min(numel(id), size(proba,2));
    frameIdx = frameIdx(frameIdx <= maxFrame);
    if isempty(frameIdx)
        frameIdx = 1:maxFrame;
    end
end
id = id(frameIdx);

if ~isempty(proba) && ~(isscalar(proba) && proba == -1)
    proba=proba(:,frameIdx);
end

divTimes=[];

% first identify frame corresponding to death or clog and birth (non
% empty cavity)

% switch param.classiftype
%
%     %========================CLASSIF BUD========================
%     case 'bud'

deathid=find(matches(classes,'dead'));
clogid=find(matches(classes,'clog'));
lbid=find(matches(classes,'large'));
smid=find(matches(classes,'small'));
unbuddedid=find(matches(classes,'unbud'));
emptyid=find(matches(classes,'empty'));

%% post process / optional state decoding
[id, decoderInfo]=localDecodeStateSequence(id, proba, classes, param);


%%

%===1// find BIRTH===

firstunb=find(id==unbuddedid,1,'first');
firstsm=find(id==smid,1,'first');
firstlg=find(id==lbid,1,'first');
if numel(firstunb)==0 %isempty
    firstunb=NaN;
end
if numel(firstsm)==0
    firstsm=NaN;
end
if numel(firstlg)==0
    firstlg=NaN;
end
frameBirth=min([firstunb,firstsm,firstlg]);

%===2// Identify potential END===
%==find potential first EMPTY frame, after birth
frameFirstEmptiedAfterBirth=NaN;
bwEmpty=(id==emptyid);
bwEmptyLabeled=bwlabel(bwEmpty);
for k=1:max(bwEmptyLabeled)
    bwEmpty=(bwEmptyLabeled==k);
    if sum(bwEmpty)> 2 && find(bwEmpty,1,'first')>frameBirth
        frameFirstEmptiedAfterBirth=find(bwEmpty,1,'first');
        break
    end
end

%==post-process empty : if empty very early: check the next rls
if frameFirstEmptiedAfterBirth<param.EmptyThresholdNext%frameFirstEmptiedAfterBirth>param.EmptyThresholdDiscard
    frameAfterFirstEmpty=find(bwEmpty,1,'last');
    %search from after the first empty islet (after first birth)
    %until the end
    firstunb=find(id(frameAfterFirstEmpty:end)==unbuddedid,1,'first');
    firstsm=find(id(frameAfterFirstEmpty:end)==smid,1,'first');
    firstlg=find(id(frameAfterFirstEmpty:end)==lbid,1,'first');
    if numel(firstunb)==0 %isempty
        firstunb=NaN;
    end
    if numel(firstsm)==0
        firstsm=NaN;
    end
    if numel(firstlg)==0
        firstlg=NaN;
    end
    frameBirth=min([firstunb,firstsm,firstlg]);
end
%

%==find DEATH (need param.DeathThreshold frames to be validated)======
frameDeath=NaN;
if ~isnan(frameBirth)
    idpostBirth=id;
    idpostBirth(1:frameBirth)=0;%only consider death if cell is born (to ignore death if first images of roi is death=
    bwDeath=(idpostBirth==deathid);
    bwDeath(1:frameBirth)=0; %useless?
    bwDeathLabeled=bwlabel(bwDeath);
    for k=1:max(bwDeathLabeled)
        bwDeath=(bwDeathLabeled==k);
        if sum(bwDeath)>= param.DeathThreshold || find(bwDeath,1,'last')==numel(id) || (id(find(bwDeath,1,'last')+1)==emptyid)% if ... or if the last frame is "dead",  or if dead is followed by empty (dead cells often squeeze through the trap), then consider as death
            frameDeath=find(bwDeath,1,'first');
            break
        end
    end
end
%


%==find potential first CLOG==============
frameClog=NaN;
if ~isnan(frameBirth)
    idpostBirth=id;
    idpostBirth(1:frameBirth)=0;%only consider clog if cell is born (to ignore clog if first images of roi is clog=
    bwClog=(idpostBirth==clogid);
    bwClog(1:frameBirth)=0; %useless?
    bwClogLabeled=bwlabel(bwClog);
    for k=1:max(bwClogLabeled)
        bwClog=(bwClogLabeled==k);
        if sum(bwClog)>= param.ClogThreshold
            frameClog=find(bwClog,1,'first');
            break
        end
    end
end
%         if ~isnan(frameBirth)
%             frameClog=find((idpostBirth==clogid),1,'first');
%         end
%


%==find potential division arrest==========
frameArrest=NaN;
activeArrestThreshold=localActiveArrestThreshold(param);
for arrestid=[unbuddedid,smid,lbid]
    bwArrest=(id==arrestid);
    bwArrestLabel=bwlabel(bwArrest);
    for k=1:max(bwArrestLabel)
        bwArrest=(bwArrestLabel==k);
        if sum(bwArrest)> activeArrestThreshold
            if ~isnan(frameArrest)
                frameArrest=min(frameArrest,(find(bwArrest,1,'first')+ activeArrestThreshold));
            else
                frameArrest=find(bwArrest,1,'first')+ activeArrestThreshold;
            end
            break
        end
    end
end
%

%===3/ find END===
if isnan(frameBirth) %if timeseries has never seen unb, small or large
    frameEnd=NaN;
    endType='NeverBorn';
else
    frameEnd=min([frameClog, frameDeath, frameFirstEmptiedAfterBirth, frameArrest]);
    if isnan(frameEnd) % cell is not dead or clogged or empty, TO DO: SEPARATE BETWEEN DEATH AND CENSOR
        frameEnd=numel(id);
        %machin.censor=1;
    end
    endTypeid=find([frameClog, frameDeath, frameFirstEmptiedAfterBirth, frameArrest, numel(id)]==frameEnd,1,'last');
    endTypeList={'Clog', 'Death', 'Emptied', 'Arrest', 'stillAlive'};
    endType=endTypeList{endTypeid};
end
%


%===4/ detect divisions===

%=====Div counting=====
%
%
divFrames=[];
startAfterBudEmergence=0;
if ~isnan(frameBirth)
    %===divided before start of timelapse==?
    if id(frameBirth)==smid || id(frameBirth)==lbid
        startAfterBudEmergence=1;
    end

    %==detect bud emergence==
    for j=frameBirth:frameEnd-1
        if (id(j)==lbid && id(j+1)==smid) || (id(j)==unbuddedid && id(j+1)==smid) % bud has emerged
            divFrames=[divFrames j+1];
        end
    end
end
%
if numel(divFrames)==0
    divFrames=NaN;
end
[divFrames, rejectedDivFrames, minDivisionInterval]=localApplyDivisionIntervalRule(divFrames,param);
divTimes.frameBirth=localMapRLSFrame(frameBirth,frameIdx);
divTimes.frameEnd=localMapRLSFrame(frameEnd,frameIdx);
divTimes.endType=endType;
divTimes.framediv=localMapRLSFrame(divFrames,frameIdx);
divTimes.duration=diff(divTimes.framediv); % division times on original ROI frame axis
divTimes.ndiv=sum(~isnan([divTimes.framediv]));
divTimes.decoder=decoderInfo.mode;
divTimes.decoderChangedFrames=decoderInfo.changedFrames;
divTimes.rejectedDivFrames=localMapRLSFrame(rejectedDivFrames,frameIdx);
divTimes.minDivisionInterval=minDivisionInterval;
divTimes.arrestThreshold=activeArrestThreshold;
%if timelapse started while the cell is small or large
if startAfterBudEmergence==1
    divTimes.ndiv=divTimes.ndiv+1;
end




%         %%=================================CLASSIF DIV======================================
%     case 'div'
%         deathid=findclassid(classes,'dead');
%         censorid=findclassid(classes,'censor');
%         nodivid=findclassid(classes,'nodiv');
%         divid=findclassid(classes,'div');
%         emptyid=findclassid(classes,'birth');
%
%
%         startFrame=find(id==emptyid,1,'last');
%         if numel(startFrame)==0
%             startFrame=1;
%         end
%
%         endFrame=min( find(id==deathid,1,'first')  ,  find(id==censorid,1,'first'));
%         if numel(endFrame)==0
%             endFrame=numel(id);
%         end
%
%         divFrames=startFrame;
%         for j=startFrame:endFrame
%             if id(j)==divid % cell has divided
%                 divFrames=[divFrames j];
%             end
%         end
%         divTimes.framediv=divFrames;
%         divTimes.duration=diff(divFrames); % division times !
% end

end
function frameIdx=localNormalizeRLSFrames(frames,nFrames)
if nargin<2 || isempty(nFrames) || ~isfinite(nFrames) || nFrames<1
    frameIdx=[];
    return;
end
if nargin<1 || isempty(frames) || (isnumeric(frames) && all(frames == -1))
    frameIdx=1:nFrames;
    return;
end
if islogical(frames)
    frames=find(frames);
elseif iscell(frames)
    try
        frames=cell2mat(frames(:));
    catch
        frames=[];
    end
elseif ~isnumeric(frames)
    try
        frames=double(frames(:));
    catch
        frames=[];
    end
end
frames=double(frames(:)');
frames=unique(round(frames(isfinite(frames) & frames>=1 & frames<=nFrames)),'stable');
if isempty(frames)
    frames=1:nFrames;
end
frameIdx=frames;
end

function out=localMapRLSFrame(frameLocal,frameIdx)
out=frameLocal;
if isempty(frameLocal) || isempty(frameIdx)
    return;
end
mask=isfinite(double(frameLocal)) & frameLocal>=1 & frameLocal<=numel(frameIdx);
out(mask)=frameIdx(round(frameLocal(mask)));
end

function [idOut, info]=localDecodeStateSequence(id,proba,classes,param)
idOut=id(:)';
mode=lower(localChoiceString(param,'StateDecoder','off'));
info=struct('mode',mode,'changedFrames',0);

hasProba=~isempty(proba) && ~(isscalar(proba) && proba == -1) && isnumeric(proba);
if ~hasProba
    if strcmp(mode,'median')
        idOut=localModeFilterLabels(idOut,localNumericParam(param,'MedianFilterWindow',3));
        info.changedFrames=sum(idOut~=id(:)');
    else
        info.mode='off';
    end
    return
end

probaWork=double(proba);
smid=find(matches(classes,'small'));
lbid=find(matches(classes,'large'));
if true
    if ~isempty(smid)
        probaWork(smid,:) = movmedian(probaWork(smid,:), 4, 2, 'omitnan');
    end
    if ~isempty(lbid)
        probaWork(lbid,:) = movmedian(probaWork(lbid,:), 4, 2, 'omitnan');
    end
end

[~,argmaxId]=max(probaWork,[],1);

switch mode
    case {'off','argmax','legacy'}
        idOut=argmaxId;
        info.mode='off';
    case 'median'
        idOut=localModeFilterLabels(argmaxId,localNumericParam(param,'MedianFilterWindow',3));
    case 'viterbi'
        idOut=localViterbiDecode(probaWork,classes,param);
    otherwise
        idOut=argmaxId;
        info.mode='off';
end

info.changedFrames=sum(idOut(:)'~=argmaxId(:)');


end
function idOut=localModeFilterLabels(idIn,window)
idOut=idIn(:)';
window=max(1,round(double(window)));
if window<=1 || numel(idOut)<=2
    return
end
if mod(window,2)==0
    window=window+1;
end
half=floor(window/2);
for t=1:numel(idOut)
    lo=max(1,t-half);
    hi=min(numel(idOut),t+half);
    vals=idOut(lo:hi);
    vals=vals(~isnan(vals));
    if isempty(vals)
        continue
    end
    u=unique(vals,'stable');
    counts=arrayfun(@(x) sum(vals==x),u);
    [~,ix]=max(counts);
    idOut(t)=u(ix);
end


end
function idOut=localViterbiDecode(proba,classes,param)
[nStates,nFrames]=size(proba);
if nFrames==0
    idOut=[];
    return
end

p=max(double(proba),eps);
colsum=sum(p,1,'omitnan');
bad=colsum<=0 | isnan(colsum);
colsum(bad)=1;
p=p./colsum;
emit=log(max(p,eps));

decodeClasses=localDecodeClassNames(classes,nStates);
trans=localViterbiTransitionMatrix(decodeClasses,param);
score=-inf(nStates,nFrames);
back=ones(nStates,nFrames);
score(:,1)=emit(:,1);

for t=2:nFrames
    for s=1:nStates
        vals=score(:,t-1)+trans(:,s);
        [best,idx]=max(vals);
        score(s,t)=best+emit(s,t);
        back(s,t)=idx;
    end
end

[~,last]=max(score(:,end));
path=zeros(1,nFrames);
path(end)=last;
for t=nFrames:-1:2
    path(t-1)=back(path(t),t);
end
idOut=path;


end
function out=localDecodeClassNames(classes,nStates)
out=cellstr(string(classes(:)'));
if numel(out)>=nStates
    out=out(1:nStates);
else
    for k=(numel(out)+1):nStates
        out{k}=['class_' num2str(k)];
    end
end


end
function trans=localViterbiTransitionMatrix(classes,param)
n=numel(classes);
unexpected=localNumericParam(param,'ViterbiUnexpectedTransitionPenalty',1.0);
liveSwitch=localNumericParam(param,'ViterbiLiveSwitchPenalty',0.10);
terminal=localNumericParam(param,'ViterbiTerminalPenalty',0.25);
refill=localNumericParam(param,'ViterbiRefillPenalty',0.50);

trans=-unexpected*ones(n,n);
for s=1:n
    trans(s,s)=0;
end

deadid=find(matches(classes,'dead'));
clogid=find(matches(classes,'clog'));
lbid=find(matches(classes,'large'));
smid=find(matches(classes,'small'));
unbuddedid=find(matches(classes,'unbud'));
emptyid=find(matches(classes,'empty'));
live=[unbuddedid smid lbid];

if ~isempty(unbuddedid) && ~isempty(smid), trans(unbuddedid,smid)=-liveSwitch; end
if ~isempty(smid) && ~isempty(lbid), trans(smid,lbid)=-liveSwitch; end
if ~isempty(lbid) && ~isempty(unbuddedid), trans(lbid,unbuddedid)=-liveSwitch; end
if ~isempty(lbid) && ~isempty(smid), trans(lbid,smid)=-liveSwitch; end

terminalStates=[deadid clogid emptyid];
for a=live
    for b=terminalStates
        trans(a,b)=-terminal;
    end
end

if ~isempty(emptyid)
    for b=live
        trans(emptyid,b)=-refill;
    end
end

% Death and clog are absorbing: a cell cannot "undie" or unclog.
if ~isempty(deadid)
    trans(deadid,:)=-inf;
    trans(deadid,deadid)=0;
end
if ~isempty(clogid)
    trans(clogid,:)=-inf;
    trans(clogid,clogid)=0;
end


end
function [divFramesOut,rejectedDivFrames,minInterval]=localApplyDivisionIntervalRule(divFrames,param)
divFramesOut=divFrames;
rejectedDivFrames=[];
minInterval=localActiveMinDivisionInterval(param);

if isnan(minInterval) || minInterval<=0 || isempty(divFrames) || all(isnan(divFrames))
    return
end

candidate=divFrames(~isnan(divFrames));
if numel(candidate)<=1
    divFramesOut=candidate;
    if isempty(divFramesOut)
        divFramesOut=NaN;
    end
    return
end

keep=true(size(candidate));
lastKept=candidate(1);
for k=2:numel(candidate)
    if candidate(k)-lastKept < minInterval
        keep(k)=false;
    else
        lastKept=candidate(k);
    end
end

rejectedDivFrames=candidate(~keep);
divFramesOut=candidate(keep);
if isempty(divFramesOut)
    divFramesOut=NaN;
end


end
function minInterval=localActiveMinDivisionInterval(param)
minInterval=localNumericParam(param,'MinDivisionInterval',NaN);
if isnan(minInterval) || minInterval<=0
    expected=localNumericParam(param,'ExpectedDivisionPeriod',NaN);
    factor=localNumericParam(param,'MinDivisionIntervalFactor',0.5);
    if ~isnan(expected) && expected>0 && ~isnan(factor) && factor>0
        minInterval=expected*factor;
    else
        minInterval=NaN;
    end
end
if ~isnan(minInterval)
    minInterval=round(minInterval);
end


end
function threshold=localActiveArrestThreshold(param)
expected=localNumericParam(param,'ExpectedDivisionPeriod',NaN);
arrestThreshold=localNumericParam(param,'ArrestThreshold',3);
if isfield(param,'ArrestThresholdCycles') && ~isempty(param.ArrestThresholdCycles)
    arrestThreshold=localNumericParam(param,'ArrestThresholdCycles',arrestThreshold);
end
if ~isnan(expected) && expected>0 && ~isnan(arrestThreshold) && arrestThreshold>0
    threshold=round(expected*arrestThreshold);
else
    threshold=arrestThreshold;
end
threshold=max(1,round(threshold));


end
function out=localChoiceString(param,field,defaultValue)
out=defaultValue;
if ~isfield(param,field) || isempty(param.(field))
    return
end
v=param.(field);
if iscell(v)
    v=v{end};
end
if isstring(v) || ischar(v) || isnumeric(v) || islogical(v) || iscategorical(v)
    out=char(string(v));
end


end
function out=localNumericParam(param,field,defaultValue)
out=defaultValue;
if ~isfield(param,field) || isempty(param.(field))
    return
end
v=param.(field);
if iscell(v)
    v=v{end};
end
if isnumeric(v) || islogical(v)
    out=double(v);
elseif isstring(v) || ischar(v) || iscategorical(v)
    out=str2double(char(string(v)));
end
if isempty(out) || all(isnan(out(:)))
    out=defaultValue;
end


end
function param=localEnsureQCDefaults(param)
defaults=struct();
defaults.ArrestThreshold=3;
defaults.AverageFluoByDivision=false;
defaults.metrics_data={'<auto>','<auto>'};
defaults.StateDecoder={'off','viterbi','median','off'};
defaults.ExpectedDivisionPeriod=NaN;
defaults.MinDivisionInterval=NaN;
defaults.MinDivisionIntervalFactor=0.5;
defaults.MedianFilterWindow=3;
defaults.ViterbiLiveSwitchPenalty=0.10;
defaults.ViterbiTerminalPenalty=0.25;
defaults.ViterbiUnexpectedTransitionPenalty=1.00;
defaults.ViterbiRefillPenalty=0.50;
defaults.QCLowMarginThreshold=0.05;
defaults.QCMinMeanMargin=0.05;
defaults.QCMaxLowConfidenceFraction=0.50;

fields=fieldnames(defaults);
for k=1:numel(fields)
    f=fields{k};
    if ~isfield(param,f) || isempty(param.(f))
        param.(f)=defaults.(f);
    end
end


end
function out=localBoolParam(param,field,defaultValue)
out=defaultValue;
if ~isfield(param,field) || isempty(param.(field))
    return
end
v=param.(field);
if iscell(v)
    if isempty(v)
        return
    end
    v=v{end};
end
if islogical(v)
    out=logical(v);
elseif isnumeric(v)
    out=logical(v);
elseif isstring(v) || ischar(v) || iscategorical(v)
    txt=lower(strtrim(char(string(v))));
    out=any(strcmp(txt,{'true','1','yes','on'}));
end


end
function out=localTextParam(param,field,defaultValue)
out=defaultValue;
if ~isfield(param,field) || isempty(param.(field))
    return
end
v=param.(field);
if iscell(v)
    if isempty(v)
        return
    end
    v=v{end};
end
if isstring(v) || ischar(v) || iscategorical(v)
    out=char(string(v));
elseif isnumeric(v) || islogical(v)
    out=num2str(v);
end


end
function names=localMetricDataSelection(param)
names={};
if ~isfield(param,'metrics_data') || isempty(param.metrics_data)
    return
end
v=param.metrics_data;
if ischar(v)
    names=cellstr(v);
elseif isstring(v) || isnumeric(v) || islogical(v) || iscategorical(v)
    names=cellstr(string(v(:)));
elseif iscell(v)
    for i=1:numel(v)
        item=v{i};
        if isempty(item)
            continue
        end
        if ischar(item)
            names=[names cellstr(item)]; %#ok<AGROW>
        elseif isstring(item) || isnumeric(item) || islogical(item) || iscategorical(item)
            names=[names cellstr(string(item(:)))']; %#ok<AGROW>
        end
    end
end
names=cellfun(@(x) char(strtrim(string(x))), names(:)', 'UniformOutput', false);
names=names(~cellfun(@isempty,names));
names=unique(names,'stable');


end
function [fluo_data,mask_data]=localSelectMetricDataSeries(dataSeries,selection)
fluo_data=[];
mask_data=[];
if isempty(dataSeries)
    return
end

ids=cell(1,numel(dataSeries));
for i=1:numel(dataSeries)
    ids{i}='';
    try
        ids{i}=char(string(dataSeries(i).groupid));
    catch
    end
end

if localUseAutoMetrics(selection)
    fluoIdx=find(strcmp(ids,'channel_quantification'));
    maskIdx=find(contains(ids,'mask_quantification'));
else
    fluoIdx=[];
    maskIdx=[];
    for k=1:numel(selection)
        name=char(string(selection{k}));
        if isempty(name)
            continue
        end
        if strcmpi(name,'mask_quantification')
            maskIdx=[maskIdx find(contains(ids,'mask_quantification'))]; %#ok<AGROW>
            continue
        end
        idx=find(strcmp(ids,name));
        if isempty(idx)
            continue
        end
        if contains(lower(name),'mask_quantification')
            maskIdx=[maskIdx idx]; %#ok<AGROW>
        else
            fluoIdx=[fluoIdx idx]; %#ok<AGROW>
        end
    end
end

fluoIdx=unique(fluoIdx,'stable');
maskIdx=unique(maskIdx,'stable');
if ~isempty(fluoIdx)
    fluo_data=dataSeries(fluoIdx(1));
end
if ~isempty(maskIdx)
    mask_data=dataSeries(maskIdx);
end
 
end
function tf=localUseAutoMetrics(selection)
tf=isempty(selection);
if tf
    return
end
tokens=lower(strtrim(string(selection(:))));
tf=any(tokens=="<auto>" | tokens=="auto" | tokens=="all" | tokens=="<all>");
end

function tf=localCanQuantifyIntervals(totaltime)
tf=false;
if isempty(totaltime) || numel(totaltime)<2
    return
end
totaltime=double(totaltime(:)');
if any(isnan(totaltime)) || any(isinf(totaltime))
    return
end
if totaltime(1)<1 || totaltime(end)<=totaltime(1)
    return
end
tf=true;
end

function localAddRLSQCData(ds,t,divTimes,id,proba,classes,param) %#ok<INUSD>
n=height(t);
if n==0
    return
end

status=localRLSStatus(divTimes);
[qcMeanConf,qcMinConf,qcMeanMargin,qcLowFraction,qcScore,qcIntervalUsable]=localIntervalQC(t.totaltime,proba,param);

structuralUsable=localStructuralUsable(status);
hasQC=any(~isnan(qcScore));
if hasQC
    roiQCOk=all(qcIntervalUsable(~isnan(qcScore)));
else
    roiQCOk=true;
end
roiUsable=structuralUsable && roiQCOk;
reason=localStatusReason(status,structuralUsable,roiQCOk,divTimes);

ds.addData(repmat(string(status),n,1),{'status'},'plot',false,'groups','qc');
ds.addData(repmat(logical(roiUsable),n,1),{'usable'},'plot',false,'groups','qc');
ds.addData(repmat(string(reason),n,1),{'reason'},'plot',false,'groups','qc');
ds.addData(repmat(double(divTimes.ndiv),n,1),{'nDiv'},'plot',false,'groups','qc');
ds.addData(repmat(double(divTimes.frameBirth),n,1),{'frameBirth'},'plot',false,'groups','qc');
ds.addData(repmat(double(divTimes.frameEnd),n,1),{'frameEnd'},'plot',false,'groups','qc');
ds.addData(repmat(string(divTimes.endType),n,1),{'endType'},'plot',false,'groups','qc');
ds.addData(repmat(string(divTimes.decoder),n,1),{'decoder'},'plot',false,'groups','qc');
ds.addData(repmat(double(divTimes.minDivisionInterval),n,1),{'minDivisionInterval'},'plot',false,'groups','qc');
ds.addData(repmat(double(divTimes.arrestThreshold),n,1),{'arrestThreshold'},'plot',false,'groups','qc');
ds.addData(repmat(double(numel(divTimes.rejectedDivFrames)),n,1),{'nRejectedDivisions'},'plot',false,'groups','qc');
ds.addData(repmat(double(divTimes.decoderChangedFrames),n,1),{'decoderChangedFrames'},'plot',false,'groups','qc');
ds.addData(qcMeanConf,{'qc_mean_confidence'},'plot',false,'groups','qc');
ds.addData(qcMinConf,{'qc_min_confidence'},'plot',false,'groups','qc');
ds.addData(qcMeanMargin,{'qc_mean_margin'},'plot',false,'groups','qc');
ds.addData(qcLowFraction,{'qc_low_fraction'},'plot',false,'groups','qc');
ds.addData(qcScore,{'qc_score'},'plot',false,'groups','qc');
ds.addData(qcIntervalUsable,{'qc_interval_usable'},'plot',false,'groups','qc');

end
function status=localRLSStatus(divTimes)
endType=lower(string(divTimes.endType));
if endType=="neverborn"
    status="neverBorn";
elseif endType=="death"
    status="death";
elseif endType=="arrest"
    status="arrest";
elseif endType=="clog"
    status="clog";
elseif endType=="emptied"
    status="emptied";
elseif divTimes.ndiv==0
    status="noDivision";
else
    status="stillAlive";
end

end
function tf=localStructuralUsable(status)
bad=["neverBorn","clog","emptied"];
tf=~any(status==bad);

end
function reason=localStatusReason(status,structuralUsable,roiQCOk,divTimes) %#ok<INUSD>
if ~structuralUsable
    switch status
        case "neverBorn"
            reason="no cell birth/state detected";
        case "clog"
            reason="clog detected";
        case "emptied"
            reason="ROI emptied after birth";
        otherwise
            reason="structural status not usable";
    end
elseif ~roiQCOk
    reason="ambiguous class probabilities";
elseif status=="noDivision"
    reason="no budding transition detected";
elseif status=="arrest"
    reason="cell-cycle arrest threshold reached";
elseif status=="death"
    reason="death detected";
else
    reason="ok";
end

end
function [meanConf,minConf,meanMargin,lowFraction,qcScore,intervalUsable]=localIntervalQC(totaltime,proba,param)
n=numel(totaltime);
meanConf=nan(n,1);
minConf=nan(n,1);
meanMargin=nan(n,1);
lowFraction=nan(n,1);
qcScore=nan(n,1);
intervalUsable=true(n,1);

if isempty(proba) || ~isnumeric(proba) || size(proba,2)==0
    return
end

p=double(proba);
nFrames=size(p,2);
sorted=sort(p,1,'descend');
conf=sorted(1,:);
if size(sorted,1)>=2
    margin=sorted(1,:)-sorted(2,:);
else
    margin=nan(1,nFrames);
end

for r=1:n
    hi=round(double(totaltime(r)));
    if isnan(hi) || isinf(hi)
        intervalUsable(r)=false;
        continue
    end

    if r==1
        lo=max(1,min(hi,nFrames));
    else
        lo=round(double(totaltime(r-1)));
    end

    if isnan(lo) || isinf(lo)
        intervalUsable(r)=false;
        continue
    end

    lo=max(1,min(lo,nFrames));
    hi=max(1,min(hi,nFrames));
    if hi<lo
        tmp=lo;
        lo=hi;
        hi=tmp;
    end

    ix=lo:hi;
    c=conf(ix);
    m=margin(ix);
    low=(m<param.QCLowMarginThreshold);

    meanConf(r)=mean(c,'omitnan');
    minConf(r)=min(c,[],'omitnan');
    meanMargin(r)=mean(m,'omitnan');
    lowFraction(r)=mean(double(low),'omitnan');
    qcScore(r)=1-lowFraction(r);
    intervalUsable(r)=meanMargin(r)>=param.QCMinMeanMargin && ...
        lowFraction(r)<=param.QCMaxLowConfidenceFraction;
end

end
function tf=localNeedsDataLoad(roiobj)
tf=true;
try
    if isempty(roiobj.data)
        return
    end
    d=roiobj.data;
    if isa(d,'dataseries')
        for k=1:numel(d)
            try
                if ~isempty(d(k).groupid)
                    tf=false;
                    return
                end
            catch
            end
            try
                if ~isempty(d(k).data)
                    tf=false;
                    return
                end
            catch
            end
        end
    else
        tf=false;
    end
catch
    tf=true;
end
end