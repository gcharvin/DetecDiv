function list= gatherVariablesFromWorkspace(filter)

% collects all the variable names in the workspace related to detecdiv :
% projects & classifiers

% if filter is provided, then only the classi with apropriate names are
% returned


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
                    
                   % if nargin==0 % remove project var if filter is provided 
                    st.Project{cc}=varlist{i};
                  %  end

                    tmpclassi={};

                    for k=1:numel(tmp.processing.classification)
                        %  k

                        if nargin==1
                        if contains(filter,tmp.processing.classification(k).strid)
                        tmpclassi = [tmpclassi tmp.processing.classification(k).strid];
                        end
                        else
                         tmpclassi = [tmpclassi tmp.processing.classification(k).strid];
                        end
                    end

                    st.Projectclassi{cc}=tmpclassi;

                    tmpproj={};

                    for k=1:numel(tmp.fov)
                        %  k
                        tmpproj = [tmpproj tmp.fov(k).id];
                    end

                      if nargin==0 % remove project var if filter is provided 
                    st.Projectpos{cc}=tmpproj;
                      end
                end

                if isa(tmp,'classi')

                    disp('this is a classification object')
                    cd=cd+1;
                      if nargin==1
                        if contains(filter,tmp.strid)
st.Classifier{cd}=varlist{i};
                        end
                      else
st.Classifier{cd}=varlist{i};
                      end
                    
                    % aa= st.Classifier{cd}
                end

            end

list=st;
