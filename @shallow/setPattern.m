function setPattern(obj,fovid,roiid,frameid,channelid)
% a pattern is an image used to look for all possible ROIs in field of view based on
% a given pattern. 

% a pattern is defined from a used defined ROI in a given field of view

% arguments :
% fovid: id of the field of view in which a user defined ROI is present
% roiid: id of the roiid in which the defined is roi is present
% frameid: etc...
% channel id: etc...

if nargin==2
    frameid=1;
    channelid=1;
end

roitmp=obj.fov(fovid).roi(roiid);

tmp=readImage(obj.fov(fovid),frameid,channelid);

figure, imshow(tmp,[]);

%obj.pattern=pattern;
