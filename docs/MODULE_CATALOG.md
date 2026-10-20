# Common module catalog

The module catalog provides one metadata inventory for adapters delivered with
DetecDiv and adapters installed in external plugin roots. Module discovery reads
files; it does not change the MATLAB path, call adapter entrypoints, initialize
Python, load weights or modify a pipeline. Existing execution functions and
repository locations remain unchanged.

## Module identity and descriptor

A `module.json` beside the MATLAB adapter declares static metadata using
[`detecdiv-module-v1.schema.json`](schemas/detecdiv-module-v1.schema.json).
Identifiers and MATLAB package names are case-sensitive and independent of
installation paths.

| Module | Stable ID | MATLAB package | Adapter repository |
| --- | --- | --- | --- |
| CellposeSAM | `detecdiv.cellposesam` | `cellposesam` | DetecDiv |
| CellLatentModel | `detecdiv.cellLatentModel` | `cellLatentModel` | DetecDiv |
| HOCT | `detecdiv.hoctModel` | `hoctModel` | hoct_model |

The bundled descriptors live in `engine/classification/+cellposesam/` and
`engine/classification/+cellLatentModel/`. HOCT's descriptor lives in its own
repository at `plugins/classifier/+hoctModel/module.json`. Its existing
`plugin.json` remains in place for existing consumers.

The descriptor fields have the following meanings:

| Field | Meaning |
| --- | --- |
| `format` | `detecdiv.module.v1` |
| `id`, `name`, `type`, `package` | Stable module identity, display name, technical family and canonical MATLAB package |
| `adapterVersion` | Independently released adapter version, or `null` when versioned with its repository |
| `summary`, `capabilities` | Description and searchable possible abilities |
| `entrypoints.execute` | Existing execution function, declared as text |
| `entrypoints.parameters` | Optional existing parameter metadata function, declared as text |
| `compatibility.detecdiv` | Declared compatibility constraint; `null` means unspecified |
| `compatibility.pipelineContract` | `legacy` while existing execution contracts are retained |
| `provenance.repository`, `provenance.maintainer` | Adapter source repository and optional maintainer |

The two bundled adapters have `adapterVersion: null`: a backend or trained-model
version must not be substituted for an adapter release. HOCT declares `0.2.4`,
matching its existing plugin manifest. No backend or weight version is inferred
from these values.

Capabilities describe available modes, not unconditional pipeline outputs.
For example, CellposeSAM may expose segmentation, probabilities and instance-ID
propagation, while the effective node configuration determines which outputs
are produced. Metadata does not assert scientific validation, runtime readiness
or input/output compatibility. Those remain separate concerns.

Distribution and resolved installation paths are determined by the catalog,
not stored in the descriptor. Moving an installation or using a plugin root
does not change the module's ID. A plugin mechanism and inclusion in a DetecDiv
distribution describe different properties.

## Discovery API

```matlab
[modules, diagnostics] = detecdiv_modules_list();

% Explicit roots, without changing stored plugin preferences:
[modules, diagnostics] = detecdiv_modules_list( ...
    'Root', detecdivRoot, ...
    'PluginRoots', {externalPluginRoot});

% Inspect a selected adapter outside the registered roots:
[modules, diagnostics] = detecdiv_modules_list( ...
    'Root', detecdivRoot, ...
    'PluginRoots', {}, ...
    'PackagePaths', {absoluteHoctPackagePath});
```

`Root` is the DetecDiv checkout. `PluginRoots` accepts external repository roots
containing `plugins/classifier/` or `plugins/processor/`, such as the HOCT
repository root, rather than its `plugins` subdirectory. `PackagePaths`
accepts explicitly selected absolute `+package` directories. Omit `PluginRoots`
to read registered roots and include the conventional sibling `DetecDiv-plugins`
root when it exists. Pass an empty cell array for a reproducible inventory
without those external roots. Discovery does not register roots
or make the discovered packages executable. Reading default roots does not
initialize or save plugin preferences.

Each `modules` entry includes identity (`id`, `name`, `type`, `pkg`), installation
(`path`, `root`, `distribution`), declared entrypoints, `adapterVersion`,
`capabilities`, `compatibility`, `provenance` and the original `manifest` with
its `manifestPath`. An unknown adapter version is represented as an empty
character vector in the MATLAB result. `distribution` is `bundled` or
`external`.

`descriptorStatus` is `declared`, `legacy` or `invalid`; `status` is `ok`,
`invalid` or `conflict`, with details in `issues`. `resolvedEntrypoint` and
`onPath` report current MATLAB resolution without adding any path. Diagnostics
are records with `severity`, `code`, `message`, `path` and `moduleId`, allowing
both batch reports and future GUIs to present the same findings.

Packages without a new descriptor remain visible through historical discovery
rules. Existing `plugin.json` files are accepted as legacy metadata. These
entries receive a synthesized `legacy.<type>.<pkg>` locator; this locator is not
a declared stable module identity and must not be treated as one when persisting
future pipeline references. Legacy entries do not claim the descriptor contract.
An invalid `module.json` generates a diagnostic rather than silently being
treated as a valid descriptor.

The catalog reports malformed metadata, missing declared files and conflicting
identities/packages. It retains conflicting installations for inspection;
neither scan order nor the MATLAB path silently chooses an installation.
Repeated discovery of the same physical package is deduplicated. A readable
descriptor means that metadata was discovered, not that Python, model weights
or the adapter's dependencies are installed.

## Audit

`pipelineModuleAudit` consumes the same catalog. Its default mode inspects
metadata and files without calling package functions:

```matlab
[report, diagnostics] = pipelineModuleAudit('Root', detecdivRoot, ...
    'PluginRoots', {externalPluginRoot});
```

Existing contract introspection is available explicitly for trusted packages
already resolved on the MATLAB path:

```matlab
[report, diagnostics] = pipelineModuleAudit('Root', detecdivRoot, ...
    'PluginRoots', {externalPluginRoot}, ...
    'InspectContracts', true);
```

This opt-in may call existing MATLAB metadata functions. It does not install
dependencies or run classification. Metadata discovery and contract inspection
remain distinct operations so an audit can list external or unavailable
modules without initializing their runtimes.

The audit returns a table. It retains the original first ten columns and adds
catalog identity, origin, versions, discovery status, paths and diagnostics.
`ContractStatus` and `SetparamStatus` are `NOT_INSPECTED` by default. Opt-in
inspection skips invalid, conflicting, shadowed or unavailable packages rather
than inspecting metadata from a different installation.

## Migration boundary

This first catalog revision adds identity, discovery and audit only. The
existing `classify` signatures, `executionSpec`, pipeline node serialization,
GUI menus, plugin registration and runtime policies remain in place. The
`legacy` flag intentionally preserves the current execution-contract status
until module-owned semantic contracts are introduced separately.

The catalog does not alter model release pointers, classifier sources or
runtime bundles. In particular, the latent model retains its separate
[`MODEL_RUNTIME_CONTRACT_V1.md`](MODEL_RUNTIME_CONTRACT_V1.md); adding a module
descriptor does not authorize runtime export or copying model/data trees.
