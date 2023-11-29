function plotData(datagroups,filename,varargin)
% plot dataseries from rois as a collection of single cell traj and/or
% averages

% for single cells , one plot per datagroup and per datatype (mean, max 20
% pixels)

% for averages, put all datagroups on one plot to compare the datagroups,
% provide averag, standard deviation and bootstrap for standard error on
% mean

% special plot for RLS data : event / div duration : ecf function : plot
% reletaed to the number of events in array

[p ,f ,ext]=fileparts(filename);

col=lines(numel(datagroups));

leg={};

for i=1:numel(datagroups)
    dat=datagroups(i).Source.nodename;
    for j=1:numel(dat) % loop on plotted data types
        leg{j}{2*i-1}=datagroups(i).Name;
        leg{j}{2*i}='';

        strname=fullfile(filename,['average_' dat{j}{1} '_' dat{j}{2}]);
        outfile=[strname  '.xlsx']; %write as xlsx is important , otherwise throw an error with large files

        if exist(outfile)
            delete(outfile);
        end
    end
end

for i=1:numel(datagroups)

    if ~isfield(datagroups(i).Source,'nodename') % user did not check any node, so skip plotting
        continue
    end

    dat=datagroups(i).Source.nodename;

    rois=datagroups(i).Data.roiobj;

    for j=1:numel(dat) % loop on plotted data types
        str=[datagroups(i).Name ' // ' dat{j}{1} ' // ' dat{j}{2}];

        d=dat{j};

        xout={};
        yout={};

        cc=1;
        for k=1:numel(rois)
            groups={rois(k).data.groupid};
            pix=find(matches(groups,d{1}));

            if numel(pix)

                yout{end+1}= rois(k).data(pix).getData(d{2});

                % tmp=rois(k).data(pix).getData(d{2})

                tmp=1:numel(yout{end});
                xout{end+1}=tmp';

                if strcmp(datagroups(i).Param.Plot_type{end},'generation')
                    switch datagroups(i).Param.Traj_synchronization{end}
                        case 'sep'
                            xout{end}= rois(k).data(pix).getData('sep');
                        case 'death'
                            xout{end}= rois(k).data(pix).getData('death');
                        otherwise % birth
                            xout{end}= rois(k).data(pix).getData('birth');
                    end
                end
                cc=cc+1;
            end
        end

        cmap=lines(numel(xout));
        cmapcell = mat2cell(cmap, ones(numel(xout),1), 3);

        if datagroups(i).Param.Plot_singletraj
            h(i,j)=figure('Color','w','Tag',['plot_singletraj' num2str(i) '_' num2str(j)],'Name',str);
            hold on;

            cellfun(@(x, y, c) plot(x, y, 'Color',c), xout, yout, cmapcell', 'UniformOutput', false);

            title(datagroups(i).Name,'Interpreter','none');

            if strcmp(datagroups(i).Param.Plot_type{end},'temporal')
                xlabel('Time (frames)');
            end
            if strcmp(datagroups(i).Param.Plot_type{end},'generation')
                xlabel('Generation');
            end

            ylabel(dat{j}{2},'Interpreter','None');
        end

        if datagroups(i).Param.Plot_average  % plot average curve

            htmp=findobj('Tag',['plot_average_' dat{j}{2}]);

            if numel(htmp)==0
                havg(j)=figure('Color','w','Tag',['plot_average_' dat{j}{2}],'Name',dat{j}{2});
            else
                havg(j)=htmp;
            end

            if strcmp(datagroups(i).Param.Plot_type{end},'generation')   && ~strcmp(d{2},'event') % don t do it if if  RLS survival curve

                yout=cellfun(@(x,y) y(~isnan(x)), xout,yout,'UniformOutput',false);
                xout=cellfun(@(x) x(~isnan(x)), xout,'UniformOutput',false);

                valMin = cellfun(@(x) min(x), xout);
                totMin=min(valMin)-1;
                valMax = cellfun(@(x) max(x), xout);
                totMax=max(valMax)+1;

                totMax= num2cell(totMax*ones(1,numel(valMax)));
                totMin=  num2cell(-totMin*ones(1,numel(valMin)));

                len=cellfun(@(x) length(x), xout,'UniformOutput',false);

                valMax = cellfun(@(x,y) x-y,  totMax,len,'UniformOutput',false);
                valMin = cellfun(@(x,y) x-y,  totMin,len,'UniformOutput',false);

                switch datagroups(i).Param.Traj_synchronization{end}
                    case 'sep'

                        lenMin=cellfun(@(x) length(find(x<=0)), xout,'UniformOutput',false);
                        lenMax=cellfun(@(x) length(find(x>=0)), xout,'UniformOutput',false);

                        valMax = cellfun(@(x,y) x-y,  totMax,lenMax,'UniformOutput',false);
                        valMin = cellfun(@(x,y) x-y,  totMin,lenMin,'UniformOutput',false);

                        paddedx=cellfun(@(x,y) padarray(x, [y 0],NaN,'pre'),xout,valMin,'UniformOutput',false);
                        paddedy=cellfun(@(x,y) padarray(x, [y 0],NaN,'pre'),yout,valMin,'UniformOutput',false);

                        paddedx=cellfun(@(x,y) padarray(x, [y 0],NaN,'post'),paddedx,valMax,'UniformOutput',false);
                        paddedy=cellfun(@(x,y) padarray(x, [y 0],NaN,'post'),paddedy,valMax,'UniformOutput',false);

                    case 'death'
                        paddedx=cellfun(@(x,y) padarray(x, [y 0],NaN,'pre'),xout,valMin,'UniformOutput',false);
                        paddedy=cellfun(@(x,y) padarray(x, [y 0],NaN,'pre'),yout,valMin,'UniformOutput',false);
                    otherwise % birth
                        paddedx=cellfun(@(x,y) padarray(x, [y 0],NaN,'post'),xout,valMax,'UniformOutput',false);
                        paddedy=cellfun(@(x,y) padarray(x, [y 0],NaN,'post'),yout,valMax,'UniformOutput',false);
                end

                listx=cell2mat(paddedx);
                listy=cell2mat(paddedy);
            end

            if strcmp(datagroups(i).Param.Plot_type{end},'temporal')

                isScalarNonEmpty = @(x,y) ~isempty(x) && isnumeric(x) && ~isempty(y) && isnumeric(y);

                scalarNonEmptyIndex = cellfun(isScalarNonEmpty, xout,yout);
                xout = xout(scalarNonEmptyIndex);
                yout=yout(scalarNonEmptyIndex);


                if numel(yout)==0
                    disp('One of the variable you are trying to plot is empty or not numeric!')
                    continue
                end

                valMax = cellfun(@(x) max(x), xout);

                totMax=max(valMax)+1;

                totMax= num2cell(totMax*ones(1,numel(valMax)));
                % totMin=  num2cell(-totMin*ones(1,numel(valMin)));

                len=cellfun(@(x) length(x), xout,'UniformOutput',false);

                valMax = cellfun(@(x,y) x-y,  totMax,len,'UniformOutput',false);
                %   valMin = cellfun(@(x,y) x-y,  totMin,len,'UniformOutput',false);

                switch datagroups(i).Param.Traj_synchronization{end}
                    case 'sep'
                        disp('SEP synchro is not compatible with temporal display mode !');

                    case 'death'
                        paddedx=cellfun(@(x,y) padarray(x, [y 0],NaN,'pre'),xout,valMax,'UniformOutput',false);
                        paddedy=cellfun(@(x,y) padarray(x, [y 0],NaN,'pre'),yout,valMax,'UniformOutput',false);
                    otherwise % birth
                        %   paddedx=cellfun(@(x,y) padarray(x, [y 0],NaN,'post'),xout,valMax,'UniformOutput',false);
                        paddedx = cellfun(@(x, padSize) padarray(x, [padSize, 0], nan, 'post'), ...
                            xout, valMax, 'UniformOutput', false);

                        paddedy = cellfun(@(x, padSize) padarray(x, [padSize, 0], nan, 'post'), ...
                            yout, valMax, 'UniformOutput', false);

                        %  paddedy=cellfun(@(x,y) padarray(x, [y 0],NaN,'post'),yout,valMax,'UniformOutput',false);
                end

                listx=cell2mat(paddedx);
                listy=cell2mat(paddedy);

            end

            if ~strcmp(d{2},'event')  % plot the average data , unless the user requests to plot the RLS curve

                meanx=min(listx(:)):max(listx(:));
                meany=mean(listy,2,"omitnan"); meany=meany'; meany=meany(~isnan(meany));
                stdy = std(listy,0,2,"omitnan")./sqrt(sum(~isnan(listy),2)); stdy=stdy'; stdy=stdy(~isnan(stdy));

                mi=uint16(min(size(meanx,2),size(meany,2)));
                meanx=meanx(1:mi);
                meany=meany(1:mi);
                stdy=stdy(1:mi);

                %[rlsb] = bootstrp(Nboot,@(x)x,rlst);
                % rlsb=[rlst; rlsb ]; %add the real one in addition to the bootstrap

                figure(havg(j)); hold on;
                plot(meanx, meany,'Color',col(i,:),'LineWidth',2);
                closedxt = [meanx fliplr(meanx)];
                inBetween = [meany+stdy fliplr(meany-stdy)];

                tmp=[];
                tmp(1,:)=meanx;
                tmp(2,:)=meany;
                tmp(3,:)=stdy;

                tmp=num2cell(tmp);
                tmp=[ {datagroups(i).Name; ' '; ' '} , {'abscissa'; 'mean'; 'sem'},  tmp];
                % tmp=[ {'abscissa'; 'mean'; 'sem'} tmp];

                ptch=patch(closedxt, inBetween',col(i,:));
                
                if numel(ptch)
                    ptch.EdgeColor=col(i,:);
                    ptch.FaceAlpha=0.15;
                    ptch.EdgeAlpha=0.3;
                    ptch.LineWidth=1;

                end

                warning off all
                legend(leg{j});
                warning on all

                if strcmp(datagroups(i).Param.Plot_type{end},'temporal')
                    xlabel('Time (frames)');
                end
                if strcmp(datagroups(i).Param.Plot_type{end},'generation')
                    xlabel('Generation');
                end

                ylabel(dat{j}{2},'Interpreter','None');

            else % rls curve correspondinf to "event" subdataset

                censored=cellfun(@(x) x(end)==categorical("stillAlive"),yout); % censored cells are those that are still alive at the end of the movie
                ngen=cellfun(@(x) length(x),yout)-1;

                [yt,xt,flo,fup]=ecdf(ngen,'Censoring',censored);

                xt(1)=0;
                figure(havg(j)); hold on;
                plot(xt,1-yt,'LineWidth',2,'color',col(i,:));


                tmp=[];
                tmp(1,:)=xt;
                tmp(2,:)=1-yt;
                tmp(3,:)=(fup-flo)/2;

                tmp=num2cell(tmp);
                tmp=[ {datagroups(i).Name; ' '; ' '},  {'abscissa'; 'mean'; 'sem'} tmp];

                leg{j}{2*i-1}=[ leg{j}{2*i-1} ' - Median=' num2str(median(ngen)) ' (N=' num2str(length(ngen)) ')'];

                fup(1)=0;
                fup(end)=1;
                flo(1)=0;
                flo(end)=1;
                closedxt = [xt', fliplr(xt')];
                inBetween = [1-fup', fliplr(1-flo')];
                ptch=patch(closedxt, inBetween,col(i,:));
                ptch.EdgeColor=col(i,:);
                ptch.FaceAlpha=0.15;
                ptch.EdgeAlpha=0.3;
                ptch.LineWidth=1;

                warning off all
                legend(leg{j});
                warning on all

                ylabel('Survival')
                xlabel('Generations')

            end

            strname=fullfile(filename,['average_' dat{j}{1} '_' dat{j}{2}]);
            outfile=[strname  '.xlsx']; %write as xlsx is important , otherwise throw an error with large files
            writecell(tmp,outfile,'WriteMode','append');
        end
    end
end

for i=1:numel(datagroups)
    dat=datagroups(i).Source.nodename;
    for j=1:numel(dat) % loop on plotted data types
        strname=fullfile(filename,[datagroups(i).Name '_' dat{j}{1} '_' dat{j}{2}]);
        exportgraphics(h(i,j),[strname '.pdf'],'BackgroundColor','None');
        savefig(h(i,j),[strname '.fig']);
    end
end


disp('Export is done !')

