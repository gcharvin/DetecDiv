# ROI drift registration

ROI extraction defaults come from `roiExtract.driftDefaults`: method `robust`,
reference policy `adaptive`, new-motion limits `maxShift=20` and `maxStep=20`
pixels, and relative keyframe refresh interval 20 frames. These limits constrain
new motion, not the total displacement over a movie. An explicit saved limit or
reference policy is retained.

Robust registration uses distributed image patches, spatial consensus, and
intensity/structural agreement. Adaptive mode first tries the immutable initial
reference. If that reference no longer matches, it tries a trusted recent raw
keyframe and adds that keyframe's absolute pose. This is still robust patch
consensus, not a switch to the legacy global `subpixel` algorithm.

An accepted strong initial-anchor match can refresh the keyframe immediately.
Relative-only matches refresh at the configured interval to reduce chaining
bias. Rejected images never become references. The initial anchor remains
available for reacquisition. Adaptive registration cannot guarantee alignment
when no stable image content remains; inspect rejection history and absolute
centering, especially under clogging. Small consecutive-frame residuals alone
do not validate the absolute trajectory.

`drift.referenceFrames` identifies the actual reference used for each estimate;
`anchorValidated` distinguishes initial-anchor matches from relative fallback.
Fallback estimates retain the `temporalFallback:keyframe` diagnostic prefix.
The keyframe frame/pose and preprocessing signature are persisted, while raw and
processed reference pixels live in transient FOV state. Cold resume reloads the
trusted frame from the raw source and fails explicitly if it cannot be read.
Refresh timing and reference state are independent of extraction block sizes.

Explicit robust `fixed` retains the historical immutable-anchor/temporal-bridge
policy. The old robust `previous` setting historically meant `fixed` and keeps
that interpretation for compatibility. Other methods support their existing
`fixed` and `previous` policies. Historical pinned Hub jobs keep their code SHA
and parameters; new defaults do not rewrite saved scientific settings.
