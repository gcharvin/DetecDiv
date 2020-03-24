function setPattern(obj,fovid,roiid,frameid)
% a pattern is an image used to look for all possible ROIs in field of view based on
% a given pattern. 

% a pattern is defined from a used defined ROI in a given field of view

% arguments :
% fovid: id of the field of view in which a user defined ROI is present
% roiid: id of the roiid in which the defined is roi is present
% frameid: etc...
% channel id: etc...

if nargin<=3
    frameid=1;
   % channelid=1;
end

channelid=1;   % find pattern must be done on channel 1, knowing that ROIs are defined on such channel
roitmp=obj.fov(fovid).roi(roiid).value;

tmp=readImage(obj.fov(fovid),frameid,channelid);
tmp=tmp(roitmp(2):roitmp(2)+roitmp(4)-1,roitmp(1):roitmp(1)+roitmp(3)-1);

%figure, imshow(tmp,[]);

obj.processing.roi.pattern=tmp;
