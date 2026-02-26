function [catCell, catStr] = classiNormalizeCategory(categoryIn)
% classiNormalizeCategory Normalize classifier category legacy formats.
% Returns:
%   catCell : 1x1 cell containing category text
%   catStr  : category text as char

    catStr = '';

    if nargin == 0 || isempty(categoryIn)
        catCell = {''};
        return;
    end

    if iscell(categoryIn)
        if isempty(categoryIn)
            catStr = '';
        else
            v = categoryIn{1};
            if isstring(v)
                catStr = char(v);
            elseif ischar(v)
                catStr = v;
            else
                try
                    catStr = char(string(v));
                catch
                    catStr = '';
                end
            end
        end
    elseif isstring(categoryIn)
        if isempty(categoryIn)
            catStr = '';
        else
            catStr = char(categoryIn(1));
        end
    elseif ischar(categoryIn)
        catStr = categoryIn;
    else
        try
            catStr = char(string(categoryIn));
        catch
            catStr = '';
        end
    end

    catCell = {catStr};
end
