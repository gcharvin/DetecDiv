# classifierGUI App Designer workflow

`structure/GUI/classifierGUI.mlapp` is the runtime application. Do not edit it
directly in App Designer: saving it can restore stale App Designer code and
discard programmatic fixes.

Open the isolated design source with:

```matlab
classifier_gui_layout("edit")
```

The design source owns component properties and `createComponents`. The
code-rich reference under `private/classifierGUI_runtime_code.m` owns callbacks
and helpers. After saving and closing App Designer, rebuild the runtime with:

```matlab
classifier_gui_layout("apply")
```

The apply step validates every wired callback, creates backups, merges the
layout, and verifies the code embedded in the runtime `.mlapp`.
