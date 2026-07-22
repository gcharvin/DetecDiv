#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { createRequire } from 'node:module';
import { pathToFileURL } from 'node:url';

function argsOf(argv) {
  const out = {};
  for (let i = 2; i < argv.length; i += 1) {
    const key = argv[i];
    if (!key.startsWith('--')) continue;
    const next = argv[i + 1];
    out[key.slice(2)] = next && !next.startsWith('--') ? argv[++i] : true;
  }
  return out;
}

function die(message) { console.error(message); process.exit(1); }
function esc(value) {
  return String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
}
function label(value) {
  return String(value ?? '').replace(/[_-]+/g, ' ').replace(/([a-z])([A-Z])/g, '$1 $2')
    .replace(/\b\w/g, c => c.toUpperCase()).replace(/\bDetecdiv\b/g, 'DetecDiv');
}
function compact(value, depth = 0) {
  if (value == null || value === '') return '';
  if (Array.isArray(value)) return value.length ? `[${value.length} elements]` : 'auto / all';
  if (typeof value === 'object') {
    if (depth > 0) return '{...}';
    const keys = Object.keys(value);
    return keys.length ? `{${keys.slice(0, 4).join(', ')}${keys.length > 4 ? ', ...' : ''}}` : '{}';
  }
  const s = String(value);
  return s.length > 52 ? `${s.slice(0, 49)}...` : s;
}

const catalogue = {
  dataloader: {
    title: 'Load microscopy data',
    goal: 'Discover the acquisition and build an inventory of positions, frames, Z planes, and channels.',
    principle: 'The loader parses the raw sources, applies the requested filters, and exposes images grouped by field of view.',
    inputs: ['source path or linked project sources'], outputs: ['images', 'fovList', 'channels', 'shallow']
  },
  roipattern: {
    title: 'Detect repeated regions',
    goal: 'Locate the repeated traps or structures that must be analysed.',
    principle: 'A reference image patch is matched against the selected source channel. Accepted matches become ROI rectangles.',
    inputs: ['images', 'reference channel', 'pattern patch'], outputs: ['roiList']
  },
  roigrid: {
    title: 'Create ROIs from a grid',
    goal: 'Partition the source field into a reproducible set of analysis regions.',
    principle: 'A regular grid or full-frame tiling rule converts the selected image area into explicit ROI rectangles.',
    inputs: ['full-frame image', 'grid geometry'], outputs: ['roiList']
  },
  roimanual: {
    title: 'Define ROIs manually',
    goal: 'Let the operator identify the exact regions that should be analysed.',
    principle: 'Rectangles drawn on the source full frame are stored as explicit ROI definitions for extraction and downstream processing.',
    inputs: ['full-frame image', 'manual rectangles'], outputs: ['roiList']
  },
  roiidentify: {
    title: 'Define regions of interest',
    goal: 'Convert the source full frame into an explicit set of analysis regions.',
    principle: 'The configured ROI strategy creates rectangles on the source image and publishes them as a reusable ROI list.',
    inputs: ['full-frame image', 'ROI strategy'], outputs: ['roiList']
  },
  roiextract: {
    title: 'Extract ROI time series',
    goal: 'Materialise one analysis-ready image series for every detected ROI.',
    principle: 'Each ROI rectangle is cropped from the source data, optionally drift-corrected, and written to its local H5 image store.',
    inputs: ['roiList', 'source images', 'selected channels'], outputs: ['roiList', 'ROI channels', 'ROI .h5 files']
  },
  bestfocusplane: {
    title: 'Select the best focus plane',
    goal: 'Reduce each Z stack to a sharp image that can be segmented reliably.',
    principle: 'A focus score is evaluated along Z. The best plane, optionally smoothed or projected, becomes a derived image channel.',
    inputs: ['roiList', 'Z-stack channels'], outputs: ['DIC_focus', 'best-Z index series']
  },
  cellposesam: {
    title: 'Segment cells with CellposeSAM',
    goal: 'Identify individual cells in every ROI and frame.',
    principle: 'The configured CellposeSAM model infers cell boundaries from the focused image and writes an instance-labelled mask.',
    inputs: ['roiList', 'focused image channel', 'trained model'], outputs: ['instance mask', 'probability map']
  },
  detectviterbipombedivisionframe: {
    title: 'Track the target cell and detect division',
    goal: 'Follow one biologically relevant cell and identify its division frame.',
    principle: 'Viterbi optimisation selects a temporally coherent path through segmented instances. Shape and septum profiles produce a division score.',
    inputs: ['instance masks', 'focused image'], outputs: ['target-cell mask', 'division profile', 'division score']
  },
  detecdivpomegranate: {
    title: 'Quantify the Pomegranate phenotype',
    goal: 'Measure cell geometry and three-dimensional signals at the biologically relevant frame.',
    principle: 'The division score selects the analysis frame. The Z stack is quantified inside the tracked cell mask, then tables and quality-control images are exported.',
    inputs: ['Z stack', 'target-cell mask', 'division score', 'best-Z index'], outputs: ['cell measurements', 'Excel / CSV', 'QC images and mosaic']
  }
};

