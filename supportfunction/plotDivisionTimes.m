function plotDivisionTimes(datagroups,filename,varargin)
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

% here do implement divtimes analysis

leg={};
leg2=leg;

leg_md={};

cd=1;
clineage=1;

for i=1:numel(datagroups)
    cd(i)=0;
    clineage(i)=0;
    dat=datagroups(i).Source.nodename;

    if ~isfield(datagroups(i).Source,'nodename') % user did not check any node, so skip plotting
        continue
    end

    for j=1:numel(dat) % loop on plotted data types

        if strcmp(dat{j}{2},'divduration') % plotting division times data
            cd(i)=j;

            strname=fullfile(filename,['average_' dat{cd(i)}{1} '_' dat{cd(i)}{2}]);
            outfile=[strname  '.xlsx']; %write as xlsx is important , otherwise throw an error with large files

            if exist(outfile)
                delete(outfile);
            end

            % break
        end

        if strcmp(dat{j}{2},'lineage') % get M/D lineage data
            clineage(i)=j;

            % HERE

            strname_lin=fullfile(filename,['average_MD_' dat{cd(i)}{1} '_' dat{cd(i)}{2}]);
            outfile_lin=[strname_lin  '.xlsx']; %write as xlsx is important , otherwise throw an error with large files

            if exist(outfile_lin)
                delete(outfile_lin);
            end
            break

        end

        
    end

    if cd(i)==0
        disp(['Could not find the data required to plot division times in group ' num2str(i) ' ; Quitting ....'])
        return;
    end

    leg{i}=datagroups(i).Name;
    leg_md{i}{1}=datagroups(i).Name;

    leg2{2*i-1}=datagroups(i).Name;
    leg2{2*i}='';
end

