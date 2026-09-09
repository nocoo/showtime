(() => {
  'use strict';
  const $ = (selector, root = document) => root.querySelector(selector);
  const $$ = (selector, root = document) => [...root.querySelectorAll(selector)];
  const esc = value => String(value).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const paths = {
    grid:'<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/>',
    projects:'<rect x="3" y="4" width="18" height="16" rx="2"/><path d="M3 9h18M9 9v11"/>',
    chart:'<path d="M4 3v17h17M8 15l4-5 4 2 5-7"/>',
    inbox:'<path d="M4 4h16l2 10v6H2v-6L4 4Z"/><path d="M2 14h6l2 3h4l2-3h6"/>',
    users:'<circle cx="9" cy="8" r="3"/><path d="M3 21v-3a6 6 0 0 1 12 0v3M16 5a3 3 0 0 1 0 6M18 15a5 5 0 0 1 3 5"/>',
    settings:'<path d="m10 3-.5 3-3 1-2.5-1-2 3 2 2v3l-2 2 2 3 3-1 2 1 .5 3h4l.5-3 3-1 2.5 1 2-3-2-2v-3l2-2-2-3-3 1-2-1-.5-3Z"/><circle cx="12" cy="12" r="3"/>',
    search:'<circle cx="10.5" cy="10.5" r="6.5"/><path d="m16 16 5 5"/>',
    bell:'<path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9M9 21h6"/>',
    plus:'<path d="M12 5v14M5 12h14"/>',
    down:'<path d="m7 10 5 5 5-5"/>',
    chevrons:'<path d="m8 8 4-4 4 4m-8 8 4 4 4-4"/>',
    right:'<path d="M5 12h14m-5-5 5 5-5 5"/>',
    close:'<path d="m6 6 12 12M6 18 18 6"/>',
    check:'<path d="m5 12 4 4L19 6"/>',
    globe:'<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a16 16 0 0 1 0 18 16 16 0 0 1 0-18Z"/>',
    currency:'<rect x="3" y="5" width="18" height="14" rx="2"/><circle cx="12" cy="12" r="3"/><path d="M6 12h.01M18 12h.01"/>',
    arrowup:'<path d="M7 17 17 7M7 7h10v10"/>',
    clock:'<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
    calendar:'<rect x="3" y="5" width="18" height="16" rx="2"/><path d="M7 3v4m10-4v4M3 11h18"/>',
    filter:'<path d="M4 7h16M7 12h10M10 17h4"/>',
    list:'<path d="M9 5h12M9 12h12M9 19h12M3 5h.01M3 12h.01M3 19h.01"/>',
    board:'<rect x="3" y="4" width="4" height="16" rx="1"/><rect x="10" y="4" width="4" height="11" rx="1"/><rect x="17" y="4" width="4" height="14" rx="1"/>',
    dots:'<circle cx="5" cy="12" r="1"/><circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/>',
    box:'<path d="m12 3 9 5v9l-9 5-9-5V8l9-5ZM3 8l9 5 9-5m-9 5v9M7 5l10 6"/>',
    layers:'<path d="m12 3 10 6-10 6L2 9l10-6Zm-9 11 9 5 9-5M3 19l9 5 9-5"/>',
    spark:'<path d="m12 3 2.5 6.5L21 12l-6.5 2.5L12 21l-2.5-6.5L3 12l6.5-2.5L12 3Z"/>',
    lock:'<rect x="5" y="10" width="14" height="11" rx="2"/><path d="M8 10V6a4 4 0 0 1 8 0v4M12 14v3"/>',
    help:'<circle cx="12" cy="12" r="9"/><path d="M9.5 9a2.5 2.5 0 1 1 4 2c-1.5 1-1.5 1-1.5 3M12 17h.01"/>',
    link:'<path d="m10 13 4-4M8 16l-2 2a4 4 0 0 1-6-6l5-5a4 4 0 0 1 6 0m2 0 2-2a4 4 0 0 1 6 6l-5 5a4 4 0 0 1-6 0" transform="translate(1 0)"/>',
    mail:'<rect x="3" y="5" width="18" height="14" rx="2"/><path d="m3 6 9 7 9-7"/>',
    return:'<path d="M20 5v9H4m5-5-5 5 5 5"/>',
  };
  const icon = (name, extra = '') => `<svg class="icon ${extra}" viewBox="0 0 24 24" aria-hidden="true">${paths[name] || paths.box}</svg>`;
  const people = [['AL',''],['JK','a1'],['MR','a2'],['SK','a3'],['EW','a4']];
  const avatar = (index = 0) => `<span class="avatar ${people[index % people.length][1]}">${people[index % people.length][0]}</span>`;
  const avatars = (indexes = [0,1,2], extra = false) => `<div class="avatar-stack">${indexes.map(avatar).join('')}${extra ? '<span class="avatar a5">+2</span>' : ''}</div>`;
  const initialProjects = [
    {id:'aurora',name:'Website redesign',description:'A fresh home for our next chapter. Thoughtful details, from the first impression to the final click.',team:'Design',status:'in-progress',progress:68,due:'Sep 24',color:'',icon:'globe',people:[0,1,2],tasks:[true,true,false,false,true]},
    {id:'mobile',name:'Mobile experience',description:'Your workspace, wherever inspiration finds you.',team:'Engineering',status:'in-progress',progress:42,due:'Oct 02',color:'blue',icon:'layers',people:[3,0],tasks:[true,false,false,false,true]},
    {id:'system',name:'Design system 2.0',description:'One shared language. Infinite possibilities.',team:'Design',status:'review',progress:92,due:'Sep 18',color:'green',icon:'box',people:[1,2],tasks:[true,true,true,false,true]},
    {id:'story',name:'Tell a better story',description:'Bring our brand to life, one detail at a time.',team:'Marketing',status:'planned',progress:15,due:'Oct 08',color:'orange',icon:'spark',people:[2,4],tasks:[true,false,false,false,false]},
    {id:'onboard',name:'First impressions',description:'Make the first five minutes feel effortless.',team:'Design',status:'planned',progress:8,due:'Oct 12',color:'',icon:'users',people:[1,0],tasks:[false,false,false,false,false]},
    {id:'insights',name:'Better insights',description:'Turn the numbers into your next big idea.',team:'Engineering',status:'review',progress:86,due:'Sep 21',color:'blue',icon:'chart',people:[3,4],tasks:[true,true,true,false,true]},
    {id:'community',name:'Community launch',description:'A place to share, learn, and grow together.',team:'Marketing',status:'done',progress:100,due:'Sep 09',color:'green',icon:'users',people:[2,4],tasks:[true,true,true,true,true]},
    {id:'workflow',name:'A smoother workflow',description:'More flow. Fewer things in the way.',team:'Engineering',status:'done',progress:100,due:'Sep 05',color:'blue',icon:'spark',people:[3,0],tasks:[true,true,true,true,true]},
  ];
  const state = {page:'overview',range:'month',projects:structuredClone(initialProjects),filter:'All projects',view:'board',sortAscending:true,invites:[],readInbox:false,workspace:'Acme Studio',notifications:true,digest:false,overlay:null,selectedTeam:'Design',lastCreated:null};
  window.orbit = {state};
  window.__inputLog = [];
  ['pointerdown','click','input','keydown','wheel','pointermove'].forEach(kind => document.addEventListener(kind, event => {
    window.__inputLog.push({kind,trusted:event.isTrusted,target:event.target.id || event.target.closest('[id]')?.id || event.target.tagName,time:Math.round(performance.now()),value:kind==='input' && event.target.type!=='password' ? event.target.value : undefined});
    if(window.__inputLog.length>5000) window.__inputLog.splice(0,1000);
  },{capture:true,passive:true}));
  const projectIcon = p => `<span class="project-icon ${p.color}">${icon(p.icon)}</span>`;
  const statusName = value => ({planned:'Planned','in-progress':'In progress',review:'In review',done:'Complete'}[value]);
  const tag = (text, style='') => `<span class="tag ${style}"><i></i>${esc(text)}</span>`;
  const projectTag = p => tag(statusName(p.status), {planned:'gray','in-progress':'',review:'orange',done:'green'}[p.status]);
  function navItem(page, label, symbol, count='') {
    return `<button id="${page}-nav" class="nav-item ${state.page===page?'active':''}" data-nav="${page}">${icon(symbol)}<span>${label}</span>${count?`<span class="count">${count}</span>`:''}</button>`;
  }
  function shell() {
    const title = {overview:'Overview',projects:'Projects',analytics:'Analytics',inbox:'Inbox',team:'Team',settings:'Settings'}[state.page];
    document.title = `${title} · Orbit`;
    $('#app').innerHTML = `<div class="app-shell"><aside class="sidebar">
      <a href="#overview" class="brand" data-nav="overview" aria-label="Orbit home"><img src="/demo/favicon.svg" alt="">orbit</a>
      <button class="workspace-switch" id="workspace-switch"><span class="workspace-icon">A</span><span class="workspace-text">${esc(state.workspace)}<small>Pro workspace</small></span>${icon('chevrons')}</button>
      <div class="nav-section"><div class="nav-label">WORKSPACE</div>
        ${navItem('overview','Overview','grid')}${navItem('projects','Projects','projects')}${navItem('analytics','Analytics','chart')}${navItem('inbox','Inbox','inbox',state.readInbox?'':'4')}
      </div>
      <div class="nav-section"><div class="nav-label">YOUR PROJECTS<button id="sidebar-add-project" aria-label="Add project">+</button></div>
        ${state.projects.slice(0,3).map((p,i)=>`<button class="nav-item" data-project="${p.id}"><span class="project-dot" style="background:${['#77b65f','#9cb4ce','#adc29e'][i]}"></span>${esc(p.name)}</button>`).join('')}
        <button class="nav-item" data-nav="projects" style="color:#a6adba">${icon('dots')}All projects</button>
      </div>
      <div class="sidebar-bottom">${navItem('team','Team members','users')}${navItem('settings','Settings','settings')}
        <div class="upgrade-card"><b>A little more possibility.</b><p>Good work grows better<br>when you do it together.</p><button id="explore-plan">Explore your plan ${icon('right')}</button></div>
        <button class="sidebar-profile" id="profile-open">${avatar(0)}<span><b>Alex Lane</b><small>alex@acme.design</small></span>${icon('chevrons')}</button>
      </div>
    </aside><main class="main"><header class="topbar"><div class="breadcrumbs">${icon('grid')}<span>Workspace</span><span style="color:#c5cad1">/</span><strong>${title}</strong></div>
      <div class="topbar-spacer"></div><button class="search-trigger" id="search-open">${icon('search')}<span>Search anything…</span><kbd>⌘ K</kbd></button>
      <button class="icon-button" id="help-open" aria-label="Help and shortcuts">${icon('help')}</button>
      <button class="icon-button" id="notifications-open" aria-label="Notifications">${icon('bell')}${state.readInbox?'':'<span class="notification-dot"></span>'}</button>
      <div class="top-divider"></div><button id="top-profile" aria-label="Your profile">${avatar(0)}</button>
    </header><div class="main-scroll" id="main-scroll"><div class="content" id="page-content"></div></div></main></div>`;
    renderPage(); bindShell();
  }
  function bindShell() {
    $$('[data-nav]').forEach(el=>el.addEventListener('click',e=>{e.preventDefault();navigate(el.dataset.nav)}));
    $$('[data-project]').forEach(el=>el.addEventListener('click',()=>openDetail(el.dataset.project)));
    $('#search-open').onclick=openSearch; $('#notifications-open').onclick=()=>navigate('inbox');
    $('#sidebar-add-project').onclick=()=>openNewProject(); $('#explore-plan').onclick=openPlan;
    $('#profile-open').onclick=openProfile; $('#top-profile').onclick=openProfile; $('#help-open').onclick=openHelp;
    $('#workspace-switch').onclick=()=>navigate('settings');
  }
  function navigate(page) { state.page=page; state.overlay=null; $('#overlay-root').innerHTML=''; history.replaceState(null,'',`#${page}`); shell(); }
  function pageHeading(eyebrow,title,description,actions='') {
    return `<div class="page-heading"><div><div class="eyebrow">${eyebrow}</div><h1>${title}</h1>${description?`<p>${description}</p>`:''}</div><div class="heading-actions">${actions}</div></div>`;
  }
  const newProjectButton = `<button class="button primary" id="new-project">${icon('plus')}New project</button>`;
  const sparkline = (style,points) => `<svg class="metric-spark ${style}" viewBox="0 0 90 36"><path d="${points} L87 36H2Z" fill="currentColor" opacity=".06"/><path d="${points}" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>`;
  function metrics() {
    return `<div class="metrics">
      <div class="metric-card" id="revenue-card"><div class="metric-label">${icon('currency')}Total revenue<span>↗</span></div><div class="metric-value">$84,254<span style="font-size:17px;color:#b2b9c2;font-weight:400">.00</span></div><div class="metric-foot"><span class="change">↗ 18.4%</span>vs. last month</div>${sparkline('','M2 28 11 25 19 28 28 20 36 23 45 16 54 18 62 9 72 12 80 6 87 3')}</div>
      <div class="metric-card"><div class="metric-label">${icon('users')}Active users<span>↗</span></div><div class="metric-value">24,892</div><div class="metric-foot"><span class="change">↗ 12.8%</span>vs. last month</div>${sparkline('grass','M2 30 10 27 18 28 27 24 35 24 43 19 51 20 60 12 68 14 77 7 87 4')}</div>
      <div class="metric-card"><div class="metric-label">${icon('chart')}Conversion rate<span>↗</span></div><div class="metric-value">6.84<span style="font-size:22px">%</span></div><div class="metric-foot"><span class="change">↗ 2.1%</span>vs. last month</div>${sparkline('blue','M2 27 11 25 19 30 28 25 36 26 45 17 54 20 62 12 71 13 79 10 87 2')}</div>
    </div>`;
  }
  const monthly = [80,83,72,74,53,59,50,55,27,39,32,37,16,22,13,19,4,10,6,1];
  const quarterly = [93,83,88,79,62,68,57,62,45,51,39,33,37,20,27,16,18,7,12,0];
  function linePoints(values) { return values.map((v,i)=>`${i===0?'M':'L'}${(42+i*24.3).toFixed(1)} ${(19+v*1.02).toFixed(1)}`).join(' '); }
  function revenueChart(large=false) {
    const points=linePoints(state.range==='quarter'?quarterly:monthly);
    return `<section class="panel"><div class="panel-header"><div><h2>Revenue overview</h2><p>A little progress, every day.</p></div><div class="segmented"><button id="range-month" class="${state.range==='month'?'active':''}">This month</button><button id="range-quarter" class="${state.range==='quarter'?'active':''}">This quarter</button></div></div>
      <div class="chart-legend"><span><i class="legend-dot"></i>Revenue</span><span><i class="legend-dot pale"></i>Previous period</span><span style="margin-left:auto">${state.range==='month'?'September 2026':'Jul – Sep 2026'}</span></div>
      <div class="revenue-graph" id="revenue-chart" ${large?'style="height:244px"':''}><svg viewBox="0 0 550 166" preserveAspectRatio="none" aria-label="Revenue is up 18.4 percent compared with the previous period" role="img">
        <defs><linearGradient id="chart-fill" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#84b86f" stop-opacity=".23"/><stop offset="1" stop-color="#b7d8aa" stop-opacity=".02"/></linearGradient></defs>
        ${[24,57,90,123].map((y,i)=>`<line class="chart-gridline" x1="38" y1="${y}" x2="540" y2="${y}"/><text class="chart-axis" x="0" y="${y+3}">$${[30,20,10,0][i]}k</text>`).join('')}
        <path class="chart-comparison" d="M42 123L66 111 90 116 115 100 140 104 165 87 188 98 212 81 235 89 261 72 285 81 309 74 334 57 358 66 383 52 407 60 432 47 455 52 480 40 504 44"/>
        <path id="revenue-area" d="${points} L503.7 132H42Z" fill="url(#chart-fill)"/><path class="chart-line" id="revenue-line" d="${points}"/>
        <line id="chart-hover-line" class="chart-hover-line" x1="270" y1="15" x2="270" y2="133"/>
        ${[0,1,2,3,4,5,6].map((_,i)=>`<text class="chart-axis" x="${40+i*77}" y="156">${state.range==='month'?['Sep 01','Sep 05','Sep 10','Sep 15','Sep 20','Sep 25','Sep 30'][i]:['Jul 01','Jul 15','Aug 01','Aug 15','Sep 01','Sep 15','Sep 30'][i]}</text>`).join('')}
      </svg><div class="chart-tooltip" id="chart-tooltip"></div></div>
    </section>`;
  }
  function bindChart() {
    if(!$('#range-month'))return;
    $('#range-month').onclick=()=>{state.range='month';renderPage()}; $('#range-quarter').onclick=()=>{state.range='quarter';renderPage()};
    const graph=$('#revenue-chart'), tooltip=$('#chart-tooltip'),line=$('#chart-hover-line');
    graph.addEventListener('mousemove',event=>{
      const r=graph.getBoundingClientRect(), x=Math.min(r.width-55,Math.max(40,event.clientX-r.left));
      const value=Math.round(9400+(x/r.width)*22400).toLocaleString('en-US');
      tooltip.innerHTML=`<small>${state.range==='month'?'September':'This quarter'} · Revenue</small>$${value}.00`;
      tooltip.style.display='block';tooltip.style.left=`${Math.min(r.width-155,x+13)}px`;tooltip.style.top='24px';
      line.setAttribute('x1',x/r.width*550);line.setAttribute('x2',x/r.width*550);line.style.opacity='1';
    });
    graph.addEventListener('mouseleave',()=>{tooltip.style.display='none';line.style.opacity='0'});
  }
  function overview() {
    return pageHeading('THURSDAY, SEPTEMBER 10','Good morning, Alex.','Here’s what’s happening with your workspace today.',`<span class="status-pill"><i></i>All systems in sync</span>${newProjectButton}`)+metrics()+
      `<div class="chart-grid">${revenueChart()}<section class="launch-card"><div class="eyebrow">YOUR NEXT CHAPTER</div><div class="launch-heading">Big things start<br>with a little momentum.</div><div class="launch-progress-label"><span>September launch</span><strong>78<span style="font-size:12px">%</span></strong></div><div class="progress-track"><div class="progress-fill"></div></div><div class="launch-check"><span class="check">✓</span>Find your direction</div><div class="launch-check"><span class="check">✓</span>Make something you believe in</div><div class="launch-bottom">${avatars([0,1,2],true)}<button class="invite-inline" id="invite-team">${icon('plus')}Invite your team</button></div></section></div>
      <div class="section-heading"><div><h2>A little closer to done</h2><p>Your projects, moving in the right direction.</p></div><button class="text-button" id="view-all-projects">View all projects ${icon('right')}</button></div><div class="panel">${projectTable(state.projects.slice(0,3))}</div>`;
  }
  function projectTable(projects) {
    return `<table class="projects-table"><thead><tr><th>Project name</th><th>Status</th><th>Team</th><th>Progress</th><th>Due date</th><th></th></tr></thead><tbody>${projects.map(p=>`<tr data-project-row="${p.id}" data-project-name="${esc(p.name)}" tabindex="0" role="button" aria-label="Open ${esc(p.name)}"><td><div class="project-name-cell">${projectIcon(p)}${esc(p.name)}</div></td><td>${projectTag(p)}</td><td class="table-people">${avatars(p.people)}</td><td><div class="table-progress"><div class="track"><div class="fill" style="width:${p.progress}%"></div></div>${p.progress}%</div></td><td class="table-due">${p.due}, 2026</td><td class="project-trailing">${icon('dots')}</td></tr>`).join('')}</tbody></table>`;
  }
  function kanbanCard(p) {
    return `<article class="kanban-card ${p.id===state.lastCreated?'new-project-glow':''}" id="board-${p.id}" data-project-card="${p.id}" data-project-name="${esc(p.name)}" draggable="true" tabindex="0" role="button" aria-label="Open ${esc(p.name)}">
      ${['aurora','story','community'].includes(p.id)?`<div class="kanban-card-cover ${p.color}"><div class="cover-orbit"></div></div>`:''}
      ${tag(p.team,({Design:'',Engineering:'blue',Marketing:'orange'})[p.team])}<h3>${esc(p.name)}</h3><p>${esc(p.description).slice(0,95)}</p>
      <div class="card-footer">${icon('calendar')}${p.due}${avatars(p.people)}</div></article>`;
  }
  function filteredProjects() {
    let projects=state.projects.filter(p=>state.filter==='All projects'||p.team===state.filter);
    if(!state.sortAscending)projects=[...projects].reverse();return projects;
  }
  function projects() {
    const filtered=filteredProjects();
    return pageHeading('A SPACE FOR THE WORK THAT MATTERS','Everything in motion.','From the first spark to the finishing touches.',`${avatars([0,1,2,3],true)}${newProjectButton}`)+
      `<div class="project-tools"><div class="filter-tabs">${['All projects','Design','Engineering','Marketing'].map(f=>`<button class="filter-tab ${state.filter===f?'active':''}" id="filter-${f==='All projects'?'all':f.toLowerCase()}" data-filter="${f}">${f}</button>`).join('')}</div><div class="filter-spacer"></div><button class="filter-button" id="sort-projects">${icon('filter')}${state.sortAscending?'Newest first':'Oldest first'}</button><div class="view-switch"><button id="view-board" class="${state.view==='board'?'active':''}" aria-label="Board view">${icon('board')}</button><button id="view-list" class="${state.view==='list'?'active':''}" aria-label="List view">${icon('list')}</button></div></div>`+
      (state.view==='list'?`<div class="panel">${projectTable(filtered)}</div>`:`<div class="kanban">${['planned','in-progress','review','done'].map(status=>`<section class="kanban-column" id="column-${status}" data-status="${status}"><div class="column-heading"><i class="column-dot ${status}"></i>${statusName(status)}<span class="column-count">${filtered.filter(p=>p.status===status).length}</span><button data-add-status="${status}" aria-label="Add ${statusName(status)} project">+</button></div>${filtered.filter(p=>p.status===status).map(kanbanCard).join('')}<button class="add-card" data-add-status="${status}">${icon('plus')}Add project</button></section>`).join('')}</div>`);
  }
  function analytics() {
    return pageHeading('THE NUMBERS TELL A STORY','Look at you grow.','A clearer picture of the progress you’re making.',`<button class="button" id="export-report">${icon('chart')}View report</button>`)+metrics()+
      `<div class="analytic-grid">${revenueChart(true)}<div class="panel"><div class="panel-header"><div><h2>Where good things begin</h2><p>Your acquisition channels.</p></div>${icon('globe')}</div><div class="source-list">${[['Organic search',64,'#88ba74'],['Direct',46,'#a8bcce'],['Social',32,'#bdcba7'],['Referrals',22,'#d8c3a9'],['Other',12,'#c6cbd4']].map(([name,value,color])=>`<div class="source-row"><span class="source-label">${name}</span><div class="source-line"><div style="width:${value}%;background:${color}"></div></div><span>${value}%</span></div>`).join('')}</div></div></div>
      <div class="panel" style="margin-top:20px"><div class="panel-header"><h2>Little wins, lately</h2><span class="muted" style="font-size:12px">Across your workspace</span></div><div class="activity-list">${[['Jamie Kim','finished the component library','Design system 2.0','8 min ago',1],['Maya Reed','shared the launch direction','Website redesign','24 min ago',2],['Sam Kim','shipped a faster sign-in','Mobile experience','1 hr ago',3]].map(([name,verb,project,time,person])=>`<div class="activity-row">${avatar(person)}<p><b>${name}</b> ${verb}<small>${project}</small></p><time>${time}</time></div>`).join('')}</div></div>`;
  }
  function inbox() {
    const items=[['Maya shared an update','The new direction is ready for a fresh pair of eyes. Take a look at the latest for Website redesign.','12 min ago',2,'aurora'],['A little closer to launch','Design system 2.0 is ready for review. Your team has checked off 23 of 25 tasks.','45 min ago',1,'system'],['Sam mentioned you','“Would love your thoughts on the new mobile onboarding, @Alex.”','1 hr ago',3,'mobile'],['Good things, together','Community launch is complete. A little celebration is in order.','Yesterday',4,'community']];
    return pageHeading('STAY IN THE LOOP','A few things for you.','The conversations that keep good work moving.',`<button class="button" id="mark-all-read">${icon('check')}${state.readInbox?'All caught up':'Mark all as read'}</button>`)+`<div class="panel inbox-list">${items.map(([title,body,time,person,id])=>`<div class="inbox-item" data-project-row="${id}" role="button" tabindex="0">${avatar(person)}<div><h3>${title}</h3><p>${body}</p></div><small>${time}</small>${state.readInbox?'':'<span class="inbox-unread"></span>'}</div>`).join('')}</div>`;
  }
  function team() {
    const members=[['Alex Lane','alex@acme.design','Owner'],['Jamie Kim','jamie@acme.design','Designer'],['Maya Reed','maya@acme.design','Marketing'],['Sam Kim','sam.k@acme.design','Engineer'],['Emery West','emery@acme.design','Engineer']];
    return pageHeading('BETTER, TOGETHER','Meet your people.','Different perspectives. One shared direction.',`<button class="button primary" id="invite-team">${icon('plus')}Invite teammate</button>`)+`<div class="settings-grid"><section class="panel settings-section"><h2>Team members <span class="muted" style="font-size:13px">${members.length+state.invites.length}</span></h2><table class="members-table"><tbody>${members.map(([name,email,role],i)=>`<tr><td>${avatar(i)}<div>${name}<small>${email}</small></div></td><td>${role}</td></tr>`).join('')}${state.invites.map(email=>`<tr><td>${avatar(4)}<div>${esc(email)}<small>Invitation is on its way</small></div></td><td>${tag('Invited','orange')}</td></tr>`).join('')}</tbody></table></section><section class="panel settings-section"><h2>A place to do your best work</h2><div class="plan-highlight"><h3>Acme, in good company.</h3><p>Give everyone a little room to explore. Your Pro plan has space for 20 teammates.</p><div class="plan-price">${members.length+state.invites.length}<small> / 20 seats</small></div><button class="button soft" id="team-plan">Explore your plan ${icon('right')}</button></div></section></div>`;
  }
  function settings() {
    return pageHeading('MAKE YOURSELF AT HOME','Your space. Your rhythm.','A few little details that make Orbit yours.')+`<div class="settings-grid"><section class="panel settings-section"><h2>Workspace details</h2><form id="workspace-form"><label class="field"><span class="field-label">Workspace name</span><input id="workspace-name" class="input" value="${esc(state.workspace)}" required maxlength="40"></label><label class="field"><span class="field-label">Workspace URL</span><input class="input" value="app.orbit.so/acme-studio" readonly></label><button class="button accent" type="submit">Save changes</button></form><div class="setting-line" style="margin-top:25px"><span><b>Email notifications</b><small>Keep the important things close.</small></span><input class="switch" id="setting-notifications" type="checkbox" aria-label="Email notifications" ${state.notifications?'checked':''}></div><div class="setting-line"><span><b>Weekly digest</b><small>A little perspective every Monday.</small></span><input class="switch" id="setting-digest" type="checkbox" aria-label="Weekly digest" ${state.digest?'checked':''}></div></section><section class="panel settings-section"><h2>Your current plan</h2><div class="plan-highlight"><h3>A little more possibility.</h3><p>You’re on Orbit Pro. A shared space for your team’s biggest ideas.</p><div class="plan-price">$24<small> / seat / month</small></div><button class="button soft" id="settings-plan">Plan details ${icon('right')}</button></div></section></div>`;
  }
  function renderPage() {
    $('#page-content').innerHTML=({overview,projects,analytics,inbox,team,settings})[state.page]();
    if($('#new-project'))$('#new-project').onclick=()=>openNewProject();
    if($('#invite-team'))$('#invite-team').onclick=openInvite;
    if($('#view-all-projects'))$('#view-all-projects').onclick=()=>navigate('projects');
    $$('[data-project-row],[data-project-card]').forEach(el=>{
      const id=el.dataset.projectRow||el.dataset.projectCard;el.onclick=()=>openDetail(id);
      el.onkeydown=e=>{if(e.key==='Enter')openDetail(id)};
      if(el.draggable)el.ondragstart=e=>{e.dataTransfer.setData('text/plain',id);e.dataTransfer.effectAllowed='move'};
    });
    $$('[data-add-status]').forEach(el=>el.onclick=()=>openNewProject(el.dataset.addStatus));
    $$('[data-filter]').forEach(el=>el.onclick=()=>{state.filter=el.dataset.filter;renderPage()});
    $$('[data-status]').forEach(el=>{
      el.ondragover=e=>{e.preventDefault();el.classList.add('drag-over')};
      el.ondragleave=()=>el.classList.remove('drag-over');
      el.ondrop=e=>{e.preventDefault();const p=state.projects.find(p=>p.id===e.dataTransfer.getData('text/plain'));if(p){p.status=el.dataset.status;if(p.status==='done')p.progress=100;renderPage();toast('A little progress. A good feeling.',`${p.name} moved to ${statusName(p.status).toLowerCase()}.`)}};
    });
    if($('#view-board'))$('#view-board').onclick=()=>{state.view='board';renderPage()};
    if($('#view-list'))$('#view-list').onclick=()=>{state.view='list';renderPage()};
    if($('#sort-projects'))$('#sort-projects').onclick=()=>{state.sortAscending=!state.sortAscending;renderPage()};
    if($('#mark-all-read'))$('#mark-all-read').onclick=()=>{state.readInbox=true;shell();toast('You’re all caught up.','A little space for what comes next.')};
    if($('#export-report'))$('#export-report').onclick=openReport;
    ['team-plan','settings-plan'].forEach(id=>{if($('#'+id))$('#'+id).onclick=openPlan});
    if($('#workspace-form'))$('#workspace-form').onsubmit=e=>{e.preventDefault();state.workspace=$('#workspace-name').value.trim()||'Acme Studio';shell();toast('Made it yours.','Workspace details updated.')};
    if($('#setting-notifications'))$('#setting-notifications').onchange=e=>state.notifications=e.target.checked;
    if($('#setting-digest'))$('#setting-digest').onchange=e=>state.digest=e.target.checked;
    bindChart();
  }
  function showModal(content,className='') {
    state.overlay='modal';$('#overlay-root').innerHTML=`<div class="modal-backdrop" id="modal-backdrop"><section class="modal ${className}" role="dialog" aria-modal="true">${content}</section></div>`;
    $('#modal-backdrop').onclick=e=>{if(e.target.id==='modal-backdrop')closeOverlay()};
    $$('[data-close-modal]').forEach(el=>el.onclick=closeOverlay);
  }
  const modalTop = symbol => `<div class="modal-top"><div class="modal-symbol">${icon(symbol)}</div><button class="icon-button" data-close-modal aria-label="Close dialog">${icon('close')}</button></div>`;
  function closeOverlay() { state.overlay=null;$('#overlay-root').innerHTML=''; }
  function openNewProject(status='planned') {
    state.selectedTeam='Design';
    showModal(`${modalTop('spark')}<h2>Start something good.</h2><p class="description">Every great idea deserves a little room to grow.</p><form id="new-project-form">
      <label class="field"><span class="field-label">Project name</span><input class="input" id="project-name" placeholder="Give your idea a name" autocomplete="off" required maxlength="64"></label>
      <label class="field"><span class="field-label">A little context <span>· optional</span></span><textarea class="input textarea" id="project-description" placeholder="What are you hoping to make?" maxlength="400"></textarea></label>
      <div class="field"><span class="field-label">Made for</span><div class="team-options">${['Design','Engineering','Marketing'].map(t=>`<button type="button" id="team-${t.toLowerCase()}" class="team-option ${t==='Design'?'active':''}" data-team="${t}">${icon({Design:'layers',Engineering:'box',Marketing:'spark'}[t])}${t}</button>`).join('')}</div></div>
      <div class="form-error" id="project-error" role="alert"></div><div class="modal-bottom"><span class="modal-note">${icon('lock')}Shared with your workspace</span><button class="button accent" id="create-project" type="submit">Create project ${icon('right')}</button></div></form>`);
    $$('[data-team]').forEach(el=>el.onclick=()=>{state.selectedTeam=el.dataset.team;$$('[data-team]').forEach(b=>b.classList.toggle('active',b===el))});
    $('#new-project-form').onsubmit=e=>{
      e.preventDefault();const name=$('#project-name').value.trim();
      if(!name){$('#project-error').textContent='Give your project a name first.';return}
      if(state.projects.some(p=>p.name.toLowerCase()===name.toLowerCase())){$('#project-error').textContent='That project already has a home here. Try another name.';return}
      const project={id:'project-'+(state.projects.length+1),name,description:$('#project-description').value.trim()||'A little room for your next big idea.',team:state.selectedTeam,status,progress:0,due:'Oct 15',color:{Design:'',Engineering:'blue',Marketing:'orange'}[state.selectedTeam],icon:'spark',people:[0,2],tasks:[false,false,false,false,false]};
      state.projects.unshift(project);state.lastCreated=project.id;state.filter='All projects';navigate('projects');
      toast('And just like that, a new beginning.',`${name} is ready for your team.`);
    };
    setTimeout(()=>$('#project-name')?.focus(),180);
  }
  function openDetail(id) {
    const p=state.projects.find(p=>p.id===id);if(!p)return;
    state.overlay='detail';
    const taskNames=['Find the creative direction','Build the landing page','Connect the payment flow','Add a little analytics','Share it with the team'];
    $('#overlay-root').innerHTML=`<div class="drawer-backdrop" id="detail-backdrop"><section class="drawer" role="dialog" aria-modal="true" aria-labelledby="detail-title"><div class="drawer-toolbar"><span>PROJECT / ${esc(p.team).toUpperCase()}</span><button class="icon-button" id="close-detail" aria-label="Close project">${icon('close')}</button></div>
      <div class="project-icon drawer-project-icon ${p.color}">${icon(p.icon)}</div><h2 id="detail-title">${esc(p.name)}</h2><p class="drawer-description">${esc(p.description)}</p>
      <div class="detail-row"><span>Status</span><button id="cycle-project-status" aria-label="Change project status">${projectTag(p)}</button></div><div class="detail-row"><span>Made with</span>${avatars(p.people)}</div><div class="detail-row"><span>Due date</span><span style="color:#8c98a7;font-size:13px">${p.due}, 2026</span></div>
      <div class="detail-progress" id="detail-progress"><div><span>A little closer to done</span><strong id="detail-percentage">${p.progress}%</strong></div><div class="progress-track"><div class="progress-fill" id="detail-progress-fill" style="width:${p.progress}%"></div></div></div>
      <div class="task-heading">The little steps</div>${taskNames.map((name,i)=>`<button class="task-row ${p.tasks[i]?'done':''}" id="${i===2?'task-payment':'task-'+i}" data-task="${i}" aria-pressed="${p.tasks[i]}"><span class="task-checkbox">${p.tasks[i]?'✓':''}</span><span class="task-text">${name}</span>${i===2?'<small>Today</small>':''}</button>`).join('')}
      <div class="detail-activity">${avatar(2)}<p>Maya added a little inspiration.<br><small>“Really excited about where this is going.” · 24m</small></p></div>
    </section></div>`;
    $('#close-detail').onclick=closeOverlay;$('#detail-backdrop').onclick=e=>{if(e.target.id==='detail-backdrop')closeOverlay()};
    $$('[data-task]').forEach(el=>el.onclick=()=>{
      const i=Number(el.dataset.task);p.tasks[i]=!p.tasks[i];p.progress=Math.round(p.tasks.filter(Boolean).length/p.tasks.length*100);
      el.classList.toggle('done',p.tasks[i]);el.setAttribute('aria-pressed',String(p.tasks[i]));$('.task-checkbox',el).textContent=p.tasks[i]?'✓':'';
      $('#detail-percentage').textContent=p.progress+'%';$('#detail-progress-fill').style.width=p.progress+'%';
      renderPage();
    });
    $('#cycle-project-status').onclick=()=>{const statuses=['planned','in-progress','review','done'];p.status=statuses[(statuses.indexOf(p.status)+1)%4];if(p.status==='done'){p.progress=100;p.tasks=p.tasks.map(()=>true)}renderPage();openDetail(id)};
  }
  function openSearch() {
    showModal(`<div class="search-field-row">${icon('search')}<input class="search-input" id="search-input" placeholder="Find a little bit of anything…" autocomplete="off" aria-label="Search projects"><kbd>ESC</kbd></div><div class="search-results" id="search-results"></div><div class="search-footer"><span>Projects, people, and possibilities.</span><span>↵ to open &nbsp; esc to close</span></div>`,'search-modal');
    const update=()=>{
      const query=$('#search-input').value.toLowerCase(),results=state.projects.filter(p=>(p.name+' '+p.team+' '+p.description).toLowerCase().includes(query));
      $('#search-results').innerHTML=`<div class="search-label">${query?'PROJECTS · '+results.length:'PICK UP WHERE YOU LEFT OFF'}</div>`+(results.length?results.slice(0,5).map((p,i)=>`<button class="search-result" id="search-result-${i}" data-search-project="${p.id}">${projectIcon(p)}<span><b>${esc(p.name)}</b><small>${p.team} · ${statusName(p.status)}</small></span>${icon('return')}</button>`).join(''):`<div class="empty-state">${icon('search')}<h3>A little too well hidden.</h3><p>Try a different name or a shorter search.</p></div>`);
      $$('[data-search-project]').forEach(el=>el.onclick=()=>openDetail(el.dataset.searchProject));
    };
    $('#search-input').oninput=update;$('#search-input').onkeydown=e=>{if(e.key==='Enter')$('#search-result-0')?.click()};update();setTimeout(()=>$('#search-input')?.focus(),150);
  }
  function openInvite() {
    showModal(`${modalTop('users')}<h2>Good work is a team sport.</h2><p class="description">Invite someone to share in the next chapter.</p><form id="invite-form"><label class="field"><span class="field-label">Their email address</span><input class="input" id="invite-email" type="email" placeholder="someone@yourteam.com" required autocomplete="off"></label><div style="margin:20px 0 5px;display:flex;align-items:center;gap:9px">${avatars([0,1,2,3],true)}<span style="font-size:12px;color:#a6afbc">There’s always room for one more.</span></div><div class="form-error" id="invite-error" role="alert"></div><div class="modal-bottom"><span class="modal-note">${icon('lock')}Member access</span><button class="button accent" id="send-invite" type="submit">Send invitation ${icon('right')}</button></div></form>`);
    $('#invite-form').onsubmit=e=>{e.preventDefault();const email=$('#invite-email').value.trim().toLowerCase();if(state.invites.includes(email)){$('#invite-error').textContent='They already have an invitation waiting.';return}state.invites.push(email);closeOverlay();renderPage();toast('Good company is on its way.',`Invitation sent to ${email}`)};
    setTimeout(()=>$('#invite-email')?.focus(),180);
  }
  function openPlan() {
    showModal(`${modalTop('spark')}<h2>A little more possibility.</h2><p class="description">Orbit Pro gives good ideas room to grow.</p><div class="plan-highlight"><h3>You’re in a good place.</h3><p>Unlimited projects · 20 teammates<br>Advanced insights · Shared workspaces<br>Everything you need to find your flow.</p><div class="plan-price">$24<small> / seat / month</small></div>${tag('Your current plan','green')}</div><div class="modal-bottom"><span class="modal-note">Next renewal · October 1, 2026</span><button class="button" data-close-modal>Sounds good</button></div>`);
  }
  function openProfile() {
    showModal(`${modalTop('users')}<h2>A little about you.</h2><p class="description">Alex Lane · Workspace owner</p><div style="display:flex;align-items:center;gap:15px;margin:22px 0">${avatar(0)}<div style="font-size:15px">Alex Lane<br><span style="font-size:13px;color:#a0a9b5">alex@acme.design</span></div></div><div class="help-line"><span>Workspace</span><span>${esc(state.workspace)}</span></div><div class="help-line"><span>Time zone</span><span>San Francisco · PDT</span></div><div class="modal-bottom"><span class="modal-note">Here since the very beginning.</span><button class="button" data-close-modal>Back to the good stuff</button></div>`);
  }
  function openHelp() {
    showModal(`${modalTop('help')}<h2>A few little shortcuts.</h2><p class="description">Less looking around. More getting somewhere.</p><div class="help-line"><span>Find anything</span><span class="keyboard-key">⌘ K</span></div><div class="help-line"><span>Close a dialog</span><span class="keyboard-key">esc</span></div><div class="help-line"><span>Open a search result</span><span class="keyboard-key">↵</span></div><div class="help-line"><span>Move a project</span><span>Drag it between columns</span></div><div class="modal-bottom"><span class="modal-note">A little practice goes a long way.</span><button class="button" data-close-modal>Got it</button></div>`);
  }
  function openReport() {
    showModal(`${modalTop('chart')}<h2>Look how far you’ve come.</h2><p class="description">September 2026 · Acme Studio</p><div class="help-line"><span>Total revenue</span><b>$84,254.00</b></div><div class="help-line"><span>Active users</span><b>24,892</b></div><div class="help-line"><span>Conversion rate</span><b>6.84%</b></div><div class="help-line"><span>Projects in motion</span><b>${state.projects.filter(p=>p.status!=='done').length}</b></div><div class="modal-bottom"><span class="modal-note">A good month, by the numbers.</span><button class="button accent" data-close-modal>Keep the momentum</button></div>`);
  }
  let toastTimer;
  function toast(title,subtitle='') {
    clearTimeout(toastTimer);$('#toast-root').innerHTML=`<div class="toast"><span class="toast-symbol">${icon('check')}</span><span><b>${esc(title)}</b><small>${esc(subtitle)}</small></span></div>`;
    toastTimer=setTimeout(()=>{$('.toast')?.classList.add('fade-out');setTimeout(()=>$('#toast-root').innerHTML='',320)},3600);
  }
  document.addEventListener('keydown',e=>{
    if((e.metaKey||e.ctrlKey)&&e.key.toLowerCase()==='k'){e.preventDefault();openSearch()}
    if(e.key==='Escape')closeOverlay();
  });
  shell();
})();
