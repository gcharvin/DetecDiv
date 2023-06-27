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

        for k=1:numel(rois)

            groups={rois(k).data.groupid};
            pix=find(matches(groups,d{1}));

            if numel(pix)

                yout{end+1}= rois(k).data(pix).getData(d{2});

                xout{end+1}=1:numel(yout);

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



            end
        end

        cmap=lines(numel(xout));
        cmapcell = mat2cell(cmap, ones(numel(xout),1), 3);

        if datagroups(i).Param.Plot_singletraj
            h(i,j)=figure('Color','w','Tag',['plot_singletraj' num2str(i) '_' num2str(j)],'Name',str);
            hold on;

            cellfun(@(x, y, c) plot(x, y, 'Color',c), xout, yout, cmapcell', 'UniformOutput', false); 

            if strcmp(datagroups(i).Param.Plot_type{end},'temporal')
                xlabel('Time (frames)');
            end
            if strcmp(datagroups(i).Param.Plot_type{end},'generation')
                xlabel('Generation');
            end

            ylabel(dat{j}{2},'Interpreter','None');
        end

        if datagroups(i).Param.Plot_average

            havg=findobj('Tag',['plot_average_' dat{j}{2}]);

            if numel(havg)==0
            havg=figure('Color','w','Tag',['plot_average_' dat{j}{2}],'Name',dat{j}{2});
            end
   
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

               if strcmp(datagroups(i).Param.Plot_type{end},'generation')
                    switch datagroups(i).Param.Traj_synchronization{end}
                        case 'sep'
                   
            valMin= cellfun(@(x) min(x), xout);
            totMin=min(valMin)-1;
            valMax= cellfun(@(x) max(x), xout);
            totMax=max(valMax)+1;

            totMax= num2cell(totMax*ones(1,numel(valMax)));
            totMin = num2cell(-totMin*ones(1,numel(valMin)));

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
               end

            

            listx=cell2mat(paddedx);
            listy=cell2mat(paddedy);

            meanx=min(listx(:)):max(listx(:));
            meany=mean(listy,2,"omitnan"); meany=meany';
            stdy = std(listy,0,2,"omitnan")./sqrt(sum(~isnan(listy),2)); stdy=stdy';

            %[rlsb] = bootstrp(Nboot,@(x)x,rlst);
           % rlsb=[rlst; rlsb ]; %add the real one in addition to the bootstrap

            figure(havg); hold on;
            plot(meanx, meany,'Color',col(i,:),'LineWidth',2); 
            closedxt = [meanx fliplr(meanx)];
            inBetween = [meany+stdy fliplr(meany-stdy)];

            ptch=patch(closedxt, inBetween',col(i,:));
            ptch.EdgeColor=col(i,:);
            ptch.FaceAlpha=0.15;
            ptch.EdgeAlpha=0.3;
            ptch.LineWidth=1;

             if strcmp(datagroups(i).Param.Plot_type{end},'temporal')
                xlabel('Time (frames)');
            end
            if strcmp(datagroups(i).Param.Plot_type{end},'generation')
                xlabel('Generation');
            end

            ylabel(dat{j}{2},'Interpreter','None');
    
 


        end


    end



end

return;



for i=1:numel(dat)
    if numel(dat)>0

        d=dat{i};

        outfile=fullfile(p,[f '_' d{1} '.xlsx']); %write as xlsx is important , otherwise throw an error with large files

        if exist(outfile)
            delete(outfile);
        end
    end
end

for i=1:numel(dat)
    if numel(dat)>0

        d=dat{i};

        strtot={};
        cc=1;
        for j=1:numel(rois)

            groups={rois(j).data.groupid};
            pix=find(matches(groups,d{1}));

            if numel(pix)
                out= rois(j).data(pix).getData(d{2});

                str={};
                str{1}=rois(j).id;

                if iscell(out)
                    str=[str out'];
                else
                    str2=num2cell(out');
                    ny=size(str2,1);
                    if ny>1
                        str(2:ny,1)={[]};
                    end

                    str=[str str2];
                end


                strtot((cc-1)*size(str,1)+1:cc*size(str,1),1:size(str,2))=str;
                cc=cc+1;

            end
        end

        if cc>1
            tt=fullfile(p,[f '_' d{1} '.xlsx']);

            writecell(strtot,fullfile(p,[f '_' d{1} '.xlsx']),'sheet',d{2},'WriteMode','overwritesheet');
        end
    end
end

disp('Export is done !')

