classdef dataseries < handle
    properties
        % default properties with values
        id=''; % unique to identify a a particular dataset : x = dec2hex(randi([1 2^52]));

        groupid=''; % if it belongs to a given group of data
        parentid=''; % object id from which it was derived

        data=table; % value is an array
        class (1,1) string {mustBeMember(class, ["classification","regression","processing","other"])} = "other";
        type (1,1) string {mustBeMember(type, ["temporal","other"])} = "temporal";

        % interval=1; % time interval in case it's temporal data;

        plotGroup;
        plotProperties;
        description; % information about the dataset; this can be an object which specifiies classes for classificaiton
        history;
        userData;


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
                 if strcmp(varargin{i},'groupid')
                    obj.groupid=varargin{i+1};
                 end
                  if strcmp(varargin{i},'parentid')
                    obj.groupid=varargin{i+1};
                 end
            end


            if istable(data)
            obj.data=data;
            else
            obj.addData(data,datanames);
          %  obj=
            %disp('Input data is not a table, therefore the object is void of data');
            end

        end
        function addData(obj,arr,arrname)

            sz=size(obj.data);

            if ischar(arrname)
                arrname={arrname};
            end

            %arr,arrname,sz
            if (size(arr,1)~=sz(1) | size(arr,2)~=numel(arrname)) & sz(1)~=0
                disp('Wrong number of items in the list! Quitting...');
                return;
            else
                for i=1:size(arr,2)
               
                    obj.data.(arrname{i})=arr(:,i);
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
