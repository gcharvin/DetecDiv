classdef dataseries < handle
   properties
      % default properties with values
      id='';
      value % value is an arry 
      class (1,1) string {mustBeMember(class, ["training","result"])} = "result";
       type (1,1) string {mustBeMember(type, ["temporal","other"])} = "temporal";
       interval=1; % time interval in case it's temporal data; 

       xlabel="Time";
       ylabel="mydata"; % can ba an array with the same size as the dim2 of the value array;

 %     size
      parentid; % object id from which it was derived
      group; % if it belongs to a given group of data

      description=''; % information about the dataset; 
      classes=[];
      userData;

      
    
   end
   methods
       function obj = dataseries(id,roiarr)
           %%%% here
           if nargin==0
               id='';
               roiarr=[];
           end
           
            obj.id=id;
            obj.value=roiarr;
    
       end
        function setValue(obj,value)
            obj.value=value;
        end
        function out=size(obj)
            out=size(obj.value);
        end
       
       
   end
end