function nodeKey(node) {
  const pkg = node.params?.pkg || node.pkg || '';
  const func = node.func || '';
  return String(pkg || func.split('.')[0] || node.type || '').toLowerCase();
}
function nodeSignature(node) {
  return [nodeKey(node), node.type, node.name, node.id, node.func, node.params?.pkg]
    .filter(Boolean).join(' ').toLowerCase();
}
function genericDoc(node) {
  const type = String(node.type || 'module').toLowerCase();
  const base = catalogue[type] || {};
  return {
    title: base.title || label(node.name || node.id),
    goal: base.goal || `Execute the ${label(node.name || node.id)} stage of the pipeline.`,
    principle: base.principle || `The ${node.func || node.type || 'custom'} module transforms the incoming execution context and publishes explicit downstream results.`,
    inputs: base.inputs || ['upstream context / roiList'],
    outputs: base.outputs || (type === 'classifier' ? ['roiList', 'dataSeries / masks'] : ['roiList', 'dataSeries'])
  };
}
function docFor(node, metadata) {
  const builtIn = catalogue[nodeKey(node)] || genericDoc(node);
  const override = metadata?.nodes?.[node.id] || {};
  return {...builtIn, ...override};
}
function interestingParams(node) {
  const ignore = new Set(['pattern','candidateRects','previewRects','tip','trainingParam','classes','moduleVar','modulePath']);
  const preferred = ['channel','channels','extractChannels','outputName','outputChannelName','zBestOutputName','threshold','correctDrift','driftMethod','diameter','min_size','cell_prob_threshold','instanceChannelName','outputMaskChannelName','scoreSeriesName','frameSelectionMode','resultsWorkbookName'];
  const params = node.params || {};
  const keys = [...preferred.filter(k => k in params), ...Object.keys(params).filter(k => !preferred.includes(k))]
    .filter(k => !ignore.has(k) && compact(params[k]) !== '').slice(0, 4);
  return keys.map(k => `<li><span>${esc(label(k))}</span><strong>${esc(compact(params[k]))}</strong></li>`).join('');
}
function portsFor(node, edges, side, fallback) {
  const values = edges.filter(e => side === 'in' ? e.to === node.id : e.from === node.id)
    .map(e => side === 'in' ? e.toPort : e.fromPort).filter(Boolean);
  return [...new Set([...values, ...(fallback || [])])];
}
function pipelineDiagram(nodes, edges) {
  const ordered = nodes.filter(n => n.enabled !== false);
  const W = 1460, y = 185, nodeW = 174, nodeH = 130;
  const gap = ordered.length > 1 ? (W - ordered.length * nodeW) / (ordered.length - 1) : 0;
  const xAt = i => 22 + i * (nodeW + gap);
  const idToIndex = new Map(ordered.map((n, i) => [n.id, i]));
  const defs = `<defs><marker id="arrowhead" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 Z" fill="#315f73"/></marker></defs>`;
  const links = edges.filter(e => idToIndex.has(e.from) && idToIndex.has(e.to)).map(e => {
    const a = idToIndex.get(e.from), b = idToIndex.get(e.to);
    const x1 = xAt(a) + nodeW, x2 = xAt(b), cy = y + nodeH / 2;
    return `<path class="graph-edge" d="M ${x1} ${cy} L ${x2 - 8} ${cy}"/>`;
  }).join('');
  const boxes = ordered.map((node, i) => {
    const d = catalogue[nodeKey(node)] || genericDoc(node);
    const name = d.title || label(node.params?.pkg || node.type);
    const words = name.split(' '); const lines = [];
    while (words.length) { let line = words.shift(); while (words.length && `${line} ${words[0]}`.length <= 21) line += ` ${words.shift()}`; lines.push(line); }
    const tx = xAt(i) + nodeW / 2;
    return `<g><rect class="graph-node graph-${esc(String(node.type || 'module').toLowerCase())}" x="${xAt(i)}" y="${y}" width="${nodeW}" height="${nodeH}" rx="12"/><circle class="graph-index" cx="${xAt(i)+24}" cy="${y+24}" r="15"/><text class="graph-index-text" x="${xAt(i)+24}" y="${y+30}">${i+1}</text><text class="graph-type" x="${tx}" y="${y+30}">${esc(label(node.type))}</text>${lines.slice(0,3).map((line,j)=>`<text class="graph-name" x="${tx}" y="${y+67+j*22}">${esc(line)}</text>`).join('')}</g>`;
  }).join('');
  const contracts = edges.filter(e => idToIndex.has(e.from) && idToIndex.has(e.to)).map(e => `<span><b>${idToIndex.get(e.from)+1} -> ${idToIndex.get(e.to)+1}</b> ${esc(e.fromPort || 'output')}</span>`).join('');
  return `<svg class="pipeline-graph" viewBox="0 0 1504 440" role="img" aria-label="Pipeline graph derived from JSON edges">${defs}${links}${boxes}</svg><div class="edge-contracts">${contracts}</div><div class="graph-legend"><span><i class="loader-dot"></i> Data preparation</span><span><i class="processor-dot"></i> Processing</span><span><i class="classifier-dot"></i> Classification</span></div>`;
}
function pills(items) { return items.map(x => `<span class="pill">${esc(x)}</span>`).join(''); }

