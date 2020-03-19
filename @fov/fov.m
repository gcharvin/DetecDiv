classdef fov < handle
     properties

      tag='shallow project';
      
   end
   methods
       function obj = pro(pathname,filename) % filename contains a list of path to images used in the movi project
            obj.props.path=pathname;
            obj.props.name=filename;
            
            
       end
       function properties(obj)
           fprintf('ok');
           obj.props
          
       end
       function save(obj)
           s = inputname(1)
           save('test.mat',s);
       end
   end
end