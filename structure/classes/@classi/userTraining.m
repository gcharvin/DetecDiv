function userTraining(classif,varargin)

% this function load the annotation/curation process for a specified classification
% task
classitype=[];
for i=1:numel(varargin)
    %Method
    if strcmp(varargin{i},'Roi')
        classitype=varargin{i+1};
    end
end

[~, category] = classiNormalizeCategory(classif.category);
category = string(category);

% disp(['Number of classes defined by user: ' num2str(numel(classif.classes))]);
%     for j=1:numel(classif.classes)
%        disp([num2str(j) '- '  classif.classes{j}]);
%     end
%
% disp(' ');
%
% disp(['Number of ROIs available in the training set: ' num2str(numel(classif.roi))]);
%     for j=1:numel(classif.roi)
%        disp([num2str(j) '- '  classif.roi(j).id]);
%     end


if strcmpi(category, "Timeseries") % time series classification and regression

    rois=1:numel(classif.roi);
    prompt='Please enter the ROIs list in which to do training; Tyoe 0 to screen all rois; Default:0';
    resp= input(prompt);
    if numel(resp)==0
        resp=rois;
    end

    rois=resp;

    annotateROIs(classif,rois);

else % image based classification and regression

    if numel(classitype)==0
        prompt='Please enter the ROI number in which to do training; Default:1';
        classitype= input(prompt);

        if numel(classitype)==0
            classitype=1;
        end
    end

    % channel=classif.channel(1);

    if classitype>numel(classif.roi)
        disp('This ROI is ot available; quitting ...');
        return
    end

    % comment : disable restrictions on channel display:

    % classif.roi(classitype).display.selectedchannel=zeros(1,numel(classif.roi(classitype).display.selectedchannel));
    % classif.roi(classitype).display.selectedchannel(channel)=1;
    %
    %
    % pix = classif.roi(classitype).findChannelID(classif.strid);
    % pix=  classif.roi(classitype).channelid(pix);
    % classif.roi(classitype).display.selectedchannel(pix)=1;

    %classif.roi(classitype).view(classif.roi(classitype).display.frame,classif);

    roiObj=classif.roi(classitype);

    if numel(roiObj.image)==0
        roiObj.load;
    end

    roiObj.parent=classif;

    normalizeDisplay(roiObj);

    options = '';
    isPixelAnnotation = isPixelAnnotationClassifier(classif, category);
    classstr = {};

   if isPixelAnnotation

        options= 'pixelAnnotation';

         for i = 1:numel(roiObj.data)
            data=roiObj.data(i);
            data.show=false;
         end

         classstr=cell(1, numel(classif.classes));
         for i=1:numel(classif.classes)
            classstr{i}=[classif.strid '_' classif.classes{i}];
         end
   end

    if strcmpi(category, "LSTM")
       options=  'dataAnnotation';
       pix=[];

 for i = 1:numel(roiObj.data)
    data = roiObj.data(i);

    if strcmp(data.groupid, classif.strid)
        data.show = true;

        pp = data.plotProperties;
        for jj = 1:size(pp,1)
            label = pp{jj,2};
            pp{jj,1} = strcmp(label,'labels_training');
        end
        data.plotProperties = pp;
    else
        data.show = false;
    end

    roiObj.data(i) = data; % <-- IMPORTANT
end

       
    end

 channel_names = roiObj.display.channel;

nch = numel(channel_names);
selected = false(1, nch);

for i = 1:min(numel(roiObj.display.selectedchannel), nch)
    if any(strcmp(channel_names{i}, classif.channelName))
        selected(i) = true;
    end

    if isPixelAnnotation
         if any(strcmp(channel_names{i}, classstr))
        selected(i) = true;
         end 
    end
end

roiObj.display.selectedchannel = selected;

end

ensureCellInformationDataseries(roiObj);

    figures=findall(0,'Type','figure');
    appFigure=findobj(figures,'Name','ScoreApp');
    if isprop(appFigure,'RunningAppInstance')
        if strlength(string(options)) > 0
            appFigure.RunningAppInstance.addROI(roiObj,options);
        else
            appFigure.RunningAppInstance.addROI(roiObj);
        end
        app=appFigure.RunningAppInstance;
    else
        if strlength(string(options)) > 0
            app=score(roiObj,options);
        else
            app=score(roiObj);
        end
    end

        % app.updatePanelsLayout();
        % app.updateDisplaySettings();
        %  app.UIDataTable.Selection=[pix 1];
        %  app.displayData();
        %   app.displaySubData();
   