function readExamples(manifestPath) {
  if (!manifestPath) return {};
  const manifest = JSON.parse(fs.readFileSync(path.resolve(manifestPath), 'utf8'));
  const root = path.dirname(path.resolve(manifestPath));
  const result = {};
  for (const [role, entries] of Object.entries(manifest.roles || {})) {
    const list = Array.isArray(entries) ? entries : [entries];
    result[role] = list.filter(Boolean).map(item => {
      const file = path.resolve(root, item.file);
      const ext = path.extname(file).toLowerCase();
      const mime = ext === '.jpg' || ext === '.jpeg' ? 'image/jpeg' : 'image/png';
      return {...item, src:`data:${mime};base64,${fs.readFileSync(file).toString('base64')}`};
    });
  }
  return result;
}
function exampleRole(node) {
  const key = nodeKey(node);
  const type = String(node.type || '').toLowerCase();
  const signature = nodeSignature(node);
  if (type === 'dataloader' || /(^|\s)data\s*loader($|\s)/.test(signature)) return 'raw';
  if (['roipattern','roigrid','roimanual','roiidentify'].includes(key) ||
      (/roi/.test(signature) && /(pattern|grid|manual|identify|detect|define)/.test(signature))) return 'roi_definition';
  if (key === 'roiextract' || (/roi/.test(signature) && /(extract|crop)/.test(signature))) return 'roi_extraction';
  if (key === 'bestfocusplane' || /(best.?focus|focus.?plane|z.?focus)/.test(signature)) return 'best_focus';
  if (key === 'cellposesam' || /(cellpose|instance.?segment|segment.*cell)/.test(signature)) return 'segmentation';
  if (key === 'detectviterbipombedivisionframe' || /(viterbi|target.?cell|cell.?track|division.?frame)/.test(signature)) return 'division';
  if (key === 'detecdivpomegranate' || /(quantif|measure|export|pomegranate)/.test(signature)) return 'final';
  return key;
}
function visualBlock(node, examples) {
  const items = examples[exampleRole(node)] || [];
  if (!items.length) return '';
  return `<div class="example-grid example-count-${Math.min(items.length,2)}">${items.slice(0,2).map(item => {
    const kindLabel = item.kind === 'input-output' ? 'INPUT -> OUTPUT' : item.kind;
    const showBadge = item.kind && item.kind !== 'input-output';
    return `<figure><div class="visual-frame">${showBadge ? `<span class="visual-kind visual-${esc(item.kind)}">${esc(kindLabel)}</span>` : ''}<img src="${item.src}" alt="${esc(item.alt || item.caption || 'Project example')}"></div><figcaption>${esc(item.caption || 'Example from the associated project')}</figcaption></figure>`;
  }).join('')}</div>`;
}

