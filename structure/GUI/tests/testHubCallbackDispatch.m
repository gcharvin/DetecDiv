function tests = testHubCallbackDispatch
tests = functiontests(localfunctions);
end

function testPublicMethodReceivesPayloadAndContext(tc)
owner = HubCallbackReceiver();
cleanup = onCleanup(@()delete(owner)); %#ok<NASGU>
callback = struct('owner',owner,'method','receive','args',{{'job-123'}});
payload = struct('ok',true);
verifyTrue(tc,detecdiv_hub_invoke_callback(callback,payload));
verifyEqual(tc,owner.Payload,payload);
verifyEqual(tc,owner.Context,'job-123');
end

function testDeletedWindowStopsQuietly(tc)
owner = HubCallbackReceiver();
callback = struct('owner',owner,'method','receive','args',{{'job-123'}});
delete(owner);
verifyFalse(tc,detecdiv_hub_invoke_callback(callback,struct()));
end

function testLegacyFunctionStillWorks(tc)
seen = [];
verifyTrue(tc,detecdiv_hub_invoke_callback(@receive,17));
verifyEqual(tc,seen,17);
    function receive(payload)
        seen = payload;
    end
end

function testBrokenCallbackUnsubscribesOnce(tc)
cleanup = onCleanup(@()detecdiv_hub_broker('shutdown')); %#ok<NASGU>
% Unsupported task kind exercises the queue without issuing a Hub request.
token = detecdiv_hub_broker('register','test_no_network', ...
    struct('periodSeconds',3600),@broken);
verifyWarning(tc,@()detecdiv_hub_broker('dispatch',struct('token',token)), ...
    'detecdiv_hub:brokerCallback');
state = detecdiv_hub_broker('status');
verifyEqual(tc,state.subscriptionCount,0);
% Already queued payloads must not call the broken receiver again.
verifyWarningFree(tc,@()detecdiv_hub_broker('dispatch',struct('token',token)));
    function broken(~)
        error('test:StaleCallback','Missing App Designer callback');
    end
end