end



function annotateROIs(classif,rois)

h=figure('Position',[100 100 800 400]);

%tmp=getData(classif,rois,1);
classif.roi(rois(1)).display.frame=1;
plotData(h,classif,rois,1);

%plotData(h,tmp,1,classif)

keys={'a' 'z' 'e' 'r' 't' 'y' 'u' 'i' 'o' 'p' 'q' 's' 'd' 'f' 'g' 'h' 'j'};
h.KeyPressFcn={@changeframe,classif,rois,keys};
end



function tmp=getData(classif,rois,id)
%strfield=classif.trainingset; % dataset to be trained on
strfield=classif.channelName{1};
pix=strfind(strfield,'.');

if numel(pix)==0
    str={strfield};
else
    str={strfield(1:pix(1)-1)};

    cc=1;
    for i=1:numel(pix)-1
        str{cc+1}=strfield(pix(i)+1:pix(i+1)-1);
        cc=cc+1;
    end
    str{cc+1}=strfield(pix(cc)+1:end);
end


% parse fields

cc=1;

r=rois(id);

tmp=classif.roi(r).results;


for j=2:numel(str)
    tmp=tmp.(str{j}); % ?? Why ??
end

end

function plotData(h,classif,rois,roiid) % HERE : must display frame displayed and plot classes a function of rames

figure(h);
clf

data=getData(classif,rois,roiid);

if classif.output==1 % sequence to one
    cond=0;
else
    cond=1; % sequence to sequence
end

for i=1:size(data,1)

    subplot(size(data,1)+cond,1,i); hold on ;

    if i==1

        str=['ROI ' num2str(roiid) '  -  ' classif.roi(roiid).id ];
        if classif.output==1 % sequence to one
            if  classif.roi(rois(roiid)).train.(classif.strid).id>0
                str=[str ' - ' classif.classes{classif.roi(rois(roiid)).train.(classif.strid).id}];
            else
                str=[str ' - unclassified'];
            end

        else % sequence to sequence
            if  numel(classif.roi(rois(roiid)).train.(classif.strid).id)>=classif.roi(rois(roiid)).display.frame
                if classif.roi(rois(roiid)).train.(classif.strid).id(classif.roi(rois(roiid)).display.frame) >0
                    str=[str ' - ' classif.classes{classif.roi(rois(roiid)).train.(classif.strid).id(classif.roi(rois(roiid)).display.frame)}];
                else
                    str=[str ' - unclassified'];
                end
            else
                classif.roi(rois(roiid)).train.(classif.strid).id(classif.roi(rois(roiid)).display.frame)=0;
                str=[str ' - unclassified'];
            end

            str= [str ' - frame:' num2str(classif.roi(rois(roiid)).display.frame)];

        end

        ht=title(str,'Interpreter','none');

    end

    x=data(i,:);

    plot(x,'Marker','.','MarkerSize',10,'Color','b'); hold on

    if classif.output==0 % sequence to sequence
        line([ classif.roi(rois(roiid)).display.frame classif.roi(rois(roiid)).display.frame], [0 max(x)],'Color','k');
    end

    xlim([0 numel(x)]);

    if i<size(data,1)
        set(gca,'FontSize',14,'XTickLabels',{});
    else
        set(gca,'FontSize',14);
    end
end

if classif.output==0 % seuqnece to sequence
    subplot(size(data,1)+cond,1,i+1); hold on ;
    plot( classif.roi(rois(roiid)).train.(classif.strid).id,'Color','r','LineWidth',2); hold on
    line([ classif.roi(rois(roiid)).display.frame classif.roi(rois(roiid)).display.frame], [0 numel(classif.classes)+1],'Color','k');
    xlim([0 numel(x)]);
    ylim([0 numel(classif.classes)+1]);
end




% if sequence to sequence, must add the value  for each frame ....