function makeHtml(spec, metadata, examples, revealCss, revealJs, sourceName) {
  const nodes = (spec.nodes || []).filter(n => n.enabled !== false);
  const edges = spec.edges || [];
  const slides = [];
  slides.push(`<section class="title-slide"><div class="eyebrow">Pipeline documentation</div><h1>${esc(metadata.title || label(spec.name || 'DetecDiv pipeline'))}</h1><p>${esc(metadata.description || 'A reproducible microscopy workflow, documented from declared inputs to reviewable outputs.')}</p><div class="title-meta">Version ${esc(spec.version || 'not specified')} <span>&bull;</span> ${nodes.length} active stages</div><footer>Pipeline definition: ${esc(sourceName)}</footer></section>`);
  slides.push(`<section><div class="eyebrow">Pipeline overview</div><h2>The declared graph connects ${nodes.length} explicit processing stages</h2>${pipelineDiagram(nodes, edges)}<div class="takeaway">The diagram is generated directly from the pipeline nodes, edges, and port names.</div></section>`);
  nodes.forEach((node, index) => {
    const d = docFor(node, metadata);
    const inPorts = portsFor(node, edges, 'in', d.inputs || []);
    const outPorts = portsFor(node, edges, 'out', d.outputs || []);
    const visual = visualBlock(node, examples);
    const defaultTakeaway = index === nodes.length - 1 ? 'The final stage publishes quantitative results together with visual quality-control evidence.' : `Stage ${index + 1} produces explicit, reviewable outputs for the next operation.`;
    slides.push(`<section data-node-id="${esc(node.id)}"><div class="step-index">${String(index + 1).padStart(2,'0')} / ${String(nodes.length).padStart(2,'0')}</div><div class="eyebrow">${esc(label(node.type))}</div><h2>${esc(metadata.nodes?.[node.id]?.title || d.title || label(node.params?.pkg || node.func?.split('.')[0] || node.name))}</h2><div class="module-layout ${visual ? 'has-example' : 'no-example'}"><div class="story"><h3>Goal</h3><p>${esc(d.goal)}</p><h3>Principle</h3><p>${esc(d.principle)}</p><div class="io-pair"><div><h3>Inputs</h3>${pills(inPorts)}</div><div><h3>Outputs</h3>${pills(outPorts)}</div></div></div><div class="evidence">${visual}<div class="params"><h3>Key parameters</h3><ul>${interestingParams(node)}</ul></div></div></div><div class="takeaway">${esc(d.takeaway || defaultTakeaway)}</div></section>`);
  });
  slides.push(`<section><div class="eyebrow">Review and extension</div><h2>The documentation remains traceable to the executable pipeline</h2><div class="review-list"><p><b>Arrow keys</b><span>Move through the processing stages</span></p><p><b>O</b><span>Open the slide overview</span></p><p><b>Associated project</b><span>Add real intermediate outputs as embedded examples</span></p><p><b>Metadata JSON</b><span>Refine scientific explanations without changing execution</span></p></div><div class="takeaway">pipeline2 calls the same generator with the current pipeline and its optional project.</div></section>`);
  return `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${esc(spec.name)} - Pipeline documentation</title><style>${revealCss}\n${themeCss()}</style></head><body><div class="reveal"><div class="slides">${slides.join('\n')}</div></div><script>${revealJs}</script><script>if(location.search.includes('static-pdf')){document.body.classList.add('static-print');}else{Reveal.initialize({hash:true,history:true,center:false,slideNumber:'c/t',transition:'fade',backgroundTransition:'none',width:1600,height:900,margin:0,pdfSeparateFragments:false});}</script></body></html>`;
}
function themeCss() { return `
:root{--ink:#14212b;--muted:#566774;--paper:#ffffff;--accent:#d94c36;--blue:#315f73;--line:#d8e0e5;--soft:#f3f6f7}
html,body{background:#fff}.reveal{font-family:Arial,Helvetica,sans-serif;color:var(--ink);font-size:40px;background:#fff}
.reveal .slides section{box-sizing:border-box;text-align:left;padding:52px 70px 76px;background:#fff}
.reveal h1,.reveal h2,.reveal h3{font-family:Arial,Helvetica,sans-serif;text-transform:none;color:var(--ink);letter-spacing:-.02em}
.reveal h1{font-size:72px;line-height:1.05;max-width:1120px;margin:145px 0 28px}.reveal h2{font-size:44px;line-height:1.08;margin:8px 0 30px}.reveal h3{font-size:19px;line-height:1.1;text-transform:uppercase;letter-spacing:.12em;color:var(--accent);margin:0 0 10px}
.reveal p{font-size:25px;line-height:1.36}.eyebrow{font-size:17px;text-transform:uppercase;letter-spacing:.2em;font-weight:800;color:var(--blue)}
.title-slide p{max-width:1000px;font-size:30px;color:var(--muted)}.title-meta{margin-top:82px;font-size:21px;font-weight:700}.title-meta span{padding:0 12px;color:var(--accent)}.title-slide footer{position:absolute;bottom:42px;font-size:16px;color:var(--muted)}
.step-index{position:absolute;right:70px;top:52px;font-size:18px;font-weight:800;color:var(--muted)}
.module-layout{display:grid;grid-template-columns:minmax(0,44fr) minmax(0,56fr);gap:30px;height:650px}.story{border-left:6px solid var(--accent);padding:12px 28px}.story p{font-size:23px;margin:0 0 25px}.io-pair{display:grid;grid-template-columns:1fr 1fr;gap:22px;margin-top:24px}.evidence{min-width:0}.params{margin-top:16px}.params ul{list-style:none;margin:0;padding:0;font-size:18px}.params li{display:flex;justify-content:space-between;gap:16px;border-bottom:1px solid var(--line);padding:6px 0}.params li span{color:var(--muted);flex:0 0 36%}.params li strong{text-align:right;min-width:0;flex:1;overflow-wrap:anywhere}.pill{display:inline-block;font-size:16px;font-weight:700;background:var(--soft);border:1px solid #c8d5dc;border-radius:5px;padding:7px 10px;margin:0 5px 6px 0}
.example-grid{display:grid;gap:12px;height:420px}.example-count-1{grid-template-columns:1fr}.example-count-2{grid-template-columns:1fr 1fr}.example-grid figure{margin:0;display:flex;flex-direction:column;min-width:0}.visual-frame{position:relative}.example-grid img{display:block;width:100%;height:372px;object-fit:contain;background:#0c0f11;border:1px solid #cbd5da}.example-count-2 img{height:350px}.visual-kind{position:absolute;z-index:2;top:10px;left:10px;padding:6px 10px;border-radius:4px;background:#fff;color:var(--ink);font-size:14px;font-weight:800;text-transform:uppercase;letter-spacing:.08em;box-shadow:0 1px 4px rgba(0,0,0,.2)}.visual-input{border-left:5px solid var(--blue)}.visual-output{border-left:5px solid var(--accent)}.visual-input-output{border-left:5px solid var(--blue);border-right:5px solid var(--accent)}.example-grid figcaption{font-size:16px;line-height:1.25;color:var(--muted);padding-top:7px}
.takeaway{position:absolute;left:70px;right:70px;bottom:34px;border-top:2px solid var(--ink);padding-top:13px;font-size:20px;font-weight:800}
.pipeline-graph{display:block;width:100%;height:410px;margin:30px 0 0}.graph-edge{stroke:var(--blue);stroke-width:3;fill:none;marker-end:url(#arrowhead)}.graph-node{fill:#f7f9fa;stroke:#9fb2bc;stroke-width:2}.graph-dataloader,.graph-roipattern,.graph-roiextract{fill:#eef5f7}.graph-classifier{fill:#fff0ed;stroke:#d8998e}.graph-processor{fill:#f5f3fb;stroke:#aaa1cb}.graph-index{fill:var(--ink)}.graph-index-text{font-family:Arial,sans-serif;font-size:17px;font-weight:700;fill:#fff;text-anchor:middle}.graph-type{font-family:Arial,sans-serif;font-size:12px;font-weight:700;letter-spacing:1px;fill:var(--muted);text-anchor:middle;text-transform:uppercase}.graph-name{font-family:Arial,sans-serif;font-size:17px;font-weight:700;fill:var(--ink);text-anchor:middle}.edge-contracts{display:flex;justify-content:center;gap:10px;margin-top:-42px}.edge-contracts span{font-size:14px;color:var(--blue);border:1px solid #c7d4da;background:#f6f9fa;padding:5px 8px;border-radius:4px}.edge-contracts b{color:var(--ink);margin-right:4px}.graph-legend{display:flex;gap:28px;justify-content:center;font-size:16px;color:var(--muted);margin-top:22px}.graph-legend i{display:inline-block;width:12px;height:12px;margin-right:7px;border-radius:2px}.loader-dot{background:#dcecf0}.processor-dot{background:#e8e4f5}.classifier-dot{background:#f8d9d2}
.review-list{margin:70px 80px 0}.review-list p{display:flex;align-items:baseline;margin:0;padding:20px 0;border-bottom:1px solid var(--line);font-size:25px}.review-list b{color:var(--accent);display:inline-block;flex:0 0 260px;width:260px;margin-right:30px}
body.static-print,body.static-print .reveal,body.static-print .reveal .slides{width:1600px!important;height:auto!important;min-height:0!important;margin:0!important;padding:0!important;overflow:visible!important;position:static!important;transform:none!important}
body.static-print .reveal .slides section{box-sizing:border-box!important;display:block!important;visibility:visible!important;opacity:1!important;position:relative!important;left:auto!important;top:auto!important;width:1600px!important;height:900px!important;min-height:900px!important;margin:0!important;overflow:hidden!important;transform:none!important;page-break-after:always!important;break-after:page!important}
body.static-print .step-index{position:absolute!important;right:70px!important;top:52px!important;left:auto!important}
body.static-print .module-layout{display:grid!important;grid-template-columns:minmax(0,44fr) minmax(0,56fr)!important;gap:30px!important;height:650px!important}
body.static-print .io-pair{display:grid!important;grid-template-columns:1fr 1fr!important;gap:22px!important}
body.static-print .example-grid{display:grid!important;height:420px!important}
body.static-print .example-count-1{grid-template-columns:1fr!important}
body.static-print .example-count-2{grid-template-columns:1fr 1fr!important}
body.static-print .visual-frame{position:relative!important}
body.static-print .visual-kind{position:absolute!important;top:10px!important;left:10px!important}
body.static-print .takeaway{position:absolute!important;left:70px!important;right:70px!important;bottom:34px!important}
body.static-print .reveal .slides section:last-child{page-break-after:auto!important;break-after:auto!important}
@media print{
 @page{size:1600px 900px;margin:0}
 html,body,.reveal,.reveal .slides{width:1600px!important;height:auto!important;min-height:0!important;margin:0!important;padding:0!important;overflow:visible!important;position:static!important;transform:none!important}
 .reveal .slides section{background:#fff!important}
 .reveal .controls,.reveal .progress,.reveal .slide-number{display:none!important}
}
`; }

