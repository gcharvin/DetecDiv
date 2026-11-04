function value = trackId(input,allowZero)
%TRACKID Parse a uint64 identity without a lossy intermediate double.
if nargin < 2, allowZero = false; end
if isnumeric(input)
    if isa(input,'uint64'), value = input;
    else
        validateattributes(input,{'numeric'},{'scalar','real','finite','integer','nonnegative','<=',flintmax});
        value = uint64(input);
    end
else
    text = strtrim(char(string(input)));
    assert(~isempty(regexp(text,'^[0-9]+$','once')),'detecdivui:TrackId','Enter a decimal integer track ID.');
    value = uint64(0);
    for digit = text
        n = uint64(double(digit)-double('0'));
        assert(value <= idivide(intmax('uint64')-n,uint64(10),'floor'), ...
            'detecdivui:TrackId','Track ID exceeds uint64 storage.');
        value = value*uint64(10)+n;
    end
end
assert(isscalar(value) && (allowZero || value > 0),'detecdivui:TrackId','Choose a positive track ID.');
end
