function log(obj,message,category)
% logs a message associated with ROI processing 
% if category is provided , then a specific category is mentionned in the
% table that lists all messages. Allowed categories are : 
%'Dependency','Processing','Loading','Saving'
% Processing is the default category

if nargin<=2
    category='Processing';
end

obj.history(end+1,:)={datetime,string(category),string(message)};
