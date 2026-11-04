# Shared Hub connection in the unified viewer

Design recorded on 4 November 2026 following the request to make Hub connection independent of Pipeline execution. This document specifies a future integration; a Hub widget/controller has not yet been implemented in this worktree.

## Existing implementation to reuse

| Concern | Existing source | Observed behavior |
| --- | --- | --- |
| Common connection form | [detecdiv_hub_connection_dialog](../helpers/detecdiv_hub_connection_dialog.m) | Edits URL/fallbacks, user, password/token, timeout and path roots; calls login/current-user helpers; persists a successful connection. Password is not added to the settings structure |
| Canonical saved preferences | [settings_get](../helpers/detecdiv_hub_settings_get.m), [settings_set](../helpers/detecdiv_hub_settings_set.m) | Existing `prefdir/detecdiv_hub_settings.mat`; getter merges defaults and environment overrides. Reuse this store, not a second viewer-specific settings file |
| Authentication and identity | [login](../helpers/detecdiv_hub_login.m), [get_current_user](../helpers/detecdiv_hub_get_current_user.m) | Existing password-backed login and current identity request |
| Disconnect | [logout](../helpers/detecdiv_hub_logout.m) | Clears local token and environment token first, notifies the UI, then attempts bounded server revocation and reports its outcome |
| Shared background transport | [broker](../helpers/detecdiv_hub_broker.m), [broker_worker](../helpers/detecdiv_hub_broker_worker.m) | One broker worker, request/run-status/lease tasks, DataQueue callbacks and per-subscription cleanup. Unregistering a monitor does not cancel its server job |
| Server requests and endpoint selection | `detecdiv_hub_request`, `detecdiv_hub_request_json`, existing status/list helpers | Preserve fallback handling and current HTTP/API contracts |
| Classic DetecDiv UI | `connectToHub`, `disconnectFromHub`, `refreshHubConnectionStatus` in `detecdiv_extracted.m` | Common dialog and global settings already used; status presentation is local to the app |
| Advanced Pipeline UI | `connectHubButtonPushed`, `hubSettingsFromUi`, `ensureHubSessionFromUi`, `resumeHubRunStatusMonitorAfterReconnect` in `pipeline2_extracted.m` | Local Hub fields, connection checks/persistence and explicit monitor restart after reconnection |
| Score movie export | `configureMovieExecutionControls`, `MovieHubConnectionButtonPushed`, `submitScoreMovieToHub` in Score runtime | Another client of connection/execution selection; migrate to the same viewer session service |

The shared helpers already centralize substantial behavior. The missing layer is a common live session owner and UI state notification; sharing a preferences file alone does not keep an already-open Pipeline form/monitor synchronized with a later connection or logout.

## Planned Hub widget

Add a native dockable **Hub** document, available through **View > Hub** without requiring a project, pipeline or run. Instantiate it on demand, with backward-compatible layout migration. Do not open an empty Hub panel at startup merely to advertise the feature.

Its compact view contains:

- Selected server/profile endpoint and current user identity.
- Text connection state: Not connected, Checking, Connected, Unavailable or Session expired, based on actual outcomes rather than token presence alone.
- Connect…, Disconnect and Refresh actions. Connect opens the existing shared connection dialog; one common advanced connection editor contains fallbacks, timeouts and path mappings.
- An optional compact execution-target summary through existing helpers. Detailed queue/job views can be added separately; they are not required to establish a connection.

The main window may show a concise shared connection indicator that opens this widget. All labels remain English; help stays in tooltips/status. A connection, session identity and worker availability are separate states. Being authenticated does not mean a worker is idle, a project is writable or a run can be submitted.

## Common session controller

Introduce one UI-independent session controller per MATLAB process, backed by the existing settings and transport helpers. All viewer windows and widgets in that process obtain this service instead of making independent credentials/state copies. Preferences remain reusable across MATLAB sessions; do not imply live cross-process event delivery from a MAT preferences file.

The controller owns:

