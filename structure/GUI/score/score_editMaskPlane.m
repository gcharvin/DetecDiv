function out = score_editMaskPlane(action, mask, geometry, label, radius, overwrite)
%SCORE_EDITMASKPLANE Shared label-edit primitives for Score and its viewer.
% Pure pixel operation: callers own transactions, model/review sync and save.
if nargin < 5, radius = 7; end
if nargin < 6, overwrite = true; end
validateattributes(mask,{'numeric'},{'2d','real','finite','nonnegative','integer'});
validateattributes(label,{'numeric'},{'scalar','integer','>=',0,'<=',65535});
assert(~isinteger(mask) || label <= double(intmax(class(mask))), ...
    'score:MaskLabelRange','Label exceeds the mask storage type.');
out = mask;
switch action
    case 'paint'
        validateattributes(radius,{'numeric'},{'scalar','integer','>=',1,'<=',256});
        validateattributes(geometry,{'numeric'},{'2d','ncols',2,'finite'});
        for point = round(geometry).'
            x = point(1); y = point(2);
            cols = max(1,x-radius):min(size(mask,2),x+radius);
            rows = max(1,y-radius):min(size(mask,1),y+radius);
            [xx,yy] = meshgrid(cols-x,rows-y); disk = xx.^2+yy.^2 <= radius^2;
            patch = out(rows,cols);
            if ~overwrite && label > 0, disk = disk & (patch == 0 | patch == label); end
            patch(disk) = cast(label,'like',mask); out(rows,cols) = patch;
        end
    case {'draw','replace'}
        assert(islogical(geometry) && isequal(size(geometry),size(mask)), ...
            'score:MaskGeometry','Contour coverage must match the mask dimensions.');
        assert(label > 0,'score:MaskLabel','Choose a positive object label.');
        if strcmp(action,'replace'), out(out == label) = 0; end
        if ~overwrite, geometry = geometry & (mask == 0 | mask == label); end
        out(geometry) = cast(label,'like',mask);
    case 'delete'
        assert(label > 0,'score:MaskLabel','Select an object first.');
        out(out == label) = 0;
    case 'fill'
        assert(label > 0,'score:MaskLabel','Select an object first.');
        coverage = imfill(mask == label,'holes');
        if ~overwrite, coverage = coverage & (mask == 0 | mask == label); end
        out(coverage) = cast(label,'like',mask);
    otherwise
        error('score:MaskAction','Unknown mask edit action.');
end
end
