function []=plotSignal(roiobj,varargin)
%classi script

timeOrGen=0; %time
load=0;

for i=1:numel(varargin)
    if strcmp(varargin{i},'Generation')
        timeOrGen=1;
    end
    
    if strcmp(varargin{i},'Load') %load data
        load=1;
    end
 
end

if timeOrGen==1

end


%% load data if required
if load==1
    for r=1:numel(roiobj)
        roiobj(r).load('results');
    end
end
       
%% ask signal
if isfield(roiobj(1).results,'signal')
    liststrid=fields(roiobj(1).results.signal); %full, cell, nucleus
    str=[];
else
    error(['The roi ' roiobj(1) 'has no signal. Extract it using extractSignal'])
end
for i=1:numel(liststrid)
    str=[str num2str(i) ' - ' liststrid{i} ';'];
end
signalid=input(['Which signal extraction type? (Default: 1)' str]);
if numel(signalid)==0
    signalid=1;
end
signalstrid=liststrid{signalid};

%% ask classistrid

liststrid=fields(roiobj(1).results.signal.(signalstrid));
str=[];

for i=1:numel(liststrid)
    str=[str num2str(i) ' - ' liststrid{i} ';'];
end
classifid=input(['Which classi used for extracting signal? (Default: 1)' str]);
if numel(classifid)==0
    classifid=1;
end
classifstrid=liststrid{classifid};

%% ask fluo

liststrid=fields(roiobj(1).results.signal.(signalstrid).(classifstrid));
str=[];

for i=1:numel(liststrid)
    str=[str num2str(i) ' - ' liststrid{i} ';'];
end
fluoid=input(['Which type of signal? (Default: 1)' str]);
if numel(fluoid)==0
    fluoid=1;
end
fluostrid=liststrid{fluoid};


%% ask channel
channumber=size(roiobj(1).results.signal.(signalstrid).(classifstrid).(fluostrid),1);
str=[];

chanid=input(['Which channel ? (Default: 1)' num2str(1:channumber)]);
if numel(chanid)==0
    chanid=1;
end

%% data to vector
for r=1:numel(roiobj) 
    if isfield(roiobj(r).results,'signal')
        if isfield(roiobj(r).results.signal,signalstrid)
            if isfield(roiobj(r).results.signal.(signalstrid),classifstrid)
                
                
                if timeOrGen==0
                    for chan=chanid
                        data(r,:)=roiobj(r).results.signal.(signalstrid).(classifstrid).(fluostrid)(chan,:);
                        hold on
                    end
                end
                if timeOrGen==1
                    data(r,:)=roiobj(r).results.RLS.divSignal.(signalstrid).(fluostrid)(chan,:);
                    hold on
                end
                
                
            else
                error(['The roi ' roiobj(r) 'has no ' signalstrid 'signal from classi ' classifstrid ', be sure extracted it well, using extractSignal'])
            end
        else
            error(['The roi ' roiobj(r) 'has no ' signalstrid 'signal, be sure extracted it, using extractSignal'])
        end
    else
        error(['The roi ' roiobj(r) 'has no signal. Extract it using extractSignal'])
    end     
end

%% plot
    %all
    figure;
    for r=1:numel(roiobj)
        hold on
        plot(data(r,:))
    end
    
    %averaged value
    figure;
    plot(mean(data,1))
end