for i=1:numel(datagroups)
    if ~isfield(datagroups(i).Source,'nodename') % user did not check any node, so skip plotting
        continue
    end

    dat=datagroups(i).Source.nodename;
    rois=datagroups(i).Data.roiobj;

    %   for j=1:numel(dat) % loop on plotted data types
    j=cd(i);

    str=[datagroups(i).Name ' // ' dat{j}{1} ' // ' dat{j}{2}];

    d=dat{j};
    xout={};
    yout={};
    ylineage={};
    cc=1;

    groups={rois(1).data.groupid};
    pix=find(matches(groups,d{1}));
    tt= rois(1).data(pix).getData(d{2});

    if ~isnumeric(tt)
        disp(['Those data:  ' num2str(d{1}) ' are not numeric, yet I expected numeric data; quitting ....' ]);
        return
    end

    for k=1:numel(rois)
        % collect the selected data

        groups={rois(k).data.groupid};
        pix=find(matches(groups,d{1}));

        if numel(pix)
            tt= rois(k).data(pix).getData(d{2});
            yout{end+1}= rois(k).data(pix).getData(d{2});

            if clineage(i)~=0
                ylineage{end+1}=rois(k).data(pix).getData('lineage');
            end

            tmp=1:numel(yout{end});
            xout{end+1}=tmp';

            if strcmp(datagroups(i).Type,'generation')
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
        else
            disp(['Could not find ' num2str(d{1}) 'in the available data']);
        end
    end

    % cmap=lines(numel(xout));
    % cmapcell = mat2cell(cmap, ones(numel(xout),1), 3);
    %
    % if datagroups(i).Param.Display_single_cell_plot
    %     h(i,j)=figure('Color','w','Tag',['plot_singletraj' num2str(i) '_' num2str(j)],'Name',str);
    %     hold on;
    %
    %     cellfun(@(x, y, c) plot(x, y, 'Color',c), xout, yout, cmapcell', 'UniformOutput', false);
    %
    %     title(datagroups(i).Name,'Interpreter','none');
    %
    %     if strcmp(datagroups(i).Type,'temporal')
    %         xlabel('Time (frames)');
    %     end
    %     if strcmp(datagroups(i).Type,'generation')
    %         xlabel('Generation');
    %     end
    %
    %     ylabel(dat{j}{2},'Interpreter','None');
    % end

    %   if datagroups(i).Param.Display_single_cell_plot
    % h(i,j)=figure('Color','w','Tag',['plot_singletraj' num2str(i) '_' num2str(j)],'Name',str);
    % hold on;
    %
    % cellfun(@(x, y, c) plot(x, y, 'Color',c), xout, yout, cmapcell', 'UniformOutput', false);
    %
    % title(datagroups(i).Name,'Interpreter','none');
    %
    % if strcmp(datagroups(i).Param.Plot_type{end},'temporal')
    %     xlabel('Time (frames)');
    % end
    % if strcmp(datagroups(i).Param.Plot_type{end},'generation')
    %     xlabel('Generation');
    % end
    %
    % ylabel(dat{j}{2},'Interpreter','None');
    %   end


    %    if datagroups(i).Param.Display_average  % plot average curve

    htmp=findobj('Tag',['plot_average_' dat{j}{2}]);

    if numel(htmp)==0
        havg=figure('Color','w','Tag',['plot_average_' dat{j}{2}],'Name',dat{j}{2});
    else
        havg=htmp;
    end

    htmp=findobj('Tag',['plot_average2_' dat{j}{2}]);

    if numel(htmp)==0
        havg2=figure('Color','w','Tag',['plot_average2_' dat{j}{2}],'Name',dat{j}{2});
    else
        havg2=htmp;
    end

    if clineage(i)~=0
        hlineage(i)=figure('Color','w','Tag',['plot_lineage_' dat{j}{2} '_group' num2str(i)],'Name',['Division times // lineage for group ' datagroups(i).Name]);
    end

    %   if strcmp(datagroups(i).Type,'generation')  % don t do it if if  RLS survival curve

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

    if clineage(i)~=0 % concatenate data for lineage specific averaging
        yout=cellfun(@(x,y) y(~isnan(x)), xout,ylineage,'UniformOutput',false);
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

        listxlineage=cell2mat(paddedx);
        listylineage=cell2mat(paddedy);
    end



    % plot the average data points after synchronization

    meanx=min(listx(:)):max(listx(:));
    meany=mean(listy,2,"omitnan"); meany=meany'; meany=meany(~isnan(meany));
    stdy = std(listy,0,2,"omitnan")./sqrt(sum(~isnan(listy),2)); stdy=stdy'; stdy=stdy(~isnan(stdy));

    mi=uint16(min(size(meanx,2),size(meany,2)));
    meanx=meanx(1:mi);
    meany=meany(1:mi);
    stdy=stdy(1:mi);

    %[rlsb] = bootstrp(Nboot,@(x)x,rlst);
    % rlsb=[rlst; rlsb ]; %add the real one in addition to the bootstrap

    figure(havg2); hold on;
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
    legend(leg2);
    warning on all

    xlabel('Generation');
    ylabel(dat{j}{2},'Interpreter','None');

    % save average as xlsx file
    strname=fullfile(filename,['average_' dat{j}{1} '_' dat{j}{2}]);
    outfile=[strname  '.xlsx']; %write as xlsx is important , otherwise throw an error with large files
    writecell(tmp,outfile,'WriteMode','append');

    % plot the histogram of division times , all the groups on the same
    % plot

    val=listy(:); val=val(~isnan(val));

    figure(havg); hold on;
    hs(i)=histogram(val);
    hs(i).Normalization='probability';
    hs(i).BinWidth=1;

    leg{i}=[leg{i}  ' - Median= ' num2str(median(val)) '+/-' num2str(std(val)) ' (N=' num2str(length(val)) ')'];

    warning off all
    legend(leg);
    warning on all

    ylabel('Probability');
    xlabel('Time (frames)');

    % plot the histogram of division times ,distinguishing mothers and
    % daughters

    if clineage(i)~=0 % concatenate data for lineage specific averaging

         tmplin=listylineage(:); m=tmplin==1; d= tmplin==0;

         divm=listy(m); divd=listy(d);

        %val=listy(:); val=val(~isnan(val));

        figure(hlineage(i)); hold on;
        hm(i)=histogram(divm);
        hm(i).Normalization='probability';
        hm(i).BinWidth=1;

        hd(i)=histogram(divd);
        hd(i).Normalization='probability';
        hd(i).BinWidth=1;

         leg_md{i}{2}= leg_md{i}{1};

        leg_md{i}{1}=[leg_md{i}{1}  ' Mothers - Median= ' num2str(median(divm)) '+/-' num2str(std(divm)) ' (N=' num2str(length(divm)) ')'];

        leg_md{i}{2}=[leg_md{i}{2}  ' Daughter  - Median= ' num2str(median(divd)) '+/-' num2str(std(divd)) ' (N=' num2str(length(divd)) ')'];

        warning off all
        legend(leg_md{i});
        warning on all

        ylabel('Probability');
        xlabel('Time (frames)');
    end


    %   strname=fullfile(filename,['average_' dat{j}{1} '_' dat{j}{2}]);
    %   outfile=[strname  '.xlsx']; %write as xlsx is important , otherwise throw an error with large files
    %   writecell(tmp,outfile,'WriteMode','append');
end



% for i=1:numel(datagroups)
%     dat=datagroups(i).Source.nodename;
%     %    for j=1:numel(dat) % loop on plotted data types
%     j=cd;
%   %  if plottable_data(i)
strname=fullfile(filename,['histogram_' dat{j}{1} '_' dat{j}{2}]);
exportgraphics(havg(j),[strname '.pdf'],'BackgroundColor','None');
%exportgraphics(havg(j),[strname '.pdf'],'BackgroundColor','None');
savefig(havg(j),[strname '.fig']);

% %    en
% end

disp('Export is done !')

