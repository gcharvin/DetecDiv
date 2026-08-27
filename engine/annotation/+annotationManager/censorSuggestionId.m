function id = censorSuggestionId(roiObj, issue)
%ANNOTATIONMANAGER.CENSORSUGGESTIONID Stable identity for one advisory item.

roiId = '';
try, roiId = char(string(roiObj.id)); catch, end
payload = struct( ...
    'roi_id', roiId, ...
    'code', fieldText(issue, 'code'), ...
    'family_id', fieldNumber(issue, 'family_id'), ...
    'track_id', fieldNumber(issue, 'focus_track_id'), ...
    'frame_start', fieldNumber(issue, 'suggested_frame_start'), ...
    'frame_end', fieldNumber(issue, 'suggested_frame_end'), ...
    'scope_flags', fieldNumber(issue, 'suggested_scope_flags'), ...
    'reason', fieldText(issue, 'suggested_reason'));
bytes = unicode2native(jsonencode(payload), 'UTF-8');
digest = java.security.MessageDigest.getInstance('SHA-256');
digest.update(bytes);
id = lower(reshape(dec2hex(typecast(digest.digest(), 'uint8'), 2).', 1, []));
end

function value = fieldText(value, name)
if isfield(value, name), value = char(string(value.(name)));
else, value = '';
end
end

function value = fieldNumber(value, name)
if isfield(value, name), value = double(value.(name));
else, value = 0;
end
end
