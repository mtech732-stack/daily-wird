/* ش4 · المحفوظ الجديد · محرّك الصفحة المرجعية design/s4.html
   يبني على محرّك ش3 (التظليل والعمر والدورة وموضع التوقّف) ويضيف المحفوظ الجديد (5.6):
   اختيار الحزب الذي يُحفظ الآن، وأوجهه مربّعات مرقّمة بأرقام المصحف، وإتمام الوجه والتراجع،
   وموضع التوقّف أول وجه لم يتمّ، والوجه المشترك بين حزبين، وتنبيه اكتمال الحزب والرفع إلى القريب،
   والنقل بين المسارات الثلاثة (5.2).
   هذا منطق عرض للصفحة وحدها، لا قواعد البيانات. المرجع المكتوب: design/system.md §15. */
(function(){
const W=window.WIRD,S2=window.S2,S3=window.S3,{R,SN,N,TT,BM,quartersOf}=W;
const CLOCK='<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>';
const PLUS='<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg>';
const ADD='<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"><circle cx="12" cy="12" r="8.5"/><path d="M12 8v8M8 12h8"/></svg>';
const MOVE='<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M4 8h13l-3.5-3.5M20 16H7l3.5 3.5"/></svg>';
const TRASH='<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M4 7h16M9 7V4.5h6V7M6.5 7l1 12.5h9l1-12.5M10 11v5M14 11v5"/></svg>';
/* الرفع إلى القريب: سهم صاعد (SF Symbol: arrow.up) */
const UP='<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.1" stroke-linecap="round" stroke-linejoin="round"><path d="M12 19V5M6 11l6-6 6 6"/></svg>';
/* صحّ حوار الاكتمال، بلون `onNew` على البرتقالي (ت10) */
const CHECK='<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>';
const SHORT={far:'البعيد',near:'القريب',new:'الجديد'};
/* وجهات النقل من كل مسار، بترتيبها في القائمة: الأقرب في طريق المالك أولاً (الجديد ← القريب ← البعيد) */
const DEST={far:['near','new'],near:['far','new'],new:['near','far']};
const TIMES=['5:08 ص','4:52 ص','5:34 ص','5:21 ص','9:40 م','5:15 ص','4:47 ص'];
const mins=t=>{const[h,m]=t.split(' ')[0].split(':').map(Number);return (h%12)*60+m+(t.endsWith('م')?720:0);};

/* ── الأوجه من الجدول ── */
const pagesOf=h=>{const a=R[(h-1)*4+1].firstPage,b=R[h*4].lastPage,o=[];for(let p=a;p<=b;p++)o.push(p);return o;};
/* الوجه المشترك: أوّل وجه في الحزب وهو آخر وجه في الذي قبله، أو آخره وهو أول وجه في الذي بعده (5.6) */
const otherHizb=(h,p)=>h>1&&p===R[(h-1)*4+1].firstPage&&R[(h-1)*4].lastPage===p?h-1:h<60&&p===R[h*4].lastPage&&R[h*4+1].firstPage===p?h+1:null;
const juzOf=h=>Math.ceil(h/2);
const firstSura=h=>SN[R[(h-1)*4+1].suras[0]];
/* سور الحزب: واحدة أو اثنتان بأسمائهما، وأكثر «أولها ← آخرها» (كما في م19) */
const suraTxt=h=>{const s=[...new Set(quartersOf(h).flatMap(r=>R[r].suras))];return s.length>2?`${SN[s[0]]} ← ${SN[s[s.length-1]]}`:s.map(x=>SN[x]).join(' · ');};

/* العدد مع المعدود (م20) */
const hizbs=l=>l.length===1?`الحزب ${N(l[0])}`:l.length===2?'حزبين':l.length<=10?`${N(l.length)} أحزاب`:`${N(l.length)} حزباً`;
const hizbsNom=l=>l.length===1?`ح ${N(l[0])}`:l.length===2?'حزبان':l.length<=10?`${N(l.length)} أحزاب`:`${N(l.length)} حزباً`;
const hizbsSubj=l=>l.length===1?`الحزب ${N(l[0])}`:l.length===2?`الحزبان ${N(l[0])} و${N(l[1])}`:`${N(l.length)} أحزاب`;
const P=n=>n===1?'ه':n===2?'هما':'ها';

/* ── الحالة: S.nw أحزاب المحفوظ الجديد، وS.pg إتمام كل وجه {d: قبل كم يوماً, t: الوقت} ── */
function make(o){
  const S=S3.make(Object.assign({},o,{newHizb:null}));
  S.nw=(o.nw||[]).slice().sort((a,b)=>a-b);S.pg={};
  Object.entries(o.pg||{}).forEach(([p,d],i)=>S.pg[p]={d,t:d===0?'4:58 ص':TIMES[i%TIMES.length]});
  return S;
}
const trackOf=(S,h)=>S.far.includes(h)?'far':S.near.includes(h)?'near':S.nw.includes(h)?'new':null;
const isDone=(S,p)=>!!S.pg[p];
const hzDone=(S,h)=>pagesOf(h).every(p=>isDone(S,p));
const allPages=S=>[...new Set(S.nw.flatMap(pagesOf))].sort((a,b)=>a-b);
/* موضع التوقّف في الجديد (5.6): أول وجه لم يتمّ، في أول حزب (بترتيب الأحزاب) بقي فيه وجه */
function bmOf(S){for(const h of S.nw){const p=pagesOf(h).find(p=>!isDone(S,p));if(p)return {h,p};}return null;}
function lastNew(S){let b=null;allPages(S).forEach(p=>{const e=S.pg[p];if(e&&(!b||e.d<b.d||(e.d===b.d&&mins(e.t)>mins(b.t))))b=e;});return b;}
/* الضغطة على الوجه: أتممته اليوم، أو تراجع إن أُتمّ اليوم. وما أُتمّ قبل اليوم لا تغيّره الضغطة (ذ29) */
function tapPage(S,p,now='5:12 ص'){
  const e=S.pg[p];
  if(e&&e.d===0){delete S.pg[p];return {kind:'undo'};}
  if(e)return {kind:'old',e};
  S.pg[p]={d:0,t:now};
  return {kind:'done',complete:S.nw.filter(h=>pagesOf(h).includes(p)&&hzDone(S,h))};
}
const resync=S=>S3.advance(S,0);
function removeFrom(S,t,list){if(t==='new')S.nw=S.nw.filter(h=>!list.includes(h));else S[t]=S[t].filter(h=>!list.includes(h));if(S.open===t&&!(t==='new'?S.nw:S[t]).length)S.open=null;resync(S);}
function moveTo(S,to,list){list.forEach(h=>{const at=trackOf(S,h);if(at&&at!==to)removeFrom(S,at,[h]);
  if(to==='new'){if(!S.nw.includes(h))S.nw.push(h);S.nw.sort((a,b)=>a-b);}else S3.add(S,to,h);});resync(S);}
/* الرفع إلى القريب (5.2 · 5.6): ينتقل الحزب بأرباعه غير مظلّلة، ويبقى سجلّ أوجهه */
function raise(S,h){const before=W.bookmark(S,'near');moveTo(S,'near',[h]);const after=W.bookmark(S,'near');
  return after&&after!==before&&R[after].hizb===h;}
function advance(S,n){S3.advance(S,n);Object.values(S.pg).forEach(e=>e.d+=n);}

/* ── البطاقة ── */
function stampNew(S){const e=lastNew(S);
  if(!e)return `<div class="stamp blank" aria-hidden="true">${CLOCK}<b>&nbsp;</b></div>`; // مكانه محجوز قبل أول إتمام (ذ17)
  return `<div class="stamp" data-stamp="new">${CLOCK}<b>آخر إدخال ${S2.rel(e.d)}</b><span class="sd">${S2.dLong(e.d,S)} · ${e.t}</span></div>`;}
function emptyNew(){
  return `<div class="track empty" style="--c:var(--new)" data-track="new"><div class="th"><span class="mk"></span><h3>${TT.new}</h3><span class="more" data-more="new" role="button" aria-label="قائمة المسار">⋯</span></div>
    <div class="emp"><p>لم تحدّد بعدُ الحزب الذي تحفظه.</p><button class="btn add" data-pick>${PLUS}اختر الحزب الذي تحفظه</button></div></div>`;
}
function pbox(S,h,p,bm){
  const e=S.pg[p],o=otherHizb(h,p),cls=['q','t-new',e?'L1':'L5'];
  if(e&&e.d===0)cls.push('today');if(bm&&bm.p===p)cls.push('bm');
  const al=`الوجه ${p}، ${e?'محفوظ':'لم يُحفظ'}${e&&e.d===0?'، أتممته اليوم':''}${bm&&bm.p===p?'، موضع التوقّف':''}${o?`، مشترك مع الحزب ${o}`:''}`;
  return `<div class="${cls.join(' ')}" data-p="${p}" data-h="${h}" role="button" aria-label="${al}">${o?'<i class="cut"></i>':''}<span class="n">${N(p)}</span></div>`;
}
const raiseBtn=h=>`<button class="btn raise" data-raise="${h}">${UP}ارفع ح ${N(h)} إلى ${TT.near}</button>`;
function block(S,h,list,bm,noBm){
  const mark=!noBm&&bm&&bm.h===h;
  return `<div class="nh" data-nh="${h}"><div class="nsub"><span class="lbl" data-h="${h}" data-t="new">${mark?BM:''}ح ${N(h)}</span><span class="ns">· ${suraTxt(h)} · الجزء ${N(juzOf(h))}</span></div>
    <div class="pages">${list.map(p=>pbox(S,h,p,noBm?null:bm)).join('')}</div>${hzDone(S,h)?raiseBtn(h):''}</div>`;
}
/* الصفّ المطويّ: صفّ الأوجه الخمسة الذي فيه موضع التوقّف (7.1)، كما في النماذج المعتمدة */
function foldStart(list,idx){return Math.max(0,Math.min(Math.floor(idx/5)*5,list.length-5));}
function foldView(S){
  const bm=bmOf(S);
  if(S.pinNew)return S.pinNew;
  const h=bm?bm.h:S.nw.find(x=>hzDone(S,x)),list=pagesOf(h),idx=bm&&bm.h===h?list.indexOf(bm.p):list.length-1;
  return {h,start:foldStart(list,idx)};
}
function newCard(S){
  if(!S.nw.length)return emptyNew();
  const bm=bmOf(S),all=allPages(S),done=all.filter(p=>isDone(S,p)).length,open=S.open==='new';
  let body='';
  if(open)S.nw.forEach(h=>body+=block(S,h,pagesOf(h),bm));
  else{const v=foldView(S),list=pagesOf(v.h);
    body=block(S,v.h,list.slice(v.start,v.start+5),bm,!!S.pinNew);
    /* حزب آخر اكتمل ولم يُرفع (نادر: حزبان في الجديد) يبقى زرّه ظاهراً */
    S.nw.filter(x=>x!==v.h&&hzDone(S,x)).forEach(x=>body+=raiseBtn(x));}
  return stampNew(S)+`<div class="track ${open?'open':''}" style="--c:var(--new)" data-track="new">${W.head('new',`${N(done)} من ${N(all.length)}`)}
  <div class="cur ncur">${body}</div>${W.pull('new',open,'عرض كل أوجه الحزب')}</div>`;
}

/* ── الأوراق والقوائم والحوارات ── */
function chip(S,h,t,ui,mode){
  const at=trackOf(S,h),sel=ui.sel.has(h);
  if(mode!=='add'&&at!==t)return '<div class="hc blank"></div>';
  let cls='hc',sub=firstSura(h),st='';
  if(mode==='add'&&at===t){cls+=' here';sub=t==='new'?'تحفظه الآن':'في هذا المسار';}
  else if(mode==='add'&&at){cls+=' other';sub=`<i></i>في ${SHORT[at]}`;st=` style="--c:var(--${at})"`;}
  if(sel)cls+=' sel';
  return `<div class="${cls}"${st} data-hc="${h}" role="button" aria-pressed="${sel}"><b>ح ${N(h)}</b><span>${sub}</span></div>`;
}
const pickable=(S,h,t,mode)=>mode==='add'?trackOf(S,h)!==t:trackOf(S,h)===t;
function jrows(S,t,ui,mode){
  let o='';
  for(let j=1;j<=30;j++){const hs=[2*j-1,2*j];
    if(mode!=='add'&&!hs.some(x=>trackOf(S,x)===t))continue;
    const can=hs.filter(x=>pickable(S,x,t,mode)),all=can.length&&can.every(x=>ui.sel.has(x));
    /* في اختيار الحزب الذي يُحفظ لا دائرة للجزء: حزب واحد في وقت واحد (القرار 5) */
    const jb=t==='new'&&mode==='add'?`<span class="jbtn jl">الجزء ${N(j)}</span>`:`<button class="jbtn ${can.length?'':'off'}" data-jb="${j}"><span class="ck ${all?'on':''}"></span>الجزء ${N(j)}</button>`;
    o+=`<div class="jrow" data-j="${j}">${jb}${chip(S,hs[0],t,ui,mode)}${chip(S,hs[1],t,ui,mode)}</div>`;}
  return o;
}
function addSheet(S,ui){
  const t=ui.t,sel=[...ui.sel].sort((a,b)=>a-b),nw=t==='new';
  const lbl=sel.length?`أضف ${hizbs(sel)} إلى ${TT[t]}`:nw?'اختر حزباً':'اختر جزءاً أو حزباً';
  const hd=nw?`<div class="ttl"><h4>الحزب الذي تحفظه</h4><button class="lnk" data-close>إلغاء</button></div>
      <div class="dest" style="--c:var(--new)"><i class="mk"></i><b>${TT.new}</b></div>
      <p class="why">اختر الحزب الذي تحفظ فيه الآن، فتظهر أوجهه في البطاقة.</p>`
    :`<div class="ttl"><h4>إضافة محفوظ</h4><button class="lnk" data-close>إلغاء</button></div>
      <div class="seg">${['far','near'].map(x=>`<button class="${x===t?'on':''}" data-seg="${x}" style="--c:var(--${x})"><span class="mk"></span>${TT[x]}</button>`).join('')}</div>
      <p class="why">اختر الجزء كلّه بدائرته، أو حزباً منه.</p>`;
  return `<div class="dim" data-close></div><div class="sheet tall${nw?' pick':''}" role="dialog"><div class="shd"><div class="grab"></div>${hd}</div>
    <div class="jlist">${jrows(S,t,ui,'add')}</div>
    <div class="sbar"><button class="btn pri" data-go ${sel.length?'':'disabled'}>${lbl}</button></div></div>`;
}
/* ورقة النقل من «⋯»: الوجهة مقطعان بالمسارين الآخرين (ذ32) */
function manageSheet(S,ui){
  const t=ui.t,sel=[...ui.sel].sort((a,b)=>a-b),mv=ui.mode==='move',to=ui.to||DEST[t][0];
  const dest=mv?`<div class="seg dest2"><span class="to">إلى</span>${DEST[t].map(x=>`<button class="${x===to?'on':''}" data-to="${x}" style="--c:var(--${x})"><span class="mk"></span>${TT[x]}</button>`).join('')}</div>`
    :`<p class="why">${t==='new'?'يبقى سجلّ حفظ ما تزيله محفوظاً.':'يبقى سجلّ تلاوة ما تزيله محفوظاً.'}</p>`;
  const lbl=sel.length?(mv?`انقل ${hizbs(sel)} إلى ${TT[to]}`:`أزل ${hizbs(sel)}`):'اختر حزباً أو أكثر';
  return `<div class="dim" data-close></div><div class="sheet tall" role="dialog"><div class="shd"><div class="grab"></div>
    <div class="ttl"><h4>${mv?'نقل من':'إزالة من'} ${TT[t]}</h4><button class="lnk" data-close>إلغاء</button></div>${dest}</div>
    <div class="jlist">${jrows(S,t,ui,ui.mode)}</div>
    <div class="sbar"><button class="btn pri" data-go ${sel.length?'':'disabled'}>${lbl}</button></div></div>`;
}
/* سؤال النقل (5.1) عند الإضافة، وأحدها في مسار آخر */
function conflictDlg(S,ui){
  const c=ui.conf,from=trackOf(S,c[0]),n=c.length,rest=ui.sel.size-n;
  const q=n===1?`الحزب ${N(c[0])} موجود في ${TT[from]}. أتنقله؟`:`${hizbsSubj(c)} موجود${n===2?'ان':'ة'} في ${TT[from]}. أتنقل${P(n)}؟`;
  const rec=from==='new'?`سجلّ حفظ${P(n)} يبقى كما هو.`:`سجلّ تلاوت${P(n)} ينتقل مع${P(n)} كما هو.`;
  return `<div class="dim top"></div><div class="dlg" role="alertdialog"><h4>${q}</h4>
    <p>${rec}${rest?` ويُضاف ما سوا${P(n)} في الحالين.`:''}</p>
    <button class="btn pri" data-conf="move">انقل${P(n)} إلى ${TT[ui.t]}</button>
    <button class="btn quiet" data-conf="keep">اترك${P(n)} في ${TT[from]}</button></div>`;
}
function removeDlg(S,ui){
  const sel=[...ui.sel].sort((a,b)=>a-b),n=sel.length,who=n===1?`الحزب ${N(sel[0])}`:n===2?`الحزبين ${N(sel[0])} و${N(sel[1])}`:hizbs(sel);
  const p=ui.t==='new'?`يبقى سجلّ حفظ${P(n)} محفوظاً، فإن أعدت${P(n)} ظهرت أوجه${P(n)} كما كانت.`:`يبقى سجلّ تلاوت${P(n)} محفوظاً، فإن أعدت${P(n)} ظهر عمر${P(n)} كما كان.`;
  return `<div class="dim top"></div><div class="dlg" role="alertdialog"><h4>أتزيل ${who} من ${TT[ui.t]}؟</h4><p>${p}</p>
    <button class="btn pri" data-rm="yes">أزل${P(n)}</button><button class="btn quiet" data-rm="no">إلغاء</button></div>`;
}
/* تنبيه اكتمال الحزب (5.6 · 5.2)، كما في النموذج المعتمد 6 */
function doneDlg(S,ui){
  const h=ui.h,l=pagesOf(h);
  return `<div class="dim top"></div><div class="dlg done" role="alertdialog"><div class="big" aria-hidden="true">${CHECK}</div><h4>اكتمل الحزب ${N(h)}</h4>
    <p>أتممت أوجهه كلها، من ${N(l[0])} إلى ${N(l[l.length-1])}.<br>أترفعه إلى ${TT.near}؟</p>
    <button class="btn pri" data-up="${h}">ارفعه إلى ${TT.near}</button><button class="btn quiet" data-later>لاحقاً</button></div>`;
}
function trackMenu(S,ui){
  const t=ui.t,has=t==='new'?S.nw.length:S[t].length;
  const restart=t==='new'||!has?'':`<div class="gap6"></div><div class="mi${S.cyc[t].size?'':' off'}"><span>ابدأ دورة جديدة</span><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M4.5 12a7.5 7.5 0 1 0 2.2-5.3"/><path d="M4.5 3.8v4h4"/></svg></div>`;
  return `<div class="dim" data-close style="background:transparent"></div><div class="menu" role="menu">
    <div class="mi" data-tm="add"><span>إضافة</span>${ADD}</div>
    ${has?`<div class="mi" data-tm="move"><span>نقل</span>${MOVE}</div><div class="mi" data-tm="remove"><span>إزالة</span>${TRASH}</div>`:''}${restart}</div>`;
}
/* قائمة الحزب (7.1.1 · 5.2): «نقل إلى …» لكل مسار آخر، ثم الإزالة */
function hizbMenu(S,ui){
  const h=ui.h;
  return `<div class="dim" data-close></div><div class="menu" role="menu"><div class="mh">ح ${N(h)} · ${firstSura(h)} · الجزء ${N(juzOf(h))}</div>
    ${DEST[ui.t].map(x=>`<div class="mi" data-hm="${x}"><span>نقل إلى ${TT[x]}</span>${MOVE}</div>`).join('')}
    <div class="gap6"></div><div class="mi" data-hm="remove"><span>إزالة من المسار</span>${TRASH}</div></div>`;
}
function overlay(S,ui){
  const toast=ui.toast?`<div class="toast" role="status">${ui.toast}</div>`:'';
  switch(ui.ov){
    case 'add':return addSheet(S,ui);
    case 'conf':return addSheet(S,ui)+conflictDlg(S,ui);
    case 'manage':return manageSheet(S,ui);
    case 'rdlg':return (ui.from==='manage'?manageSheet(S,ui):'')+removeDlg(S,ui);
    case 'tmenu':return trackMenu(S,ui);
    case 'hmenu':return hizbMenu(S,ui);
    case 'done':return doneDlg(S,ui);
  }
  return toast;
}
/* مفاتيح الرموز: «بين حزبين» في مجموعة المحفوظ الجديد (ذ31) */
function keysNew(scr){
  const row=[...scr.querySelectorAll('.keys .krow')].pop();if(!row||row.dataset.s4)return;row.dataset.s4=1;
  const blank=row.querySelector(':scope>div:not(.key)');if(!blank)return;
  blank.outerHTML=`<div class="key"><div class="q L5 t-new" style="--cb:var(--card)"><i class="cut"></i><span class="n">3</span></div><span>بين حزبين</span></div>`;
}
function place(scr,ui){
  const m=scr.querySelector('.menu');if(!m)return;
  const sr=scr.getBoundingClientRect(),k=sr.width/scr.offsetWidth;
  if(ui.ov==='tmenu'){const a=scr.querySelector(`.track[data-track="${ui.t}"] .more`).getBoundingClientRect();
    m.style.top=((a.bottom-sr.top)/k+2)+'px';m.style.left=Math.max(12,(a.left-sr.left)/k+4)+'px';return;}
  const l=scr.querySelector(`.track[data-track="${ui.t}"] .lbl[data-h="${ui.h}"]`),row=l.closest('.row')||l.closest('.nh');row.classList.add('lift');
  const a=row.getBoundingClientRect();let top=(a.bottom-sr.top)/k+8;
  if(top+m.offsetHeight>scr.offsetHeight-24)top=(a.top-sr.top)/k-m.offsetHeight-8;
  m.style.top=top+'px';m.style.right=Math.max(12,(sr.right-a.right)/k-6)+'px';
}
function paint(scr,S,ui={}){
  const ui3=ui.ov==='qd'?{ov:'qd',r:ui.r,t:ui.t,shared:ui.shared}:{};
  scr.innerHTML=S3.screen(S,ui3);
  const old=scr.querySelector('.track[data-track="new"]');
  old.insertAdjacentHTML('beforebegin',newCard(S));old.remove();
  S3.decorate(scr,S);keysNew(scr);S2.sizeFold(scr);
  if(ui.ov!=='qd')scr.insertAdjacentHTML('beforeend',overlay(S,ui));
  place(scr,ui);
}
const toRowJ=(scr,j)=>{const jl=scr.querySelector('.jlist'),r=scr.querySelector(`.jrow[data-j="${j}"]`);if(jl&&r)jl.scrollTop=r.offsetTop-jl.offsetTop-8;};

/* ── هاتف تفاعلي ── */
function interactive(scr,S,o={}){
  let ui={sel:new Set()},tm,pt;
  const U=(x={})=>Object.assign({sel:new Set()},x);
  const render=(keep=true)=>{const y=scr.querySelector('.scroll')?.scrollTop||0,jy=scr.querySelector('.jlist')?.scrollTop||0;paint(scr,S,ui);
    if(keep){scr.querySelector('.scroll').scrollTop=y;const jl=scr.querySelector('.jlist');if(jl)jl.scrollTop=jy;}wire();o.onRender&&o.onRender(S);};
  const toast=m=>{ui=U({toast:m});render();clearTimeout(tm);tm=setTimeout(()=>{ui=U();render();},2500);};
  function onPage(p){
    const v=S.open?null:foldView(S);clearTimeout(pt);S.pinNew=null;
    const r=tapPage(S,p);
    if(r.kind==='old'){toast(`أتممت الوجه ${N(p)} ${S2.dLong(r.e.d,S)}`);return;}
    if(r.kind==='done'&&r.complete.length){ui=U();render();pt=setTimeout(()=>{ui=U({ov:'done',h:r.complete[0]});render();},450);return;}
    /* إن انتقل موضع التوقّف إلى صفّ آخر بقي الصفّ 0.8 ث ثم تلاشى إلى الجديد (ذ20 · ذ30) */
    const nv=S.open?null:foldView(S);
    if(v&&nv&&(nv.h!==v.h||nv.start!==v.start)&&r.kind==='done'){S.pinNew=v;ui=U();render();pt=setTimeout(()=>{S.pinNew=null;render();scr.querySelector('.track[data-track="new"] .cur')?.classList.add('swap');},800);}
    else{ui=U();render();}
  }
  function wire(){
    const $=(q,f)=>scr.querySelectorAll(q).forEach(e=>e.onclick=ev=>{ev.stopPropagation();f(e,ev);});
    $('[data-toggle]',e=>{const t=e.dataset.toggle;S.open=S.open===t?null:t;S.pinNew=null;ui=U();render(false);if(S.open&&S.open!=='new')S3.toBookmark(scr,S.open);});
    $('[data-pick]',()=>{ui=U({ov:'add',t:'new'});render();});
    $('[data-add]',e=>{ui=U({ov:'add',t:e.dataset.add});render();});
    $('[data-close]',()=>{ui=U();render();});
    $('[data-seg]',e=>{ui.t=e.dataset.seg;ui.sel=new Set();render();});
    $('[data-to]',e=>{ui.to=e.dataset.to;render();});
    const mode=ui.ov==='add'||ui.ov==='conf'?'add':ui.mode;
    $('.hc[data-hc]',e=>{const h=+e.dataset.hc;if(!pickable(S,h,ui.t,mode))return;ui.sel.has(h)?ui.sel.delete(h):ui.sel.add(h);render();});
    $('[data-jb]',e=>{const j=+e.dataset.jb,can=[2*j-1,2*j].filter(x=>pickable(S,x,ui.t,mode));if(!can.length)return;
      const all=can.every(x=>ui.sel.has(x));can.forEach(x=>all?ui.sel.delete(x):ui.sel.add(x));render();});
    $('[data-go]',()=>{const sel=[...ui.sel].sort((a,b)=>a-b);if(!sel.length)return;
      if(ui.ov==='add'){const c=sel.filter(h=>trackOf(S,h)&&trackOf(S,h)!==ui.t);
        if(c.length){ui.ov='conf';ui.conf=c;render();return;}
        moveTo(S,ui.t,sel);toast(`أُضيف ${hizbsNom(sel)} إلى ${TT[ui.t]}`);}
      else if(ui.mode==='move'){const to=ui.to||DEST[ui.t][0];moveTo(S,to,sel);toast(`نُقل ${hizbsNom(sel)} إلى ${TT[to]}`);}
      else{ui.ov='rdlg';ui.from='manage';render();}});
    $('[data-conf]',e=>{const sel=[...ui.sel].sort((a,b)=>a-b),list=e.dataset.conf==='move'?sel:sel.filter(h=>!ui.conf.includes(h));
      if(list.length)moveTo(S,ui.t,list);toast(list.length?`أُضيف ${hizbsNom(list)} إلى ${TT[ui.t]}`:'لم يُضف شيء');});
    $('[data-rm]',e=>{if(e.dataset.rm==='no'){ui=U();render();return;}
      const sel=[...ui.sel];removeFrom(S,ui.t,sel);toast(`أُزيل ${hizbsNom(sel)} · سجلّ${P(sel.length)} محفوظ`);});
    $('[data-more]',e=>{ui=U({ov:'tmenu',t:e.dataset.more});render();});
    $('[data-tm]',e=>{const a=e.dataset.tm,t=ui.t;ui=a==='add'?U({ov:'add',t}):U({ov:'manage',mode:a,t});render();});
    $('[data-hm]',e=>{const a=e.dataset.hm,h=ui.h,t=ui.t;
      if(a==='remove'){ui=U({ov:'rdlg',t,sel:new Set([h])});render();return;}
      if(a==='near'&&t==='new'){const bmMoved=raise(S,h);toast(`رُفع ح ${N(h)} إلى ${TT.near}${bmMoved?' · وفيه الآن موضع التوقّف':''}`);return;}
      moveTo(S,a,[h]);toast(`نُقل ح ${N(h)} إلى ${TT[a]}`);});
    const up=h=>{const bmMoved=raise(S,h);toast(`رُفع ح ${N(h)} إلى ${TT.near}${bmMoved?' · وفيه الآن موضع التوقّف':''}`);};
    $('[data-up]',e=>up(+e.dataset.up));
    $('[data-raise]',e=>up(+e.dataset.raise));
    $('[data-later]',()=>{ui=U();render();});
    $('[data-undo]',()=>{const r=ui.r,t=ui.t;ui=U();S3.tap(S,r,t);render();});
    scr.querySelectorAll('.q[data-p]').forEach(el=>el.onclick=()=>onPage(+el.dataset.p));
    scr.querySelectorAll('.q[data-r]').forEach(el=>{let lp,long=false;
      const open=()=>{long=true;ui=U({ov:'qd',r:+el.dataset.r,t:el.dataset.t,shared:!!el.querySelector('.cut')});render();};
      el.onpointerdown=()=>{long=false;lp=setTimeout(open,450);};el.onpointerleave=()=>clearTimeout(lp);
      el.onpointerup=()=>{clearTimeout(lp);if(long)return;S3.tap(S,+el.dataset.r,el.dataset.t);ui=U();render();};
      el.oncontextmenu=ev=>{ev.preventDefault();clearTimeout(lp);open();};});
    scr.querySelectorAll('.lbl[data-h]').forEach(l=>{let lp;
      const open=()=>{ui=U({ov:'hmenu',t:l.dataset.t,h:+l.dataset.h});render();};
      l.onpointerdown=()=>{lp=setTimeout(open,450);};l.onpointerup=l.onpointerleave=()=>clearTimeout(lp);
      l.oncontextmenu=ev=>{ev.preventDefault();clearTimeout(lp);open();};});
  }
  render();
  return {render,S,advance:n=>{advance(S,n);ui=U();render();}};
}
/* رسم ثابت لحالة واحدة (للصفحة واللقطات) */
function still(scr,S,ui,afterFn){const u=Object.assign({sel:new Set()},ui||{});paint(scr,S,u);
  setTimeout(()=>{if(S.open&&S.open!=='new')S3.toBookmark(scr,S.open);if(u.j)toRowJ(scr,u.j);place(scr,u);afterFn&&afterFn(scr);},40);}
window.S4={make,tapPage,raise,moveTo,removeFrom,advance,still,interactive,pagesOf,otherHizb,bmOf,foldView,paint};
})();
