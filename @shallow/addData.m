function addData(obj,inputarg)

tmppath = pwd;

if nargin==1
    disp('Input data directory:');
    pathe = uigetdir(tmppath,'Select directory with data:');
    if pathe==0
        disp('Quit!');
        return;
    end
    newdata = parseInputData(pathe);
else
    if ischar(inputarg)
        pathe   = inputarg;
        newdata = parseInputData(pathe);
    else
        newdata = inputarg;
    end
end

% gestion de l'indice FOV à créer
nfov = numel(obj.fov);
if nfov==1 && numel(obj.fov.srclist)==0
    cc = 1;
else
    cc = nfov+1;
end

for i = 1:numel(newdata.pos)

    obj.fov(cc) = fov; % nouveau FOV

    % Préparer mtInfo si multi-TIFF
    mtInfo = struct();
    if isfield(newdata.pos(i),'isMultiTiff') && newdata.pos(i).isMultiTiff
        mtInfo.isMultiTiff = true;
        mtInfo.tiffSource  = newdata.pos(i).tiffSource; % cell{ch}
        mtInfo.pageMap     = newdata.pos(i).pageMap;    % cell{ch}, mapping frame->page
    end

    % Appeler setpathlist avec ou sans mtInfo
    if ~isempty(fieldnames(mtInfo))
        obj.fov(cc).setpathlist( ...
            newdata.pos(i).pathlist, ...
            cc, ...
            newdata.pos(i).filelist, ...
            newdata.pos(i).name, ...
            mtInfo);
    else
        obj.fov(cc).setpathlist( ...
            newdata.pos(i).pathlist, ...
            cc, ...
            newdata.pos(i).filelist, ...
            newdata.pos(i).name);
    end

    % NDTiff info
    if isfield(newdata.pos(i),'isNDTiff') && newdata.pos(i).isNDTiff
        obj.fov(cc).isNDTiff       = true;
        obj.fov(cc).ndtiffPath     = newdata.pos(i).ndtiffPath;
        obj.fov(cc).ndtiffPosition = newdata.pos(i).ndtiffPosition;
        obj.fov(cc).ndtiffChannels = newdata.pos(i).ndtiffChannels;
        if isfield(newdata.pos(i),'ndtiffZ')
            obj.fov(cc).ndtiffZ = newdata.pos(i).ndtiffZ;
        else
            obj.fov(cc).ndtiffZ = 0;
        end
    end

    % copier les autres infos
    if isfield(newdata.pos(i),'contours')
        obj.fov(cc).contours = newdata.pos(i).contours;
    else
        obj.fov(cc).contours = [];
    end

    obj.fov(cc).display.binning    = newdata.pos(i).binning;
    obj.fov(cc).display.intensity  = ones(1, size(newdata.pos(i).binning,2));
    obj.fov(cc).channel            = newdata.pos(i).channelname;
    obj.fov(cc).frames             = newdata.pos(i).frames;
    obj.fov(cc).interval           = newdata.pos(i).interval;
    obj.fov(cc).parent             = obj;

    cc = cc+1;
end

disp([num2str(numel(newdata.pos)) ' FOVs were added to the current project!']);
end