xlabel('Time (frames');

h.UserData=roiid;

end

function changeframe(handle,event,classif,rois,keys)

roiid=handle.UserData;

refreshe=0;

if strcmp(event.Key,'m')
    if roiid>=numel(rois)
        return;
    end
    roiid=roiid+1;
    refreshe=1;
end

if strcmp(event.Key,'l')
    if roiid<=1
        return;
    end
    roiid=roiid-1;
    refreshe=1;
end

if classif.output==0 % sequence to sequence // allow frame browsing

    if strcmp(event.Key,'rightarrow')
        data=getData(classif,rois,roiid);
        ma=size(data,2);
        if classif.roi(rois(roiid)).display.frame<ma
            classif.roi(rois(roiid)).display.frame=classif.roi(rois(roiid)).display.frame+1;
            refreshe=1;
        end
    end
    if strcmp(event.Key,'leftarrow')
        if classif.roi(rois(roiid)).display.frame>1
            classif.roi(rois(roiid)).display.frame=classif.roi(rois(roiid)).display.frame-1;
            refreshe=1;
        end
    end

end

% data=getData(classif,rois,roiid);
% ok=1;


for i=1:numel(keys) % display the selected class for the current image
    if i>numel(classif.classes)
        break
    end

    if strcmp(event.Key,keys{i})
        if classif.output==0
            classif.roi(rois(roiid)).train.(classif.strid).id(classif.roi(rois(roiid)).display.frame)=i;
        else
            classif.roi(rois(roiid)).train.(classif.strid).id=i;
        end
        refreshe=1;
    end
end

if refreshe==1
    plotData(handle,classif,rois,roiid);
end
end

function normalizeDisplay(roiObj)
d = roiObj.display;
nch = numel(d.channel);

% Helpers internes
resizeRow = @(v, n, fill) ( ...
    (numel(v)>=n) * v(1:n) + ...
    (numel(v)< n)  * [v(:).'  repmat(fill,1,n-numel(v))] ); %#ok<NASGU>

% 1D vecteurs (rangés sur 1×N)
oneDFields = {'selectedchannel','indexed','alpha','contour','width','log'};
for k = 1:numel(oneDFields)
    f = oneDFields{k};
    if isfield(d,f)
        v = d.(f);
        v = v(:).';                      % force 1×N
        if numel(v) >= nch
            d.(f) = v(1:nch);
        else
            d.(f) = [v, zeros(1, nch-numel(v))];
        end
    end
end

% Matrices N×3 : intensity, rgb
if isfield(d,'intensity')
    v = d.intensity;
    if size(v,1) >= nch
        d.intensity = v(1:nch, :);
    else
        d.intensity = [v; zeros(nch-size(v,1), 3)];
    end
end
if isfield(d,'rgb')
    v = d.rgb;
    if size(v,1) >= nch
        d.rgb = v(1:nch, :);
    else
        d.rgb = [v; ones(nch-size(v,1), 3)];  % par défaut blanc
    end
end

% % displaylim : 2×N
% if isfield(d,'displaylim')
%     v = d.displaylim;
%     if size(v,2) >= nch
%         d.displaylim = v(:,1:nch);
%     else
%         add = repmat([0;1], 1, nch-size(v,2));
%         d.displaylim = [v, add];
%     end
% end

roiObj.display = d;
end

function tf = isPixelAnnotationClassifier(classif, category)
pixelCategories = ["Pixel", "Object", "Delta", "Pedigree"];
tf = any(strcmpi(category, pixelCategories));

if tf
    return;
end

signals = strings(1, 0);
try, signals(end+1) = string(classif.classifierPkg); end %#ok<AGROW>
try, signals(end+1) = string(classif.trainingFun); end %#ok<AGROW>
try, signals(end+1) = string(classif.classifyFun); end %#ok<AGROW>
try, signals(end+1) = string(classif.description); end %#ok<AGROW>

signals = lower(signals);
tf = any(contains(signals, "deeplab_pixel_classification")) || ...
     any(contains(signals, "trainpixeldeeplabnetfun")) || ...
     any(contains(signals, "classifypixeldeeplabnetfun")) || ...
     any(contains(signals, "pixel"));
end











