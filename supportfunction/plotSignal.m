function []=plotSignal(obj,varargin)

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

if isfield(classi.roi(r).results,'signal')
    resultFields=fields(classi.roi(r).results.signal); %full, cell, nucleus
    %essayer try catch
    for rf=resultFields
        classiFields=fields(classi.roi(r).results.signal.(rf)); %classi
        for cf=classiFields
            fluoFields=fields(classi.roi(r).results.signal.(rf).(cf)); %max, mean, volume...
            for ff=fluoFields
                for chan=1:numel(classi.roi(r).results.signal.(rf).(cf)(:,1)) %channels
                    tt=1;
                    if timeOrGen==0
                        figure;
                        plot(classi.roi(r).results.signal.(rf).(cf)(chan,:))
                        title([rf '.' cf '.' chan])
                    end
                    if timeOrGen==1
                        figure;
                        
                        for i=rois
                            plot(obj(i).divSignal.(rf).(cf)(chan,t))
                            hold on
                        end
                    end
                end
            end
        end
    end
end