const args = argsOf(process.argv);
if (!args.input) die('Usage: node generate-pipeline-doc.mjs --input pipeline.json [--output-dir dir] [--reveal-dir dir] [--metadata file.json] [--examples manifest.json] [--pdf]');
const input = path.resolve(args.input);
const outputDir = path.resolve(args['output-dir'] || path.join(path.dirname(input), 'pipeline_documentation'));
const revealDir = path.resolve(args['reveal-dir'] || process.env.REVEAL_JS_DIR || '');
if (!fs.existsSync(input)) die(`Pipeline not found: ${input}`);
if (!revealDir || !fs.existsSync(path.join(revealDir, 'dist', 'reveal.js'))) die('Reveal.js was not found. Use --reveal-dir or REVEAL_JS_DIR.');
const spec = JSON.parse(fs.readFileSync(input, 'utf8').replace(/^\uFEFF/, ''));
const metadata = args.metadata ? JSON.parse(fs.readFileSync(path.resolve(args.metadata), 'utf8')) : {};
const examples = readExamples(args.examples);
const revealCss = fs.readFileSync(path.join(revealDir, 'dist', 'reveal.css'), 'utf8');
const revealJs = fs.readFileSync(path.join(revealDir, 'dist', 'reveal.js'), 'utf8');
fs.mkdirSync(outputDir, {recursive:true});
const base = String(spec.name || 'pipeline').replace(/[^a-zA-Z0-9_-]+/g, '_');
const htmlPath = path.join(outputDir, `${base}_documentation.html`);
fs.writeFileSync(htmlPath, makeHtml(spec, metadata, examples, revealCss, revealJs, path.basename(input)), 'utf8');
const result = {html:htmlPath, pdf:null, nodes:(spec.nodes || []).filter(n => n.enabled !== false).length};
if (args.pdf) {
  const chrome = args.chrome || ['C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe','C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe','C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe'].find(fs.existsSync);
  if (!chrome) die('Chrome/Edge was not found for PDF export. Use --chrome.');
  const pdfPath = path.join(outputDir, `${base}_documentation.pdf`);
  const fileUrl = `${pathToFileURL(htmlPath).href}?static-pdf`;
  let rendered = false;
  try {
    const require = createRequire(import.meta.url);
    const { chromium } = require('playwright');
    const browser = await chromium.launch({headless:true, executablePath:chrome});
    const page = await browser.newPage({viewport:{width:1600,height:900}});
    await page.goto(fileUrl, {waitUntil:'load'});
    await page.waitForFunction(() => document.body.classList.contains('static-print') || globalThis.Reveal?.isReady?.(), null, {timeout:30000});
    await page.pdf({path:pdfPath, width:'1600px', height:'900px', landscape:true, printBackground:true, preferCSSPageSize:true, displayHeaderFooter:false});
    await browser.close();
    rendered = fs.existsSync(pdfPath) && fs.statSync(pdfPath).size > 5000;
  } catch (error) {
    // The Chrome CLI fallback is intentionally silent: stdout is a JSON API
    // consumed by MATLAB's jsondecode.
  }
  if (!rendered) {
    const run = spawnSync(chrome, ['--headless','--disable-gpu','--no-pdf-header-footer','--virtual-time-budget=5000',`--print-to-pdf=${pdfPath}`,fileUrl], {encoding:'utf8',timeout:120000});
    rendered = run.status === 0 && fs.existsSync(pdfPath) && fs.statSync(pdfPath).size > 5000;
    if (!rendered) die(`PDF export failed: ${run.stderr || run.stdout}`);
  }
  result.pdf = pdfPath;
}
console.log(JSON.stringify(result, null, 2));
