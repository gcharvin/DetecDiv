classdef dataseries < handle
    properties
        % default properties with values
        id=''; % unique to identify a a particular dataset : x = dec2hex(randi([1 2^52]));

        groupid=''; % if it belongs to a given group of data
        parentid=''; % object id from which it was derived

        data=table; % value is an array
        class (1,1) string {mustBeMember(class, ["classification","regression","processing","other"])} = "other";
        type (1,1) string {mustBeMember(type, ["temporal","generation","other"])} = "temporal";

        % interval=1; % time interval in case it's temporal data;

        plotGroup;
        plotProperties;
        description; % information about the dataset; this can be an object which specifiies classes for classificaiton
        history;
        userData;
        show=true ; % whether this dataset must be plotted when plot function is called


    end
    methods
        function obj = dataseries(data,datanames,varargin) % constructor function

            %%%% warining : data must me a table , otherwise this created
            %%%% an error 

            if nargin==0
                data=table;
            end

            obj.id= dec2hex(randi([1 2^52]));

            for i=1:numel(varargin)
                if strcmp(varargin{i},'class')
                    if numel(find(matches( ["classification","regression","processing","other"],varargin{i+1})))
                        obj.class=varargin{i+1};
                    else
                        disp('this class does not exist');
                        return;
                    end
                end
                
                if strcmp(varargin{i},'type')
                    if numel(find(matches(["temporal","","other"],varargin{i+1})))
                        obj.type=varargin{i+1};
                    else
                        disp('this type does not exist');
                        return;
                    end
                end
                 if strcmp(varargin{i},'groupid') % actual name of the dataseries
                    obj.groupid=varargin{i+1};
                 end
                  if strcmp(varargin{i},'parentid')
                    obj.parentid=varargin{i+1};
                  end

                  if strcmp(varargin{i},'groups') % cell array representing the different subgroups of the dataset
                    obj.plotGroup={[] [] [] [] [] varargin{i+1}};
                  end

            end


            if istable(data)
            obj.data=data;
            else
            obj.addData(data,datanames);
          %  obj=
            %disp('Input data is not a table, therefore the object is void of data');
            end

            % build default group and plotproperties 

            si=size(obj.data);

            defplot=cell(1,size(si,2));
            defplot(:)={false};
            groups=cell(1,size(si,2));
            groups(:)={''};


            for i=1:numel(varargin)
                 if strcmp(varargin{i},'plot') % cell array representing the different subgroups of the dataset
                    defplot=varargin{i+1};
                 end

                 if strcmp(varargin{i},'groups')
                    groups=varargin{i+1};
                 end
            end

            t={};
            varnames=obj.data.Properties.VariableNames;

                 for i=1:numel(varnames)
       
                   t{i,1}= defplot{i};
                   t{i,2}= varnames{i};
               
                   t{i,3}= class(obj.data.(varnames{i}));
                   t{i,4}= 'k';
                   t{i,5}= 2;
                    
                   % here : how to manage default groups !
                   % add a property in varargin to deal with grouping
                   % subdata


%                    if numel(find(contains(varnames{i},'id')))
%                    t{i,6}= 'id';
%                    end
%                    if numel(find(contains(varnames{i},'prob')))
%                    t{i,6}= 'prob';
%                    end
%                    if numel(find(contains(varnames{i},'labels')))
%                    t{i,6}= 'labels';
%                    end

                    t{i,6}=groups{i};
                 end

             obj.plotProperties=t;
             obj.plotGroup={[] [] [] [] [] unique(groups)};
        end

        function addData(obj,arr,arrname, varargin)

            sz=size(obj.data);

            groupitem=[];
            toplot=false; 

            for i=1:numel(varargin)
                if strcmp(varargin{i},'groups')
                    groupitem=varargin{i+1};
                end
                if strcmp(varargin{i},'plot')
                    toplot=varargin{i+1};
                end

            end
            
            if numel(groupitem)==0
                groupitem=obj.plotGroup{6}{end};
            end

            groups=[obj.plotGroup{6} groupitem];

            if ischar(arrname)
                arrname={arrname};
            end

             outname={};
            if ( size(arr,2)~=numel(arrname)) %& sz(1)~=0 && | size(arr,1)~=sz(1) 
                disp('Wrong number of items in the list...Adjusting name of dataset');

                for i=1:size(arr,2)
                     outname{i}=[arrname{1} '_' num2str(i)];
                end
            else
                outname=arrname;
            end

            for i=1:size(arr,2)
                    obj.data.(outname{i})=arr(:,i);
            end

            obj.plotProperties(end+1,:)=obj.plotProperties(end,:);
            obj.plotProperties{end,1}=toplot;
            obj.plotProperties{end,6}=groupitem;
            obj.plotGroup={[] [] [] [] [] unique(groups)};
         

        end
        function newobj=copyData(obj)
            newobj=dataseries; 
            fields=fieldnames(obj);

            for i=1:numel(fields)
                if ~strcmp(fields{i},'id')
                    newobj.(fields{i})=obj.(fields{i});
                end
            end
        end

        function out=getData(obj,subdatasetname,varargin)
            % returns an array if the input is a char
            % returns a table if the input is cell array of string

            data=obj.data;
            out=[];

            if nargin==2
                if iscell(subdatasetname)
                   out=table;

                    for i=1:numel(subdatasetname)
                        if numel(find(matches(data.Properties.VariableNames,subdatasetname{i})))
                            out.(subdatasetname{i})=data.(subdatasetname{i});
                        end
                    end
                elseif ischar(subdatasetname)
                    
                        if numel(find(matches(data.Properties.VariableNames,subdatasetname)))
                                 out=data.(subdatasetname);
                        end
                end
            else

              out=data;
              
            end

        end
        function out=dataSize(obj)
            out=size(obj.data);
        end


    end
end