1. The current effective connection settings, authenticated identity and last check/error, with the existing environment/default precedence respected.
2. A single Connect/Disconnect/Refresh lifecycle and settings-change notification. Reuse the existing common connection dialog and helpers; adapt their implementation centrally if asynchronous login is later required.
3. Background identity/status checks through the existing broker. No new polling timer or direct startup HTTP loop per widget.
4. Subscription ownership and connection-generation checks. Ignore late results for a former user/server or a closed client. Reconnecting replaces the applicable monitor subscriptions without resubmitting/cancelling jobs.
5. Connection configuration propagation to Pipeline, Export and project clients. Consumers subscribe/unsubscribe; they do not become the connection owner.

Merely starting DetecDiv paints the viewer and reads local preferences first. A saved token is an unverified session until checked. Any optional verification happens after the UI is visible and through the broker; no blocking network request is added to construction, workspace discovery or image loading. A failed check does not prevent local analysis.

The existing connection dialog currently performs explicit login/check requests synchronously. Reusing it initially does not make those operations asynchronous. Its explicit Connect action must show progress and retain bounded timeouts; moving those requests off the UI thread should be done once in the common helper, not reimplemented by each widget.

## Connection settings versus job settings

| Shared connection/session | Pipeline / export / project execution scope |
| --- | --- |
| Endpoint, fallback URLs, user/session, timeout, reusable path-mapping preferences | Local/WSL/Hub target choice, worker capability/selection, run ID, resources, priority and execution policy |
| Connect, reconnect, verify identity, disconnect | Preflight, submit, monitor, cancel, resume and inspect an explicit job |
| Shared last identity/status/error | Run-specific job ID/report/log and project lease/ACL state |

Choosing Hub as an execution target does not connect or submit automatically. Pipeline shows the shared connection summary and an **Open Hub…** action if configuration is needed; it does not embed another password/token/URL form in the new viewer path. Export uses the same pattern. Worker/resource settings remain in their run/export configuration.

The advanced pipeline2 viewer bridge must use the common session state while retaining its existing run-specific options. Standalone classic Pipeline/DetecDiv/Score remain usable through the existing helpers. Migrate the bridged path first; do not break unrelated legacy entry points or discard saved run history.

At execution, resolve the current authorized session through the service. An old RunDraft/advanced form must not silently restore a logged-out token or overwrite a newly selected user's connection. Portable pipeline/layout/project snapshots and ordinary diagnostic events must not carry password/session-token values. This is a serialization boundary to verify during implementation, not a claim that all legacy run snapshots have already been audited or changed.

## Lifetimes, projects and progress

- Hiding/closing Hub removes its view subscription, not the process session, other widgets' monitors or server jobs. Only an explicit Disconnect changes shared authentication state.
- Disconnect invalidates local authorization immediately through the existing logout helper. Report an unconfirmed remote revocation separately. Do not represent logout as cancelling queued/running jobs.
- Existing run monitors retain their job identity and last known status while disconnected. A lost monitor connection is not a failed scientific job; reconnect can rebind monitoring through the established Pipeline path.
- Project access/ACLs, local↔remote path resolution and edit leases remain with the existing project helpers/broker tasks. Closing Hub must not release unrelated project leases or shut down the global broker.
- Connection/status work has scoped progress in Hub or a visible main-window owner. Preserve operation-specific run/export progress and cancellation; avoid an unrelated permanent busy spinner.

## Integration sequence and checks

1. Add the session controller and subscriber contract using existing helpers, with injectable/local test responses. Verify default/env precedence, a single shared state, stale-response rejection and subscriber cleanup without contacting the real Hub.
2. Add the compact Hub widget and main connection indicator. Verify it works with no project/pipeline, hidden-widget progress, lazy construction and old-layout migration. Startup must remain usable with an unreachable server.
3. Route the viewer's Pipeline settings/advanced bridge to the shared controller. Check that Connect/Disconnect/reconnect is reflected everywhere and that run identity/options survive. Retain standalone legacy behavior.
4. Route movie export and project-related Hub entry points to the same service as those capabilities are ported. Reuse the existing broker and project-lock/auth helpers; do not introduce parallel networking implementations.
5. Verify against an explicitly chosen real Hub session: identity, status and logout first; submission/cancellation only for a deliberate test job. No remote job or credential change is performed by this design review.

This is a cross-cutting integration dependency for future Hub-backed Pipeline/Export work. It can be implemented independently of contour, Data and annotation ports, and does not require a Hub/worker deployment or a new authentication protocol.
