function []=plotSignal(roiobj,varargin)
%classi script

timeOrGen=0; %time

for i=1:numel(varargin)
    if strcmp(varargin{i},'Generation')
        timeOrGen=1;
    end
end

if timeOrGen==1
    prompt='Indicate Rois to plot';
    rois=input(prompt);
end


%% ask signal
if isfield(roiobj(r).results,'signal')
    liststrid=fields(roiobj(r).results.signal); %full, cell, nucleus
    str=[];
else
    error(['The roi ' roiobj(1) 'has no signal. Extract it using extractSignal'])
end
signalid=input(['Which signal extraction type? (Default: 1)' str]);
if numel(signalid)==0
    signalid=1;
end
signalstrid=liststrid{signalid};

%% ask classistrid

liststrid=fields(roiobj(1).results.signal(signalstrid));
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
if numel(classifid)==0
    fluoid=1;
end
fluostrid=liststrid{fluoid};


%% ask channel
liststrid=fields(roiobj(1).results.signal.(signalstrid).(classifstrid).(fluostrid));
str=[];
for i=1:numel(liststrid)
    str=[str num2str(i) ' - ' liststrid{i} ';'];
end
chanid=input(['Which type of signal? (Default: 2)' str]);
if numel(classifid)==0
    chanid=2;
end

%%
figure;
for r=1:numel(roiobj) 
    if isfield(roiobj(r).results,'signal')
        if isfield(roiobj(1).results.signal,signalstrid)
            if isfield(roiobj(1).results.signal.(signalstrid),classifstrid)
                if timeOrGen==0
                    for chan=chanid
                        plot(roiobj(r).results.signal.(signalstrid).(classifstrid).(fluostrid)(chan,:))
                    end
                end
                if timeOrGen==1
                    plot(roiobj(r).results.RLS.divSignal.(signalstrid).(fluostrid)(chan,t))
                    hold on
                end
            else
                error(['The roi ' roiobj(1) 'has no ' signalstrid 'signal from classi ' classifstrid ', be sure extracted it well, using extractSignal'])
            end
        else
            error(['The roi ' roiobj(1) 'has no ' signalstrid 'signal, be sure extracted it, using extractSignal'])
        end
    else
        error(['The roi ' roiobj(1) 'has no signal. Extract it using extractSignal'])
    end        
end
