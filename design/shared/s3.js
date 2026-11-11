/* ش3 · موضع التوقّف · محرّك الصفحة المرجعية design/s3.html
   يبني على محرّك ش2 (التظليل والتراجع والعمر وآخر إدخال والتفاصيل) ويضيف الدورة (5.5):
   تقدّم الدورة «22 من 36»، وعلامة موضع التوقّف على أول ربع لم يُظلَّل منذ بداية الدورة،
   وانتقال الصفّ المطويّ معها، والنزول التلقائي عند فتح الأرشيف، واكتمال الدورة وسطرها،
   والزرّ اليدوي «ابدأ دورة جديدة» بتأكيده، والإضافة في منتصف الدورة.
   هذا منطق عرض للصفحة وحدها، لا قواعد البيانات. المرجع المكتوب: design/system.md §14. */
(function(){
const W=window.WIRD,S2=window.S2,{R,N,TT}=W;
const ADD='<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"><circle cx="12" cy="12" r="8.5"/><path d="M12 8v8M8 12h8"/></svg>';
const MOVE='<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M4 8h13l-3.5-3.5M20 16H7l3.5 3.5"/></svg>';
const TRASH='<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M4 7h16M9 7V4.5h6V7M6.5 7l1 12.5h9l1-12.5M10 11v5M14 11v5"/></svg>';
/* «ابدأ دورة جديدة»: سهم دائري (SF Symbol: arrow.counterclockwise) */
const RESTART='<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M4.5 12a7.5 7.5 0 1 0 2.2-5.3"/><path d="M4.5 3.8v4h4"/></svg>';
/* علامة الاكتمال: صحّ في دائرة (SF Symbol: checkmark.circle) */
const DONE='<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9.5"/><path d="M8 12.3l2.7 2.7L16 9.6"/></svg>';

/* عدد الأيام مع معدوده: يوم واحد · يومان · 3–10 أيام · 11 يوماً فأكثر */
const days=n=>n===1?'يوم واحد':n===2?'يومان':n<=10?`${N(n)} أيام`:`${N(n)} يوماً`;

/* ── الدورة ──
   S.cs[t] بداية الدورة الحالية: {d: قبل كم يوماً, seq: ترتيب الإدخال}. والتظليل في الدورة إن كان بعد بدايتها.
   S.ended[t] آخر اكتمال تلقائي: {d, days, prev, seq}، لسطر الاكتمال وللتراجع عنه في يومه. */
const after=(e,c)=>e.d<c.d||(e.d===c.d&&(e.seq||0)>c.seq);
function sync(S){
  ['far','near'].forEach(t=>{const c=S.cs[t];S.cyc[t]=new Set(W.trackQuarters(S,t).filter(r=>{const e=(S.hist[r]||[])[0];return e&&after(e,c);}));
  });
}
function make(o){
  const S=S2.make(Object.assign({hideMeta:false,hideBm:false},o));
  S.seq=0;S.cs={far:{d:o.cycle?.far??18,seq:Infinity},near:{d:o.cycle?.near??5,seq:Infinity}};S.ended={};S.pin=null;
  sync(S);return S;
}
const complete=(S,t)=>W.trackQuarters(S,t).length>0&&W.trackQuarters(S,t).every(r=>S.cyc[t].has(r));
/* الضغطة (5.3) مع الدورة (5.5). تُرجع 'done' إن اكتملت بها الدورة */
function tap(S,r,t,now){
  const h=S.hist[r]||(S.hist[r]=[]),undo=h[0]&&h[0].d===0,removed=undo?h[0]:null;
  S2.tap(S,r,now);
  if(!undo){h[0].seq=++S.seq;sync(S);
    if(complete(S,t)){S.ended[t]={d:0,days:S.cs[t].d+1,prev:S.cs[t],seq:S.seq};S.cs[t]={d:0,seq:S.seq};sync(S);return 'done';}
    return;}
  /* تراجع عن تظليل كان من الدورة التي اكتملت اليوم: تعود تلك الدورة كما كانت (§14.4) */
  const x=S.ended[t];
  if(x&&x.d===0&&(removed.seq||0)<=x.seq){S.cs[t]=x.prev;delete S.ended[t];}
  sync(S);
}
/* «ابدأ دورة جديدة» (5.5): يدوي، بلا سطر اكتمال */
function restart(S,t){S.cs[t]={d:0,seq:++S.seq};delete S.ended[t];sync(S);}
/* يوم جديد: تتقدّم الأعمار، ويختفي سطر الاكتمال بعد يومه */
function advance(S,n){S2.advance(S,n);['far','near'].forEach(t=>{S.cs[t].d+=n;if(S.ended[t])S.ended[t].d+=n;});sync(S);}
/* إضافة حزب في منتصف الدورة: يدخل الدورة الحالية بأرباعه، ولا يُعدّ منها إلا ما ظُلّل بعد بدايتها */
function add(S,t,h){if(!S[t].includes(h))S[t].push(h);S[t].sort((a,b)=>a-b);W.quartersOf(h).forEach(r=>{if(!S.hist[r])S.hist[r]=[];});sync(S);}
/* يظهر في يوم الاكتمال ما دامت الدورة الجديدة بلا تظليل، ويعود إن تُراجع عن أول تظليل فيها (ذ25) */
const lineOn=(S,t)=>{const x=S.ended[t];return !!(x&&x.d===0&&!S.cyc[t].size);};

/* ── الشاشة ── */
function trackMenu(S,ui){
  const can=S.cyc[ui.t].size>0; /* لا دورة جديدة وما ظُلّل في هذه شيء (§14.5) */
  return `<div class="dim" data-close style="background:transparent"></div><div class="menu" data-anchor="more" role="menu">
    <div class="mi" data-tm="add"><span>إضافة</span>${ADD}</div>
    <div class="mi" data-tm="move"><span>نقل</span>${MOVE}</div>
    <div class="mi" data-tm="remove"><span>إزالة</span>${TRASH}</div>
    <div class="gap6"></div>
    <div class="mi${can?'':' off'}" data-tm="${can?'restart':''}" ${can?'':'aria-disabled="true"'}><span>ابدأ دورة جديدة</span>${RESTART}</div></div>`;
}
function confirmDlg(S,ui){
  return `<div class="dim top"></div><div class="dlg" role="alertdialog"><h4>أتبدأ دورة جديدة في ${TT[ui.t]}؟</h4>
    <p>يعود موضع التوقّف إلى أول المسار، وتُعدّ الأرباع من جديد. وسجلّ التلاوة كما هو.</p>
    <button class="btn pri" data-nc="yes">ابدأ دورة جديدة</button><button class="btn quiet" data-nc="no">إلغاء</button></div>`;
}
function screen(S,ui={}){
  const base=S2.screen(S,{ov:ui.ov==='qd'?'qd':null,r:ui.r,t:ui.t,shared:ui.shared,toast:ui.ov?null:ui.toast});
  const extra=ui.ov==='tmenu'?trackMenu(S,ui):ui.ov==='nc'?confirmDlg(S,ui):'';
  return base+extra;
}
/* سطر الاكتمال مكان تقدّم الدورة في رأس البطاقة (§14.4، ذ19) */
function decorate(scr,S){
  ['far','near'].forEach(t=>{const m=scr.querySelector(`.track[data-track="${t}"] .meta2`);if(!m)return;
    m.setAttribute('aria-label',`تقدّم الدورة: ${m.textContent} ربعاً`);
    if(lineOn(S,t)){m.classList.add('cdone');const d=days(S.ended[t].days);
      m.innerHTML=`${DONE}<b class="lg">اكتملت الدورة</b><b class="sh">اكتملت</b><span>· ${d}</span>`;
      m.setAttribute('aria-label',`اكتملت دورة ${TT[t]} في ${d}`);}});
  /* إن لم يتّسع الرأس للعنوان والسطر كاملاً قُصر إلى «اكتملت · 19 يوماً» */
  const k=scr.getBoundingClientRect().width/scr.offsetWidth||1;
  scr.querySelectorAll('.th .meta2.cdone').forEach(m=>{const th=m.closest('.th'),h3=th.querySelector('h3'),rg=document.createRange();rg.selectNodeContents(h3);
    const others=[...th.children].filter(e=>e!==h3&&e!==m).reduce((a,e)=>a+e.offsetWidth,0),gaps=10*(th.children.length-1)-12;
    if(rg.getBoundingClientRect().width/k+m.offsetWidth+others+gaps>th.clientWidth)m.classList.add('short');});
}
function place(scr,ui){
  const m=scr.querySelector('.menu');if(!m)return;
  const sr=scr.getBoundingClientRect(),k=sr.width/scr.offsetWidth,a=scr.querySelector(`.track[data-track="${ui.t}"] .more`).getBoundingClientRect();
  m.style.top=((a.bottom-sr.top)/k+2)+'px';m.style.left=Math.max(12,(a.left-sr.left)/k+4)+'px';
}
/* النزول التلقائي (5.5 · 7.1): أول ظهور لموضع التوقّف عند 30% من ارتفاع ما يُرى من الأرشيف، بلا حركة (§14.2) */
function toBookmark(scr,t){
  const sc=scr.querySelector('.scroll'),b=scr.querySelector(`.track[data-track="${t}"] .q.bm`);if(!sc||!b)return;
  const row=b.closest('.row'),pull=scr.querySelector(`.track[data-track="${t}"] .pull`),vis=sc.clientHeight-(pull?pull.offsetHeight:0);
  const top=row.getBoundingClientRect().top-sc.getBoundingClientRect().top+sc.scrollTop;
  sc.scrollTop=Math.max(0,top-vis*0.3);
}
function paint(scr,S,ui){scr.innerHTML=screen(S,ui);decorate(scr,S);S2.sizeFold(scr);place(scr,ui);}

/* ── هاتف تفاعلي ── */
function interactive(scr,S,o={}){
  let ui={},tm,pt;
  const render=(keep=true,swap)=>{const y=scr.querySelector('.scroll')?.scrollTop||0;paint(scr,S,ui);if(keep)scr.querySelector('.scroll').scrollTop=y;
    if(swap)scr.querySelector(`.track[data-track="${swap}"] .cur`)?.classList.add('swap');wire();o.onRender&&o.onRender(S);};
  const toast=m=>{ui={toast:m};render();clearTimeout(tm);tm=setTimeout(()=>{ui={};render();},2500);};
  const shownHizb=t=>{const b=W.bookmark(S,t);return b?R[b].hizb:null;};
  function onTap(r,t){
    const before=shownHizb(t),pinned=S.pin&&S.pin[t];
    clearTimeout(pt);
    tap(S,r,t);
    /* الصفّ المطويّ يبقى على حزبه 0.8 ث ثم ينتقل بتلاشٍ 0.25 ث، فيرى المالك ما ظلّله ويتراجع إن شاء (§14.3) */
    const now=shownHizb(t),from=pinned||before;
    if(!S.open&&now!==from){S.pin={[t]:from};ui={};render();pt=setTimeout(()=>{S.pin=null;render(true,t);},800);}
    else{S.pin=null;ui={};render();}
  }
  function wire(){
    const $=(q,f)=>scr.querySelectorAll(q).forEach(e=>e.onclick=()=>f(e));
    $('[data-toggle]',e=>{const t=e.dataset.toggle;S.open=S.open===t?null:t;S.pin=null;ui={};render(false);if(S.open)toBookmark(scr,S.open);});
    $('[data-close]',()=>{ui={};render();});
    $('[data-undo]',()=>{const r=ui.r,t=ui.t;ui={};onTap(r,t);});
    $('[data-more]',e=>{ui={ov:'tmenu',t:e.dataset.more};render();});
    $('[data-tm]',e=>{const a=e.dataset.tm;if(!a)return;if(a==='restart'){ui={ov:'nc',t:ui.t};render();}else{ui={};render();}});
    $('[data-nc]',e=>{const t=ui.t;if(e.dataset.nc==='yes'){restart(S,t);S.pin=null;toast(`بدأت دورة جديدة في ${TT[t]}`);if(S.open===t)toBookmark(scr,t);}else{ui={};render();}});
    scr.querySelectorAll('.q[data-r]').forEach(el=>{let lp,long=false;
      const open=()=>{long=true;ui={ov:'qd',r:+el.dataset.r,t:el.dataset.t,shared:!!el.querySelector('.cut')};render();};
      el.onpointerdown=()=>{long=false;lp=setTimeout(open,450);};
      el.onpointerleave=()=>clearTimeout(lp);
      el.onpointerup=()=>{clearTimeout(lp);if(long)return;onTap(+el.dataset.r,el.dataset.t);};
      el.oncontextmenu=ev=>{ev.preventDefault();clearTimeout(lp);open();};});
  }
  render();
  return {render,S,advance:n=>{advance(S,n);ui={};render();},add:(t,h)=>{add(S,t,h);toast(`أُضيف ح ${N(h)} إلى ${TT[t]}`);}};
}
/* رسم ثابت لحالة واحدة (للصفحة واللقطات) */
function still(scr,S,ui,afterFn){paint(scr,S,ui||{});
  if(ui&&ui.swap)scr.querySelector(`.track[data-track="${ui.swap}"]`)?.classList.add('pinned');
  setTimeout(()=>{if(S.open&&!(ui&&ui.noScroll))toBookmark(scr,S.open);afterFn&&afterFn(scr);},40);}
window.S3={make,tap,restart,advance,add,screen,still,interactive,days,toBookmark,lineOn,decorate};
})();
