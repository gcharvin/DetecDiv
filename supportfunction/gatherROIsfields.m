function fields = gatherROIsfields(rois,datatype)

% for each of the rois in input, based on the type of data (mostly temporal
% or generation) , it returns the names of the dataseries and the subdatasets. 

            fields=[];
            %fields={[] [] []};
            fields.Results={[] [] []};

            if numel(rois)==0
                return
            end

            % results fields
            tmpr={};
            idx={};

            cc=1;

            for i=1:numel(rois)
                rois(i).load('data');
                for j=1:numel(rois(i).data)
                    if rois(i).data(j).type==string(datatype)
                        tmpr=[tmpr rois(i).data(j).groupid];
                        idx=[idx rois(i).data(j).id];
                        cc=cc+1;
                    end
                end
            end

            [tmpr,ia]=unique(tmpr);

            %   tmpr=tmpr(ia)

            subt={};
            subcat={};


            for i=1:numel(tmpr)

                tt={};
                catr={};

                for j=1:numel(rois)

                    pix=find(matches({rois(j).data.groupid},tmpr(i)));

                    if numel(pix)
                        %pix=matches(tmpr2,tmpr{i});

                        % if sum(pix)>0

                        subtmpr=rois(j).data(pix).data.Properties.VariableNames;

                        si=rois(j).data(pix).dataSize;

                        for k=1:numel(subtmpr)
                            %
                            %                                 if ~isstruct(rois(j).results.(tmpr2{pix}).(subtmpr{k}))
                            %
                            tt=[tt subtmpr(k)];
                            %

                            catr=[catr [' // ' num2str(si(1)) ' elements // ' class(rois(j).data(pix).data.(subtmpr{k})) ' ']];
                            %                                 end
                            %                             end
                        end


                    end
                    %   end
                end

                [ttt,iaa,~]=unique(tt);
                catrr=catr(iaa);

                subt{i}=ttt;
                subcat{i}=catrr;
            end

            % subt,subcat
            fields.Results={tmpr subt}; % subcat};
        end
    