/* Browser-side checks for the offline Mermaid audit runner. No host CSS is assumed. */
window.inspectMermaid = ({css, config, classDefs={}, assignments=[]}) => {
  const svg = document.querySelector('#diagram svg');
  const styles = [...svg.querySelectorAll('style')];
  const text = styles.map(s => s.textContent).join('\n');
  const compact = s => s.replace(/\s/g, '');
  const compiled = styles.flatMap(s => [...(s.sheet?.cssRules ?? [])]).filter(r => r.selectorText);
  const sheet = new CSSStyleSheet();
  sheet.replaceSync(css || '');
  const cssChecks = [];
  for (const rule of sheet.cssRules) {
    if (!rule.selectorText) { cssChecks.push({status:'NOT SUPPORTED', rule:rule.cssText}); continue; }
    const selectors = rule.selectorText.split(',').map(s => s.trim());
    const scoped = selectors.map(s => '#' + CSS.escape(svg.id) + ' ' + s);
    const matches = compiled.filter(r => r.selectorText.split(',').some(s => scoped.some(t => compact(s)===compact(t))));
    const nodes = [...new Set(matches.flatMap(r => {
      try { return [...document.querySelectorAll(r.selectorText)]; } catch { return []; }
    }))];
    const retained = selectors.every(s => compact(text).includes(compact(s)));
    const mismatch = [];
    for (const node of nodes) {
      const ref = document.createElementNS('http://www.w3.org/2000/svg', 'rect');
      for (const prop of rule.style) ref.style.setProperty(prop, rule.style.getPropertyValue(prop), 'important');
      svg.appendChild(ref);
      const expected = getComputedStyle(ref), actual = getComputedStyle(node);
      for (const prop of rule.style) {
        if (actual.getPropertyValue(prop) !== expected.getPropertyValue(prop))
          mismatch.push({property:prop, actual:actual.getPropertyValue(prop), expected:expected.getPropertyValue(prop)});
      }
      ref.remove();
    }
    const optional = rule.selectorText.includes('layout_') && !svg.querySelector('path[data-id^="layout_"]');
    cssChecks.push({selector:rule.selectorText, retained, matches:nodes.length,
      status: !retained ? 'FAIL' : !nodes.length ? (optional?'NOT TESTED':'FAIL') : mismatch.length?'FAIL':'PASS',
      mismatches:mismatch.slice(0,6)});
  }
  const classChecks = [];
  for (const [role, declarations] of Object.entries(classDefs)) {
    const nodes = [...svg.querySelectorAll('.node.'+role)];
    const groups = [...svg.querySelectorAll('.cluster.'+role)];
    const ids = assignments.filter(pair=>pair[1]===role).flatMap(pair=>pair[0].split(','));
    const edges = ids.flatMap(id=>[...svg.querySelectorAll('path[data-id="'+id+'"]')]);
    const mismatches = [];
    let count = 0;
    for (const [property, raw] of Object.entries(declarations)) {
      const value = raw.trim();
      const ref = document.createElementNS('http://www.w3.org/2000/svg','rect');
      ref.style.setProperty(property,value,'important'); svg.appendChild(ref);
      const expected = getComputedStyle(ref).getPropertyValue(property);
      let targets = [...edges];
      if (property==='color') {
        targets = nodes.flatMap(n=>[...n.querySelectorAll('.nodeLabel,text')]);
      } else {
        targets.push(...groups.flatMap(g=>[...g.querySelectorAll('rect')]));
        targets.push(...nodes.flatMap(n=>[...n.querySelectorAll('.label-container')]));
        if (property.startsWith('stroke')) targets.push(...nodes.flatMap(n=>[...n.querySelectorAll('.outer-path path[fill="none"]')]));
      }
      for (const target of targets) {
        const prop = property==='color' && target.namespaceURI.includes('svg') ? 'fill' : property;
        const actual = getComputedStyle(target).getPropertyValue(prop);
        count++;
        if (actual!==expected) mismatches.push({property,actual,expected});
      }
      ref.remove();
    }
    classChecks.push({class:role,matches:count,status:!count?'NOT TESTED':mismatches.length?'FAIL':'PASS',mismatches:mismatches.slice(0,6)});
  }
  const rgba = value => {
    const m = value.match(/^rgba?\(([^)]+)\)$/);
    if (!m) return null;
    const v=m[1].split(/[,\s/]+/).filter(Boolean).map(Number); return [...v.slice(0,3),v[3]??1];
  };
  const lum = c => c.slice(0,3).map(v=>v/255).map(v=>v<=0.04045?v/12.92:((v+0.055)/1.055)**2.4)
    .reduce((s,v,i)=>s+v*[0.2126,0.7152,0.0722][i],0);
  const ratio = (a,b) => (Math.max(lum(a),lum(b))+.05)/(Math.min(lum(a),lum(b))+.05);
  const visible = e => getComputedStyle(e).visibility!=='hidden' && Number(getComputedStyle(e).opacity)!==0;
  const shapes = [...svg.querySelectorAll('rect,polygon,path,circle,ellipse')].filter(e=>{
    const f=getComputedStyle(e).fill,r=e.getBoundingClientRect();
    return visible(e) && f!=='none' && f!=='rgba(0, 0, 0, 0)' && r.width>1 && r.height>1;
  });
  const rootBg = getComputedStyle(svg).backgroundColor;
  const contrast = [];
  const labels=[...svg.querySelectorAll('text, text tspan, foreignObject p, foreignObject span.nodeLabel')]
    .filter(e=>visible(e) && e.textContent.trim() && !e.querySelector('p,tspan'));
  for (const e of labels) {
    const rect=e.getBoundingClientRect(); if (!rect.width || !rect.height) continue;
    const x=rect.x+rect.width/2,y=rect.y+rect.height/2;
    const parent=e.closest('g.node');
    const own=parent?.querySelector('.label-container');
    const behind=own || shapes.filter(s=>{
      const r=s.getBoundingClientRect();return x>=r.left&&x<=r.right&&y>=r.top&&y<=r.bottom;
    }).sort((a,b)=>{const x=a.getBoundingClientRect(),y=b.getBoundingClientRect();return x.width*x.height-y.width*y.height;})[0];
    const fg=rgba(getComputedStyle(e)[e.namespaceURI.includes('svg')?'fill':'color']);
    let local=e; let surface=null;
    while(local && local!==svg) { const c=rgba(getComputedStyle(local).backgroundColor); if(c && c[3]===1) {surface=c;break;} local=local.parentElement; }
    let bg=surface || (behind?rgba(getComputedStyle(behind).fill):rgba(rootBg));
    const host=rgba(getComputedStyle(document.body).backgroundColor);
    if (!bg || bg[3]===0) bg=host;
    const valid=fg&&bg&&fg[3]===1&&bg[3]===1;
    contrast.push({text:e.textContent.trim().slice(0,90),foreground:fg,background:bg,
      ratio:valid?Number(ratio(fg,bg).toFixed(2)):null,status:valid?(ratio(fg,bg)>=4.5?'PASS':'FAIL'):'NOT SUPPORTED'});
  }
  return {cssChecks,classChecks,contrast,rootBackground:rootBg,viewBox:svg.getAttribute('viewBox'),
    shapes:shapes.length, labels:labels.length,
    activeConfig:{layout:window.mermaid.mermaidAPI.getConfig().layout,theme:window.mermaid.mermaidAPI.getConfig().theme},
    geometry:[...svg.querySelectorAll('g.node')].map(e=>({id:e.id,transform:e.getAttribute('transform')})),
    erSelectors:Object.fromEntries(['.er.entityBox','.er.attributeBoxEven','.node .label-container',
      '.er.relationshipLine','.relationshipLine','.messageText','rect.actor','text.actor'].map(s=>[s,svg.querySelectorAll(s).length]))};
};
