function combineChannels(obj,varargin)
% combine existing channels in ROI
%
% channels : ids or strid of channels to be merged into one new channel
% rgb      : cell array of [r g b] triplets per channel, or colormap (Nx3) for indexed images
% levels   : cell array of [low high] per channel (uint16 scale, default [0 65535])
% name     : output channel name
% debug    : true/false -> verbose logs

channels = [];
rgb      = {};
levels   = {};
name     = 'CombinedChannel';
debug    = false;

% ---------------- parse inputs ----------------
for i = 1:numel(varargin)
    if strcmp(varargin{i},'channels')
        channels = varargin{i+1};
    elseif strcmp(varargin{i},'rgb')
        rgb = varargin{i+1};
    elseif strcmp(varargin{i},'levels')
        levels = varargin{i+1};
    elseif strcmp(varargin{i},'name')
        name = varargin{i+1};
    elseif strcmp(varargin{i},'debug')
        debug = logical(varargin{i+1});
    end
end
% sanitize output channel name
if isstring(name) || ischar(name)
    name = strtrim(char(name));
end

fprintf('[combineChannels] ---- START ROI=%s output="%s" ----\n', tryGetROIid(obj), string(name));

if isempty(channels)
    fprintf('[combineChannels] no channel defined; quitting.\n');
    return
end

% normalize channels to cell
if ~iscell(channels)
    channels = num2cell(channels);
end

nCh = numel(channels);

% default levels
if isempty(levels)
    levels = cell(nCh,1);
    for j=1:nCh
        levels{j} = [0 65535];
    end
end

% normalize rgb
wantRGB = ~isempty(rgb);
if wantRGB
    if ~iscell(rgb), rgb = {rgb}; end
    if numel(rgb) ~= nCh
        fprintf('[combineChannels] WARNING rgb count (%d) != channels count (%d). Padding with white.\n', numel(rgb), nCh);
        rgb2 = cell(nCh,1);
        for j=1:nCh
            if j <= numel(rgb) && ~isempty(rgb{j})
                rgb2{j} = rgb{j};
            else
                rgb2{j} = [1 1 1];
            end
        end
        rgb = rgb2;
    end
end

% load image
if isempty(obj.image)
    fprintf('[combineChannels] obj.image empty -> load()\n');
    obj.load;
end
if isempty(obj.image)
    fprintf('[combineChannels] could not load image; quitting.\n');
    return;
end

H = size(obj.image,1);
W = size(obj.image,2);
C = size(obj.image,3);
T = size(obj.image,4);

fprintf('[combineChannels] obj.image size=%s class=%s (H=%d W=%d C=%d T=%d)\n', ...
    mat2str(size(obj.image)), class(obj.image), H, W, C, T);

if wantRGB
    matrix = zeros(H,W,3,T,'uint16');
    fprintf('[combineChannels] output mode = RGB\n');
else
    matrix = zeros(H,W,1,T,'uint16');
    fprintf('[combineChannels] output mode = MONO\n');
end
outIntensity = [1 1 1];

% ---------------- main loop ----------------
for iCh = 1:nCh

    ch = channels{iCh};

    % find channel indices
    pix2 = [];
    if ischar(ch) || (isstring(ch) && isscalar(ch))
        pix2 = obj.findChannelID(ch);
    elseif isnumeric(ch) && isscalar(ch)
        pix2 = find(obj.channelid == ch);
    elseif isnumeric(ch)
        for kk = 1:numel(ch)
            pix2 = [pix2 find(obj.channelid == ch(kk))]; %#ok<AGROW>
        end
    end

    fprintf('[combineChannels] -- i=%d/%d, query="%s" -> pix2=%s\n', iCh, nCh, string(ch), mat2str(pix2));

    if isempty(pix2)
        fprintf('[combineChannels] ERROR: channel "%s" not found -> quitting.\n', string(ch));
        return;
    end
    if any(pix2 > size(obj.image,3))
        fprintf('[combineChannels] ERROR: pix2 out of range for "%s" -> quitting.\n', string(ch));
        return;
    end

    % slice
    imtmp = obj.image(:,:,pix2,:); % HxWxKxT

    fprintf('[combineChannels] imtmp slice size=%s class=%s\n', mat2str(size(imtmp)), class(imtmp));

    % Force 16-bit interpretation if image is double but looks like uint16
if isa(imtmp,'double') || isa(imtmp,'single')
    % Heuristic: values look like 16-bit counts
    mx = max(imtmp(:));
    if mx > 1
        imtmp = uint16(max(0, min(65535, round(imtmp))));
        fprintf('[combineChannels] NOTE: imtmp was %s with max=%g -> cast to uint16 before imadjust.\n', class(obj.image), mx);
    end
end


    % if multiple matches, collapse
    if size(imtmp,3) > 1
        fprintf('[combineChannels] WARNING: pix2 has %d channels matched. Collapsing using MAX projection across 3rd dim.\n', size(imtmp,3));
        imtmp = max(imtmp, [], 3); % HxWx1xT
        fprintf('[combineChannels] imtmp collapsed size=%s\n', mat2str(size(imtmp)));
    end

    % levels
    lohi = levels{iCh};
    if isempty(lohi) || numel(lohi)~=2
        fprintf('[combineChannels] WARNING: bad levels for i=%d -> using [0 65535]\n', iCh);
        lohi = [0 65535];
    end
    fprintf('[combineChannels] levels=[%g %g]\n', lohi(1), lohi(2));

    % stats before adjust (first frame)
    try
        a0 = imtmp(:,:,1,1);
        fprintf('[combineChannels] pre-adjust (frame1) min=%g max=%g\n', double(min(a0(:))), double(max(a0(:))));
    catch
    end

    % --- make imadjust coherent w/ class and scale ---
