function report = pipelineRunReviewSmokeTest()
% pipelineRunReviewSmokeTest  Minimal regression test for run review JSONL.

    report = struct('ok', false, 'reviewPath', '', 'message', '');
    runDir = tempname;
    mkdir(runDir);
    eventFile = fullfile(runDir, 'run_events.jsonl');

    fid = fopen(eventFile, 'w');
    if fid < 0
        error('pipelineRunReviewSmokeTest:IO', 'Cannot write %s.', eventFile);
    end
    cleaner = onCleanup(@()fclose(fid)); %#ok<NASGU>
    writeEvent(fid, struct('ts','2026-06-05 09:00:00.000', ...
        'type','run_start', 'runId','review_smoke'));
    writeEvent(fid, struct('ts','2026-06-05 09:00:01.000', ...
        'type','node_start', 'runId','review_smoke', ...
        'NodeId','processor_1', 'NodeType','processor', ...
        'Status','running', 'Message','start'));
    writeEvent(fid, struct('ts','2026-06-05 09:00:03.000', ...
        'type','node_done', 'runId','review_smoke', ...
        'NodeId','processor_1', 'NodeType','processor', ...
        'Status','done', 'Message','ok'));
    writeEvent(fid, struct('ts','2026-06-05 09:00:04.000', ...
        'type','run_done', 'runId','review_smoke'));
    clear cleaner;

    [review, text] = pipelineRunReview(runDir, 'Write', true);
    assert(review.eventCount == 4, 'Unexpected event count.');
    assert(numel(review.nodes) == 1, 'Unexpected node count.');
    assert(strcmp(review.nodes(1).nodeId, 'processor_1'), 'Unexpected node id.');
    assert(strcmp(review.nodes(1).status, 'done'), 'Unexpected node status.');
    assert(contains(text, 'Pipeline run review'), 'Review text header missing.');
    assert(isfile(fullfile(runDir, 'run_review.txt')), 'Review file was not written.');

    report.ok = true;
    report.reviewPath = fullfile(runDir, 'run_review.txt');
    report.message = 'pipelineRunReview smoke test passed';
end

function writeEvent(fid, event)
    fprintf(fid, '%s\n', jsonencode(event));
end
