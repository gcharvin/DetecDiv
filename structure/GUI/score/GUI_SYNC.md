# Score App Designer workflow

`score.mlapp` in this directory is the runtime application. Do not edit it
directly in App Designer.

Use the isolated design source under `private/layout` instead:

```matlab
score_gui_layout("edit")
```

After saving and closing App Designer, build the runtime application with:

```matlab
score_gui_layout("apply")
```

The apply step merges only the App Designer component layout into the
private code-rich reference and writes the runtime `score.mlapp`. Backups are
created before every effective change.
