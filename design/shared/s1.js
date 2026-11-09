/* ش1 · المحفوظ · محرّك الصفحة المرجعية design/s1.html
   يرسم الشاشة الرئيسية كما تكون في ش1 (بلا تظليل ولا عدّاد ولا مفاتيح؛ تأتي في ش2 وش5)،
   والحالة الفارغة، وورقة الإضافة، وسؤال النقل، والقوائم، والنقل والإزالة. المرجع: design/system.md §12. */
(function(){
const W=window.WIRD,{R,SN,N,quartersOf,BM,GEAR}=W;
const TT={far:'مراجعة البعيد',near:'مراجعة القريب',new:'المحفوظ الجديد'};
const SHORT={far:'البعيد',near:'القريب'};
const OTHER={far:'near',near:'far'};
const PLUS='<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg>';
const MOVE='<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M4 8h13l-3.5-3.5M20 16H7l3.5 3.5"/></svg>';
const TRASH='<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M4 7h16M9 7V4.5h6V7M6.5 7l1 12.5h9l1-12.5M10 11v5M14 11v5"/></svg>';
const ADD='<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"><circle cx="12" cy="12" r="8.5"/><path d="M12 8v8M8 12h8"/></svg>';

/* العدد مع المعدود، والأرقام إنجليزية */
function hizbs(list){const n=list.length;
  if(n===1)return `الحزب ${N(list[0])}`;if(n===2)return 'حزبين';if(n<=10)return `${N(n)} أحزاب`;return `${N(n)} حزباً`;}
/* المرفوع (نائب الفاعل في الإشعار): ح 9 · حزبان · 3 أحزاب · 11 حزباً */
function hizbsNom(list){const n=list.length;
  if(n===1)return `ح ${N(list[0])}`;if(n===2)return 'حزبان';if(n<=10)return `${N(n)} أحزاب`;return `${N(n)} حزباً`;}
/* الضمير العائد: ـه · ـهما · ـها */
const P=n=>n===1?'ه':n===2?'هما':'ها';
function hizbsSubj(list){const n=list.length;
  if(n===1)return `الحزب ${N(list[0])}`;if(n===2)return `الحزبان ${N(list[0])} و${N(list[1])}`;return `${N(n)} أحزاب`;}
const firstSura=h=>SN[R[(h-1)*4+1].suras[0]];
const trackOf=(S,h)=>['far','near'].find(t=>S[t].includes(h));

/* ── الشاشة ── */
function emptyCard(t){
  const msg=t==='new'?'لم تحدّد بعدُ الحزب الذي تحفظه.':'لم تُضف إليه شيئاً بعد.';
  const btn=t==='new'?'':`<button class="btn add" data-add="${t}">${PLUS}أضف جزءاً أو حزباً</button>`;
  const more=t==='new'?'':`<span class="more" data-more="${t}" role="button" aria-label="قائمة المسار">⋯</span>`;
  return `<div class="track empty" style="--c:var(--${t})" data-track="${t}"><div class="th"><span class="mk"></span><h3>${TT[t]}</h3>${more}</div>
    <div class="emp"><p>${msg}</p>${btn}</div></div>`;
}
function card(S,t){
  if(t==='new')return emptyCard('new'); // اختيار الحزب الذي يُحفظ: ش4
  return S[t].length?W.trackHTML(S,t):emptyCard(t);
}
function screen(S,ui){
  return `<div class="island"></div><div class="status"><span>5:12</span><span>●●● ▮</span></div>
  <div class="scroll"><div class="apphead"><div><h2>الورد اليومي</h2><span class="dt">الاثنين 9 نوفمبر</span></div><div class="ic" role="button" aria-label="الإعدادات">${GEAR}</div></div>
  ${card(S,'far')}${card(S,'near')}${card(S,'new')}</div>${overlay(S,ui)}`;
}

/* ── ورقة الإضافة (7.2) ── */
function chip(S,h,t,ui,mode){
  const at=trackOf(S,h),sel=ui.sel.has(h);
  if(mode!=='add'&&at!==t)return '<div class="hc blank"></div>';
  let cls='hc',sub=firstSura(h),st='';
  if(mode==='add'&&at===t){cls+=' here';sub='في هذا المسار';}
  else if(mode==='add'&&at){cls+=' other';sub=`<i></i>في ${SHORT[at]}`;st=` style="--c:var(--${at})"`;}
  if(sel)cls+=' sel';
  return `<div class="${cls}"${st} data-hc="${h}" role="button" aria-pressed="${sel}"><b>ح ${N(h)}</b><span>${sub}</span></div>`;
}
const pickable=(S,h,t,mode)=>mode==='add'?trackOf(S,h)!==t:trackOf(S,h)===t;
function jrows(S,t,ui,mode){
  let h='';
  for(let j=1;j<=30;j++){
    const hs=[2*j-1,2*j];
    if(mode!=='add'&&!hs.some(x=>trackOf(S,x)===t))continue;
    const can=hs.filter(x=>pickable(S,x,t,mode)),all=can.length&&can.every(x=>ui.sel.has(x));
    h+=`<div class="jrow" data-j="${j}"><button class="jbtn ${can.length?'':'off'}" data-jb="${j}"><span class="ck ${all?'on':''}"></span>الجزء ${N(j)}</button>${chip(S,hs[0],t,ui,mode)}${chip(S,hs[1],t,ui,mode)}</div>`;
  }
  return h;
}
function addSheet(S,ui){
  const t=ui.t,sel=[...ui.sel].sort((a,b)=>a-b);
  const seg=['far','near'].map(x=>`<button class="${x===t?'on':''}" data-seg="${x}" style="--c:var(--${x})"><span class="mk"></span>${TT[x]}</button>`).join('');
  const lbl=sel.length?`أضف ${hizbs(sel)} إلى ${TT[t]}`:'اختر جزءاً أو حزباً';
  return `<div class="dim" data-close></div><div class="sheet tall" role="dialog"><div class="shd"><div class="grab"></div>
    <div class="ttl"><h4>إضافة محفوظ</h4><button class="lnk" data-close>إلغاء</button></div>
    <div class="seg">${seg}</div>
    <p class="why">اختر الجزء كلّه بدائرته، أو حزباً منه.</p></div>
    <div class="jlist">${jrows(S,t,ui,'add')}</div>
    <div class="sbar"><button class="btn pri" data-go ${sel.length?'':'disabled'}>${lbl}</button></div></div>`;
}
/* ── ورقة النقل أو الإزالة من قائمة المسار ── */
function manageSheet(S,ui){
  const t=ui.t,o=OTHER[t],sel=[...ui.sel].sort((a,b)=>a-b),mv=ui.mode==='move';
  const ttl=mv?`نقل من ${TT[t]}`:`إزالة من ${TT[t]}`;
  const dest=mv?`<div class="dest" style="--c:var(--${o})"><span>إلى</span><i class="mk"></i><b>${TT[o]}</b></div>`:'<p class="why">يبقى سجلّ تلاوة ما تزيله محفوظاً.</p>';
  const lbl=sel.length?(mv?`انقل ${hizbs(sel)} إلى ${TT[o]}`:`أزل ${hizbs(sel)}`):'اختر حزباً أو أكثر';
  return `<div class="dim" data-close></div><div class="sheet tall" role="dialog"><div class="shd"><div class="grab"></div>
    <div class="ttl"><h4>${ttl}</h4><button class="lnk" data-close>إلغاء</button></div>${dest}</div>
    <div class="jlist">${jrows(S,t,ui,ui.mode)}</div>
    <div class="sbar"><button class="btn pri" data-go ${sel.length?'':'disabled'}>${lbl}</button></div></div>`;
}
/* ── سؤال النقل (5.1): «الحزب موجود في [المسار]. أتنقله؟» ── */
function conflictDlg(S,ui){
  const c=ui.conf,from=trackOf(S,c[0]),one=c.length===1;
  const q=one?`الحزب ${N(c[0])} موجود في ${TT[from]}. أتنقله؟`:`${hizbsSubj(c)} موجود${c.length===2?'ان':'ة'} في ${TT[from]}. أتنقل${c.length===2?'هما':'ها'}؟`;
  const rest=ui.sel.size-c.length;
  return `<div class="dim top"></div><div class="dlg" role="alertdialog"><h4>${q}</h4>
    <p>سجلّ تلاوت${P(c.length)} ينتقل مع${P(c.length)} كما هو.${rest?` ويُضاف ما سوا${P(c.length)} في الحالين.`:''}</p>
    <button class="btn pri" data-conf="move">انقل${one?'ه':c.length===2?'هما':'ها'} إلى ${TT[ui.t]}</button>
    <button class="btn quiet" data-conf="keep">اترك${one?'ه':c.length===2?'هما':'ها'} في ${TT[from]}</button></div>`;
}
/* ── تأكيد الإزالة (5.1) ── */
function removeDlg(S,ui){
  const sel=[...ui.sel].sort((a,b)=>a-b),one=sel.length===1;
  return `<div class="dim top"></div><div class="dlg" role="alertdialog"><h4>أتزيل ${one?`الحزب ${N(sel[0])}`:sel.length===2?`الحزبين ${N(sel[0])} و${N(sel[1])}`:hizbs(sel)} من ${TT[ui.t]}؟</h4>
    <p>يبقى سجلّ تلاوت${P(sel.length)} محفوظاً، فإن أعدت${P(sel.length)} ظهر عمر${P(sel.length)} كما كان.</p>
    <button class="btn pri" data-rm="yes">أزل${P(sel.length)}</button><button class="btn quiet" data-rm="no">إلغاء</button></div>`;
}
/* ── القوائم ── */
function trackMenu(S,ui){
  const has=S[ui.t].length; /* م21: لا نقل ولا إزالة في مسار فارغ */
  return `<div class="dim" data-close style="background:transparent"></div><div class="menu" data-anchor="more" role="menu">
    <div class="mi" data-tm="add"><span>إضافة</span>${ADD}</div>
    ${has?`<div class="mi" data-tm="move"><span>نقل</span>${MOVE}</div>
    <div class="mi" data-tm="remove"><span>إزالة</span>${TRASH}</div>`:''}</div>`;
}
function hizbMenu(ui){
  const h=ui.h,o=OTHER[ui.t];
  return `<div class="dim" data-close></div><div class="menu" data-anchor="row" role="menu"><div class="mh">ح ${N(h)} · ${firstSura(h)} · الجزء ${N(Math.ceil(h/2))}</div>
    <div class="mi" data-hm="move"><span>نقل إلى ${TT[o]}</span>${MOVE}</div>
    <div class="gap6"></div>
    <div class="mi" data-hm="remove"><span>إزالة من المسار</span>${TRASH}</div></div>`;
}
function overlay(S,ui){
  const toast=ui.toast?`<div class="toast" role="status">${ui.toast}</div>`:'';
  switch(ui.ov){
    case 'add':return addSheet(S,ui);
    case 'conf':return addSheet(S,ui)+conflictDlg(S,ui);
    case 'manage':return manageSheet(S,ui);
    case 'rdlg':return (ui.from==='manage'?manageSheet(S,ui):'')+removeDlg(S,ui);
    case 'tmenu':return trackMenu(S,ui);
    case 'hmenu':return hizbMenu(ui);
  }
  return toast;
}
/* تموضع القائمة بجانب ما فُتحت منه (القياس مستقلّ عن تصغير الهاتف في الصفحة) */
function place(scr,ui){
  const m=scr.querySelector('.menu');if(!m)return;
  const sr=scr.getBoundingClientRect(),k=sr.width/scr.offsetWidth;
  if(ui.ov==='tmenu'){const a=scr.querySelector(`.track[data-track="${ui.t}"] .more`).getBoundingClientRect();
    m.style.top=((a.bottom-sr.top)/k+2)+'px';m.style.left=Math.max(12,(a.left-sr.left)/k+4)+'px';}
  else{const l=scr.querySelector(`.track[data-track="${ui.t}"] .lbl[data-h="${ui.h}"]`),row=l.closest('.row');row.classList.add('lift');
    const a=row.getBoundingClientRect();let top=(a.bottom-sr.top)/k+8;
    if(top+m.offsetHeight>scr.offsetHeight-24)top=(a.top-sr.top)/k-m.offsetHeight-8;
    m.style.top=top+'px';m.style.right=Math.max(12,(sr.right-a.right)/k-6)+'px';}
}

/* ── العمليات (منطق العرض وحده، لا قواعد البيانات) ── */
const sortT=(S,t)=>S[t].sort((a,b)=>a-b);
function addTo(S,t,list){list.forEach(h=>{const at=trackOf(S,h);if(at&&at!==t)S[at]=S[at].filter(x=>x!==h);if(!S[t].includes(h))S[t].push(h);});sortT(S,t);}
function removeFrom(S,t,list){S[t]=S[t].filter(h=>!list.includes(h));if(S.open===t&&!S[t].length)S.open=null;}

/* ── هاتف تفاعلي ── */
function interactive(scr,S,ui0){
  let ui=Object.assign({ov:null,sel:new Set()},ui0||{}),tm;
  const render=(keep)=>{const y=scr.querySelector('.scroll')?.scrollTop||0,jy=scr.querySelector('.jlist')?.scrollTop||0;
    scr.innerHTML=screen(S,ui);W.sizeFold(scr);if(keep!==false){scr.querySelector('.scroll').scrollTop=y;const jl=scr.querySelector('.jlist');if(jl)jl.scrollTop=jy;}place(scr,ui);wire();};
  const toast=t=>{ui={ov:null,sel:new Set(),toast:t};render();clearTimeout(tm);tm=setTimeout(()=>{ui.toast=null;render();},2600);};
  function wire(){
    const $=(q,f)=>scr.querySelectorAll(q).forEach(e=>e.onclick=ev=>{ev.stopPropagation();f(e,ev);});
    $('[data-toggle]',e=>{const t=e.dataset.toggle;S.open=S.open===t?null:t;ui={ov:null,sel:new Set()};render(false);if(S.open)W.scrollToBm(scr,S.open);});
    $('[data-add]',e=>{ui={ov:'add',t:e.dataset.add,sel:new Set()};render();});
    $('[data-close]',()=>{ui={ov:null,sel:new Set()};render();});
    $('[data-seg]',e=>{ui.t=e.dataset.seg;ui.sel=new Set();render();});
    const mode=ui.ov==='add'?'add':ui.mode;
    $('.hc[data-hc]',e=>{const h=+e.dataset.hc;if(!pickable(S,h,ui.t,mode))return;ui.sel.has(h)?ui.sel.delete(h):ui.sel.add(h);render();});
    $('[data-jb]',e=>{const j=+e.dataset.jb,can=[2*j-1,2*j].filter(x=>pickable(S,x,ui.t,mode));if(!can.length)return;
      const all=can.every(x=>ui.sel.has(x));can.forEach(x=>all?ui.sel.delete(x):ui.sel.add(x));render();});
    $('[data-go]',()=>{const sel=[...ui.sel].sort((a,b)=>a-b);if(!sel.length)return;
      if(ui.ov==='add'){const c=sel.filter(h=>trackOf(S,h)&&trackOf(S,h)!==ui.t);
        if(c.length){ui.ov='conf';ui.conf=c;render();return;}
        addTo(S,ui.t,sel);toast(`أُضيف ${hizbsNom(sel)} إلى ${TT[ui.t]}`);}
      else if(ui.mode==='move'){const o=OTHER[ui.t];addTo(S,o,sel);if(!S[ui.t].length&&S.open===ui.t)S.open=null;toast(`نُقل ${hizbsNom(sel)} إلى ${TT[o]}`);}
      else{ui.ov='rdlg';ui.from='manage';render();}});
    $('[data-conf]',e=>{const sel=[...ui.sel].sort((a,b)=>a-b),list=e.dataset.conf==='move'?sel:sel.filter(h=>!ui.conf.includes(h));
      if(list.length)addTo(S,ui.t,list);
      toast(list.length?`أُضيف ${hizbsNom(list)} إلى ${TT[ui.t]}`:'لم يُضف شيء');});
    $('[data-rm]',e=>{if(e.dataset.rm==='no'){ui={ov:null,sel:new Set()};render();return;}
      const sel=[...ui.sel];removeFrom(S,ui.t,sel);toast(`أُزيل ${hizbsNom(sel)} · سجلّ${P(sel.length)} محفوظ`);});
    $('[data-more]',e=>{ui={ov:'tmenu',t:e.dataset.more,sel:new Set()};render();});
    $('[data-tm]',e=>{const a=e.dataset.tm,t=ui.t;ui=a==='add'?{ov:'add',t,sel:new Set()}:{ov:'manage',mode:a,t,sel:new Set()};render();});
    $('[data-hm]',e=>{const a=e.dataset.hm;
      if(a==='move'){const o=OTHER[ui.t];addTo(S,o,[ui.h]);if(!S[ui.t].length&&S.open===ui.t)S.open=null;toast(`نُقل ح ${N(ui.h)} إلى ${TT[o]}`);}
      else{ui={ov:'rdlg',t:ui.t,sel:new Set([ui.h])};render();}});
    /* الضغط المطوّل على «ح [رقم]» يفتح قائمة الحزب */
    scr.querySelectorAll('.lbl[data-h]').forEach(l=>{let lp;
      const open=()=>{ui={ov:'hmenu',t:l.dataset.t,h:+l.dataset.h,sel:new Set()};render();};
      l.onpointerdown=()=>{lp=setTimeout(open,450);};l.onpointerup=l.onpointerleave=()=>clearTimeout(lp);
      l.oncontextmenu=ev=>{ev.preventDefault();clearTimeout(lp);open();};});
  }
  render();
}
/* رسم ثابت لحالة واحدة (للصفحة واللقطات) */
function still(scr,S,ui,after){scr.innerHTML=screen(S,Object.assign({ov:null,sel:new Set()},ui||{}));W.sizeFold(scr);
  setTimeout(()=>{if(after)after(scr);place(scr,Object.assign({sel:new Set()},ui||{}));},40);}
function st(o){const S=W.state(Object.assign({far:[],near:[],newHizb:null,ages:()=>{}},o));S.noStamp=true;return S;}
window.S1={screen,interactive,still,st,TT};
})();
