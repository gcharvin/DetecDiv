/* Classic menus for our AppContainer window. No MATLAB installation files change. */
(() => {
    if (window.detecdivMenu) return;
    const workspace = document.getElementById('uiroot');
    if (!workspace) throw new Error('AppContainer root is unavailable.');
    const style = document.createElement('style');
    style.textContent = `
      #detecdiv-menubar{position:absolute;top:0;left:0;right:0;height:28px;z-index:10000;
        display:flex;align-items:stretch;background:#f4f4f4;border-bottom:1px solid #bcbcbc;
        color:#222;font:13px "Segoe UI",sans-serif;user-select:none}
      #detecdiv-menubar button{font:inherit;color:inherit;border:0;background:transparent;
        cursor:default;text-align:left;white-space:nowrap}
      #detecdiv-menubar>.dd-root{position:relative;display:flex}
      #detecdiv-menubar>.dd-root>button{padding:3px 10px}
      #detecdiv-menubar button:hover,#detecdiv-menubar button:focus-visible{background:#dceaf5;outline:1px solid #8eafc5}
      #detecdiv-menubar button:disabled{color:#999;outline:0;background:transparent}
      #detecdiv-menubar [role=menu]{display:none;position:absolute;top:28px;left:0;
        padding:3px;min-width:205px;background:#fafafa;border:1px solid #aaa;
        box-shadow:2px 3px 8px #0003;z-index:10001}
      #detecdiv-menubar .dd-root.dd-open>[role=menu]{display:block}
      #detecdiv-menubar .dd-entry{position:relative}
      #detecdiv-menubar .dd-entry>button{width:100%;display:flex;align-items:center;gap:8px;padding:5px 8px}
      #detecdiv-menubar .dd-entry>[role=menu]{top:0;left:100%}
      #detecdiv-menubar .dd-entry:hover>[role=menu],#detecdiv-menubar .dd-entry:focus-within>[role=menu]{display:block}
      #detecdiv-menubar .dd-check{width:14px;flex-shrink:0}
      #detecdiv-menubar .dd-label{flex:1}
      #detecdiv-menubar .dd-shortcut{margin-left:22px;color:#666;font-size:12px}
      #detecdiv-menubar .dd-separator{border-top:1px solid #ccc;margin:3px 0}
    `;
    document.head.appendChild(style);
    const bar = document.createElement('nav');
    bar.id = 'detecdiv-menubar'; bar.setAttribute('role','menubar');
    bar.setAttribute('aria-label','Application menu');
    document.body.appendChild(bar);
    workspace.style.top = '28px'; workspace.style.height = 'calc(100% - 28px)';
    let menus = [], queue = [];
    const close = () => {
        bar.querySelectorAll('.dd-open').forEach(root => {
            root.classList.remove('dd-open'); root.firstChild.setAttribute('aria-expanded','false');
        });
    };
    const all = () => {
        const out = [];
        const walk = items => items.forEach(item => { out.push(item); walk(item.children || []); });
        walk(menus); return out;
    };
    const invoke = item => {
        if (!item.enabled || item.children.length) return;
        queue.push(item.id); close();
    };
    const makeMenu = items => {
        const menu = document.createElement('div'); menu.setAttribute('role','menu');
        for (const item of items) {
            if (item.separator) {
                const line = document.createElement('div');
                line.className = 'dd-separator'; line.setAttribute('role','separator'); menu.appendChild(line);
            }
            const entry = document.createElement('div'); entry.className = 'dd-entry';
            const button = document.createElement('button');
            button.setAttribute('role','menuitem'); button.dataset.command = item.id;
            button.disabled = !item.enabled;
            const check = document.createElement('span'); check.className = 'dd-check';
            check.textContent = item.checked ? '✓' : '';
            const label = document.createElement('span'); label.className = 'dd-label'; label.textContent = item.text;
            const shortcut = document.createElement('span'); shortcut.className = 'dd-shortcut';
            shortcut.textContent = item.children.length ? '›' : (item.shortcut || (item.accelerator ? 'Ctrl+'+item.accelerator.toUpperCase() : ''));
            button.append(check,label,shortcut); entry.appendChild(button);
            if (item.children.length) {
                button.setAttribute('aria-haspopup','menu'); entry.appendChild(makeMenu(item.children));
            } else button.addEventListener('click',() => invoke(item));
            menu.appendChild(entry);
        }
        return menu;
    };
    const openRoot = root => {
        close(); root.classList.add('dd-open'); root.firstChild.setAttribute('aria-expanded','true');
    };
    const setMenus = data => {
        menus = data; bar.replaceChildren();
        for (const item of menus) {
            const root = document.createElement('div'); root.className = 'dd-root';
            const button = document.createElement('button'); button.textContent = item.text;
            button.setAttribute('role','menuitem'); button.setAttribute('aria-haspopup','menu');
            button.setAttribute('aria-expanded','false');
            button.addEventListener('click',() => {
                const wasOpen = root.classList.contains('dd-open'); close(); if (!wasOpen) openRoot(root);
            });
            root.addEventListener('mouseenter',() => { if (bar.querySelector('.dd-open')) openRoot(root); });
            root.append(button,makeMenu(item.children)); bar.appendChild(root);
        }
    };
    document.addEventListener('pointerdown',event => { if (!bar.contains(event.target)) close(); },true);
    document.addEventListener('keydown',event => {
        if (event.key === 'Escape') { close(); return; }
        if ((event.ctrlKey || event.metaKey) && !event.altKey) {
            const typing = event.target.matches('input,textarea,[contenteditable=true]');
            if (typing && event.key.toLowerCase() === 'c') return;
            const item = all().find(item => item.enabled && item.accelerator &&
                item.accelerator.toLowerCase() === event.key.toLowerCase());
            if (item) { event.preventDefault(); invoke(item); }
        }
        const roots = [...bar.children];
        if (event.altKey && !event.ctrlKey) {
            const root = roots.find(root => root.firstChild.textContent[0].toLowerCase() === event.key.toLowerCase());
            if (root) { event.preventDefault(); openRoot(root); root.firstChild.focus(); }
        }
        if (!bar.contains(document.activeElement)) return;
        if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
            event.preventDefault();
            const root = document.activeElement.closest('.dd-root'); openRoot(root);
            const menu = document.activeElement.closest('[role=menu]') || root.lastChild;
            const buttons = [...menu.children].filter(node => node.classList.contains('dd-entry'))
                .map(node => node.firstChild).filter(button => !button.disabled);
            const current = buttons.indexOf(document.activeElement);
            const delta = event.key === 'ArrowDown' ? 1 : -1;
            const index = current < 0 ? (delta > 0 ? 0 : buttons.length-1) : (current+delta+buttons.length)%buttons.length;
            buttons[index]?.focus();
        } else if (event.key === 'ArrowRight' || event.key === 'ArrowLeft') {
            event.preventDefault();
            const entry = document.activeElement.closest('.dd-entry');
            if (event.key === 'ArrowRight' && entry?.lastChild.getAttribute('role') === 'menu') {
                entry.lastChild.querySelector('button:not(:disabled)')?.focus();
            } else {
                const root = document.activeElement.closest('.dd-root');
                const index = (roots.indexOf(root)+(event.key === 'ArrowRight' ? 1 : -1)+roots.length)%roots.length;
                openRoot(roots[index]); roots[index].firstChild.focus();
            }
        }
    },true);
    window.detecdivMenu = {setMenus,drain:() => { const events = queue; queue = []; return events; }};
    window.dispatchEvent(new Event('resize'));
})();