if isa(imtmp,'double') || isa(imtmp,'single')
    mx = max(imtmp(:));
    % If values look like uint16 counts, cast before imadjust
    if mx > 1
        fprintf('[combineChannels] NOTE: imtmp is %s with max=%g (looks like uint16 scale) -> cast to uint16 before imadjust.\n', class(imtmp), mx);
        imtmp = uint16(max(0, min(65535, round(imtmp))));
    else
        % already in [0,1]
        fprintf('[combineChannels] NOTE: imtmp is %s in [0,1] scale.\n', class(imtmp));
    end
end

for j = 1:size(imtmp,4)
    imtmp(:,:,1,j) = imadjust(imtmp(:,:,1,j), [levels{iCh}(1)/65535 levels{iCh}(2)/65535]);
end
    % stats after adjust (first frame)
    try
        a1 = imtmp(:,:,1,1);
        fprintf('[combineChannels] post-adjust (frame1) min=%g max=%g\n', double(min(a1(:))), double(max(a1(:))));
    catch
    end

    if ~wantRGB
        % mono
        if size(imtmp,3) ~= 1
            fprintf('[combineChannels] WARNING: mono mode but imtmp C=%d -> taking first.\n', size(imtmp,3));
            imtmp = imtmp(:,:,1,:);
        end

        % cast
        if ~isa(imtmp,'uint16')
            fprintf('[combineChannels] casting imtmp %s -> uint16\n', class(imtmp));
            imtmp = uint16(imtmp);
        end

        if ~isequal(size(matrix), size(imtmp))
            fprintf('[combineChannels] ERROR SizeMismatch: matrix=%s vs imtmp=%s\n', mat2str(size(matrix)), mat2str(size(imtmp)));
            error('combineChannels:SizeMismatch','Size mismatch (mono).');
        end

        if debug
            fprintf('[combineChannels][debug] adding mono channel i=%d\n', iCh);
        end
        matrix = imadd(matrix, imtmp);

    else
        % RGB
        thisRGB = rgb{iCh};
        if isempty(thisRGB)
            thisRGB = [1 1 1];
        end

        fprintf('[combineChannels] rgb spec size=%s\n', mat2str(size(thisRGB)));

        if size(thisRGB,1) == 1
            % scalar channel -> replicate and scale (non-indexed RGB)
            imtmp = repmat(imtmp,[1 1 3 1]); % HxWx3xT

            for k=1:3
                imtmp(:,:,k,:) = thisRGB(k) * imtmp(:,:,k,:);
            end

            if ~isa(imtmp,'uint16')
                fprintf('[combineChannels] casting imtmp %s -> uint16\n', class(imtmp));
                imtmp = uint16(imtmp);
            end

            if ~isequal(size(matrix), size(imtmp))
                fprintf('[combineChannels] ERROR SizeMismatch: matrix=%s vs imtmp=%s\n', mat2str(size(matrix)), mat2str(size(imtmp)));
                error('combineChannels:SizeMismatch','Size mismatch (rgb scalar).');
            end

            if debug
                fprintf('[combineChannels][debug] adding RGB-scaled channel i=%d\n', iCh);
            end
            matrix = imadd(matrix, imtmp);

            % keep non-indexed
            outIntensity = [1 1 1];
        else
            % indexed colormap
            fprintf('[combineChannels] indexed colormap mode (N=%d colors)\n', size(thisRGB,1));
            for ii = 1:size(thisRGB,1)
                imtmp2 = zeros(H,W,3,T,'uint16');

                for j = 1:T
                    bw = uint16(imtmp(:,:,1,j) == ii);
                    if ~any(bw(:)), continue; end

                    bw = uint16(65535 * (lohi(2)/65535)) * bw;

                    imtmp2(:,:,1,j) = thisRGB(ii,1) * bw;
                    imtmp2(:,:,2,j) = thisRGB(ii,2) * bw;
                    imtmp2(:,:,3,j) = thisRGB(ii,3) * bw;
                end

                if debug
                    fprintf('[combineChannels][debug] add indexed color ii=%d rgb=[%g %g %g]\n', ii, thisRGB(ii,1), thisRGB(ii,2), thisRGB(ii,3));
                end
                matrix = imadd(matrix, imtmp2);
            end

            % indexed output
            outIntensity = [0 0 0];
        end
    end
end

fprintf('[combineChannels] final matrix size=%s class=%s\n', mat2str(size(matrix)), class(matrix));

% replace/add channel
pix = obj.findChannelID(name);
if ~isempty(pix)
    fprintf('[combineChannels] output channel "%s" exists -> remove\n', string(name));
    obj.removeChannel(name);
end

obj.addChannel(matrix, name, [1 1 1], outIntensity);
% ensure display limits are refreshed for new channel
try
    obj.computeDisplaylim;
catch
end
obj.log(['Combined channels'], 'Processing');

fprintf('[combineChannels] ---- DONE output="%s" ----\n', string(name));

end

% ---- helper (no dependency) ----
function s = tryGetROIid(obj)
s = '?';
try
    if isprop(obj,'id') && ~isempty(obj.id)
        s = string(obj.id);
    end
catch
end
end
