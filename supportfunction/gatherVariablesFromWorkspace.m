function list= gatherVariablesFromWorkspace

            varlist=evalin('base','who');
            st=struct('Project',{''},'Classifier',{''},'Projectpos',{''},'Projectclassi',{''});
            cc=0;
            cd=0;
            list=[];


            for i=1:numel(varlist)

                if strcmp(varlist{i},'ans')
                    continue;
                end

                tmp=evalin('base',varlist{i});

                if isa(tmp,'shallow')
                    disp('this is a shallow object')
                    cc=cc+1;

                    st.Project{cc}=varlist{i};

                    tmpclassi={};

                    for k=1:numel(tmp.processing.classification)
                        %  k
                        tmpclassi = [tmpclassi tmp.processing.classification(k).strid];
                    end

                    st.Projectclassi{cc}=tmpclassi;

                    tmpproj={};

                    for k=1:numel(tmp.fov)
                        %  k
                        tmpproj = [tmpproj tmp.fov(k).id];
                    end

                    st.Projectpos{cc}=tmpproj;
                end

                if isa(tmp,'classi')

                    disp('this is a classification object')
                    cd=cd+1;
                    st.Classifier{cd}=varlist{i};
                    % aa= st.Classifier{cd}
                end

            end

list=st;
