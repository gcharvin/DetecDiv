# Pipeline documentation generator

`pipelineDocumentationGenerate` turns a pipeline JSON (or a `pipeline` object)
into a standalone Reveal.js presentation and, optionally, a PDF. Reveal's CSS
and JavaScript are embedded in the HTML, so the generated file can be reviewed
without a web server or a copy of the original pipeline assets.

## MATLAB usage

```matlab
result = pipelineDocumentationGenerate("C:\path\to\pipeline.json", ...
    "Project", "C:\path\to\project.mat", ...
    "ExportPdf", true, ...
    "OpenBrowser", true);
```

When `Project` is supplied, the generator samples representative data and
embeds lightweight visual evidence for each module. The project, its raw image
files, and its H5 files are only read; they are never modified or copied into
the documentation.

The example extractor follows a reusable input/output contract rather than a
pipeline-specific list of screenshots:

- dataloaders show a raw, full-frame image;
- manual, pattern, and grid ROI modules show the source full frame and the same
  frame with every generated ROI overlaid;
- ROI extraction shows the selected ROI in its full-frame context and a short
  time series at one fixed Z plane;
- best-focus modules show a compact input Z stack and the selected best-focus
  output;
- instance-segmentation modules show an input containing several cells and the
  corresponding multi-instance overlay;
- tracking or Viterbi modules show the candidate cells and the selected cell;
- downstream analysis modules show their most relevant input/output or QC
  artifacts when these are available.

Module matching is based on generic module families and pipeline parameters.
The extraction layer also uses pipeline-declared dataset names when possible,
so the same policy can be reused by other pipelines without hard-coded project
paths.

The result contains `html`, `pdf`, and `nodes`. `RevealDir` can be supplied
explicitly; otherwise the helper checks `REVEAL_JS_DIR` and the known local
seminar installation.

## Editorial overrides

Technical information comes from `nodes`, `edges`, node parameters, and a small
built-in module catalogue. Human-facing explanations can be refined without
changing the executable pipeline:

```json
{
  "title": "Pomegranate analysis pipeline",
  "description": "From microscopy stacks to cell-shape measurements",
  "nodes": {
    "classifier_cellposesam_5": {
      "title": "Cell segmentation",
      "goal": "Identify each cell in every frame.",
      "principle": "A trained CellposeSAM model predicts instance masks.",
      "takeaway": "The output is an instance-labelled mask, not a binary image."
    }
  }
}
```

Pass this file with the `Metadata` option. This is the intended extension point
for module-owned documentation descriptors in a later version.

## pipeline2 integration

The **File** menu provides two actions:

- **Generate pipeline documentation PDF...** builds the documentation for the
  current pipeline and, when available, the project associated with the current
  run;
- **Open pipeline documentation PDF** is enabled only when the expected PDF is
  available and opens it in the system PDF viewer.

Documentation is stored in a `documentation` directory beside the current run
when a run path is available, or beside the pipeline otherwise. Generation,
wording rules, example extraction, Reveal.js packaging, and PDF export remain
outside App Designer so they can also be called headlessly.

The generator source is `tools/pipeline-doc/generate-pipeline-doc.mjs`. It can
also be invoked directly with `node ... --input ... --reveal-dir ... --pdf`.
