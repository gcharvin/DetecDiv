objectMetrics: temporal measurements and optional generation averages

Enable in the processor parameters:
    p = objectMetrics.setparam(struct());
    p.family = 'your family name';
    p.averageByGeneration = true;
    p.generationOutputName = 'object_metrics_generation';
    [p, dataout] = objectMetrics.process(p, roiobj, struct());

The existing object_metrics temporal table is preserved. The optional second
dataseries has type="generation" and one row per track interval, independently
for every tracked cell in the selected family. The pipeline runner handles
assignment/persistence of dataout as for the temporal output. This processor
does not choose a lineage or join mother and daughter tracks into a trajectory.

Boundary convention: observed bud emergence (child_birth_v2). A mother must
be present at the daughter's first visible frame and the previous frame.
Static parentage at movie entry alone does not delimit an observed cycle.
Means use [StartFrame, EndFrameExclusive), with EndFrame=EndFrameExclusive-1.
The last interval ends just after the last observed mother frame, so that
frame is included. No death or biological lifespan is inferred from this end.

CompleteCycle is true only for intervals bounded by two eligible observed
bud emergences, without known excluded events or parentage/tracking censoring
inside the interval. First/last fragments and tracks without observed events
remain available with CompleteCycle=false. Generation is a LOCAL interval
index, starting at 1, NOT biological replicative age or genealogical depth.

Missing observations are never interpolated. DurationFrames is the interval
width; ObservedFrames counts available temporal rows; ValidFrames removes
explicit segmentation/tracking exclusions when excludeCensored=true (default).
Coverage=ValidFrames/DurationFrames; CompleteSampling flags full coverage.
CompleteCycle and CompleteSampling describe different aspects: known event
boundaries versus sample coverage. Frames omitted by a processor frame filter
are missing samples, not shortened biological intervals.

Every scalar numeric metric is averaged over its finite, uncensored samples,
with a separate ValidCount_<metric> column. Zero is a valid measurement; NaN
and Inf are omitted. A zero count produces NaN, never zero. Identity and state
IDs are not averaged. userData.generation_report stores the exact mapping of
metric columns to count columns (names may be shortened or disambiguated).

Excluded/static events are reported in generation_report.diagnostics and
HasExcludedEvents. Parentage/tracking exclusions can invalidate an interval
even when the censored frame is missing from the temporal table. Changing
excludeCensored does not create temporal evidence for a static-only relation.

GT and prediction are processed by selecting their respective model families;
their tracks are never mixed or matched implicitly. Fluorescence remains tied
to the mask provider recorded by the input metrics and family.

The pure helper can also operate directly on an in-memory model and table:
    [generations, report] = cellMetrics.averageByGeneration(model, temporalTable);

Synthetic verification:
    runtests('engine/model/tests/testCellMetricsGenerations.m')
