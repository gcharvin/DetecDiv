function staticParameterDialogTest()
%STATICPARAMETERDIALOGTEST Typed staged edits, exact classes and stale rejection.
params = struct('threshold',.5,'enabled',true,'method',{{'sum','max','sum'}}, ...
    'levels',single([1 2;3 4]),'empty',zeros(0,2,'single'),'name',"original", ...
    'count',int16(2),'largeId',intmax('uint64'),'structured',struct('path','Z:\not-mounted'));
node = struct('id','module','params',params);
state = containers.Map('KeyType','char','ValueType','any');
state('calls') = 0; state('reject') = false;
dialog = detecdivui.StaticParameterDialog(node,fieldnames(params),@storeApply);
cleanup = onCleanup(@()deleteIfValid(dialog));
assert(isa(dialog.Controls.method,'matlab.ui.control.DropDown'));
assert(isa(dialog.Controls.enabled,'matlab.ui.control.CheckBox'));
assert(isa(dialog.Controls.levels,'matlab.ui.control.Table'));
assert(strcmp(dialog.Controls.structured.Editable,'off') && strcmp(dialog.Controls.largeId.Editable,'off'));
dialog.Controls.threshold.Value = .8; dialog.Controls.enabled.Value = false;
dialog.Controls.method.Value = 'max'; dialog.Controls.levels.Data = [10 20;30 40];
dialog.Controls.empty.Value = '[4,5]'; dialog.Controls.name.Value = 'staged'; dialog.Controls.count.Value = 3;
staged = dialog.requestCurrent();
assert(isequaln(node.params,params) && state('calls')==0);
assert(staged.threshold==.8 && ~staged.enabled && strcmp(staged.method{end},'max'));
assert(isequal(staged.method(1:end-1),params.method(1:end-1)));
assert(isa(staged.levels,'single') && isa(staged.empty,'single') && isa(staged.count,'int16'));
assert(isstring(staged.name) && strcmp(staged.name,'staged'));
assert(isequal(staged.largeId,params.largeId) && isequaln(staged.structured,params.structured));

dialog.Controls.count.Value = 2.5;
assert(~dialog.apply() && isvalid(dialog) && state('calls')==0);
dialog.Controls.count.Value = 3; state('reject') = true;
assert(~dialog.apply() && isvalid(dialog) && state('calls')==0);
status = findall(dialog.Figure,'Tag','pipeline-static-status'); assert(contains(status.Text,'Stale'));
state('reject') = false;
assert(dialog.apply() && state('calls')==1);
assert(strcmp(state('id'),'module') && isequaln(state('params'),staged) && isequaln(node.params,params));

cancelled = detecdivui.StaticParameterDialog(node,{'threshold'},@storeApply);
cancelled.Controls.threshold.Value = .9; cancelled.Figure.CloseRequestFcn(cancelled.Figure,[]);
assert(~isvalid(cancelled) && state('calls')==1 && isequaln(node.params,params));
disp('Static parameter dialog test passed: native typed controls, staged values, choice representation, exact classes, structured values, invalid/stale rejection, Apply and Cancel.');

    function storeApply(id,values)
        assert(~state('reject'),'detecdivui:StaleStatic','Stale pipeline context');
        state('calls') = state('calls')+1; state('id') = id; state('params') = values;
    end
end

function deleteIfValid(object)
if ~isempty(object) && isvalid(object), delete(object); end
end
