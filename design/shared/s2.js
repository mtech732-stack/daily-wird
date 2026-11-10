/* ش2 · التظليل والعمر · محرّك الصفحة المرجعية design/s2.html
   يرسم الشاشة الرئيسية كما تكون في ش2: التظليل بضغطة وعلامة «اليوم»، والتراجع بضغطة ثانية،
   ودرجات العمر الخمس (القرار 14)، وسطر «آخر إدخال» (7.1.2)، ومفاتيح الرموز بالسحب (7.1.3)،
   وتفاصيل الربع بالضغط المطوّل (7.3). ولا عدّاد (ش5)، ولا حركة لموضع التوقّف ولا دورة (ش3).
   المرجع المكتوب: design/system.md §13. */
(function(){
const W=window.WIRD,{R,SN,N,quartersOf,BM,GEAR,TT}=W;
const CLOCK='<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>';
const PLUS='<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg>';
const UNDO='<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 14l-4-4 4-4"/><path d="M5 10h9a5 5 0 0 1 0 10h-3"/></svg>';

/* ── التاريخ: ميلادي، والأرقام إنجليزية، واليوم يبدأ عند منتصف الليل (القراران 1 و2) ── */
const BASE=new Date(2026,10,9); // «اليوم» في الصفحة: الاثنين 9 نوفمبر 2026 (كما في النماذج)
const WD=['الأحد','الاثنين','الثلاثاء','الأربعاء','الخميس','الجمعة','السبت'];
const MO=['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
const dayOf=(d,S)=>{const x=new Date(BASE);x.setDate(x.getDate()+(S?S.shift:0)-d);return x;};
function dShort(d,S){const x=dayOf(d,S),y=x.getFullYear()!==dayOf(0,S).getFullYear()?` ${N(x.getFullYear())}`:'';return `${N(x.getDate())} ${MO[x.getMonth()]}${y}`;}
const dLong=(d,S)=>`${WD[dayOf(d,S).getDay()]} ${dShort(d,S)}`;
/* صيغة المدّة (7.1.2) */
function rel(d){if(d===0)return 'اليوم';if(d===1)return 'أمس';if(d===2)return 'قبل يومين';if(d<=6)return `قبل ${N(d)} أيام`;
  if(d<=13)return 'قبل أسبوع';if(d<=20)return 'قبل أسبوعين';if(d<=29)return 'قبل 3 أسابيع';if(d<=59)return 'قبل شهر';if(d<=89)return 'قبل شهرين';
  const m=Math.floor(d/30);return m<=10?`قبل ${N(m)} أشهر`:`قبل ${N(m)} شهراً`;}
/* درجات العمر (القرار 14): خلال 7 · خلال 15 · خلال 22 · أكثر · لم يُتلَ. والحدّ شامل */
const lvl=a=>a==null?5:a<=7?1:a<=15?2:a<=22?3:4;
const LV=['','خلال 7 أيام','خلال 15 يوماً','خلال 22 يوماً','أكثر من 22 يوماً','لم يُتلَ'];
const mins=t=>{const[h,m]=t.split(' ')[0].split(':').map(Number);return (h%12)*60+m+(t.endsWith('م')?720:0);};

/* ── الحالة: سجلّ كل ربع = تظليلاته، الأحدث أولاً، كلٌّ بعدد أيامه ووقته ── */
function sync(S){S.age={};Object.keys(S.hist).forEach(r=>{const h=S.hist[r];S.age[r]=h.length?h[0].d:null;});}
function lastOf(S,t){let best=null;W.trackQuarters(S,t).forEach(r=>{const e=(S.hist[r]||[])[0];if(e&&(!best||e.d<best.d||(e.d===best.d&&mins(e.t)>mins(best.t))))best=e;});return best;}
const TIMES=['5:08 ص','4:52 ص','5:34 ص','5:21 ص','9:40 م','5:15 ص','4:47 ص'];
/* يبني سجلّاً معقولاً من عمر كل ربع: آخر تظليل بعمره، وقبله تظليلات متباعدة */
function make(o){
  const S=W.state(Object.assign({far:[],near:[],newHizb:null,ages:()=>{}},o));
  S.noStamp=true;S.shift=0;S.hist={};S.hideMeta=o.hideMeta!==false;S.hideBm=o.hideBm!==false;
  const ages=o.agesOf||(()=>null);
  [...W.trackQuarters(S,'far'),...W.trackQuarters(S,'near')].forEach(r=>{
    const a=ages(r);if(a==null){S.hist[r]=[];return;}
    const n=o.counts?o.counts(r):3+(r*7)%12,list=[];let d=a;
    for(let i=0;i<n;i++){list.push({d,t:TIMES[(r+i)%TIMES.length]});d+=9+((r+i*5)%11);}
    S.hist[r]=list;});
  Object.keys(S.hist).forEach(r=>{const e=S.hist[r][0];if(e&&e.d===0)e.t=o.todayAt||'4:58 ص';});
  sync(S);return S;
}
/* الضغطة: تلوته اليوم، أو تراجع إن ظُلّل اليوم (5.3). ولا يُظلَّل الربع مرتين في اليوم */
function tap(S,r,now='5:12 ص'){const h=S.hist[r]||(S.hist[r]=[]);if(h[0]&&h[0].d===0)h.shift();else h.unshift({d:0,t:now});sync(S);}
/* يوم جديد (أو أيام): تزيد كل الأعمار، وتختفي علامة «اليوم» */
function advance(S,n){S.shift+=n;Object.values(S.hist).forEach(h=>h.forEach(e=>e.d+=n));sync(S);}

/* ── الشاشة ── */
function stamp(S,t){const e=lastOf(S,t);if(!e)return ''; // لا سطر قبل أول إدخال في المسار
  return `<div class="stamp" data-stamp="${t}">${CLOCK}<b>آخر إدخال ${rel(e.d)}</b><span class="sd">${dLong(e.d,S)} · ${e.t}</span></div>`;}
function emptyCard(t){
  const msg=t==='new'?'لم تحدّد بعدُ الحزب الذي تحفظه.':'لم تُضف إليه شيئاً بعد.';
  const btn=t==='new'?'':`<button class="btn add" data-add="${t}">${PLUS}أضف جزءاً أو حزباً</button>`;
  const more=t==='new'?'':`<span class="more" role="button" aria-label="قائمة المسار">⋯</span>`;
  return `<div class="track empty" style="--c:var(--${t})" data-track="${t}"><div class="th"><span class="mk"></span><h3>${TT[t]}</h3>${more}</div><div class="emp"><p>${msg}</p>${btn}</div></div>`;
}
const card=(S,t)=>t==='new'||!S[t].length?emptyCard(t):stamp(S,t)+W.trackHTML(S,t);
function keysHTML(){
  const k=(c,t,txt)=>`<div class="key"><div class="q ${c} t-${t}" style="--cb:var(--card)">${c.includes('shared')?'<i class="cut"></i>':''}<span class="n">3</span></div><span>${txt}</span></div>`;
  return `<div class="keys" id="keys"><h3>مفاتيح الرموز</h3>
  <div class="kgrp">عمر الربع منذ آخر تلاوة · يتغيّر وحده مع الأيام</div>
  <div class="krow k5">${k('L1','far','خلال<br>7 أيام')}${k('L2','far','خلال<br>15 يوماً')}${k('L3','far','خلال<br>22 يوماً')}${k('L4','far','أكثر<br>من 22')}${k('L5','far','لم يُتلَ')}</div>
  <div class="kgrp">علامات تُضاف فوق أي ربع، أياً كان عمره</div>
  <div class="krow">${k('ghost today','ink','تلوته اليوم')}${k('ghost bm','ink','موضع التوقّف')}${k('ghost shared','ink','بين سورتين')}<div></div></div>
  <div class="kgrp">المحفوظ الجديد</div>
  <div class="krow">${k('L1','new','وجه محفوظ')}${k('L5','new','لم يُحفظ')}<div></div><div></div></div>
  <div class="ktxt">ضغطة: تلوته أو تراجع · ضغطة مطوّلة: التفاصيل</div></div>`;
}
function screen(S,ui={}){
  const fold=!S.open;
  return `<div class="island"></div><div class="status"><span>5:12</span><span>●●● ▮</span></div>
  <div class="scroll ${S.hideMeta?'nometa':''} ${S.hideBm?'nobm':''}">${fold?'<div class="fold s2f">':''}<div class="apphead"><div><h2>الورد اليومي</h2><span class="dt">${dLong(0,S)}</span></div><div class="ic" role="button" aria-label="الإعدادات">${GEAR}</div></div>
  ${card(S,'far')}${card(S,'near')}${card(S,'new')}${fold?'<div class="spacer"></div><div class="hint">اسحب للأعلى لمفاتيح الرموز</div></div>':''}
  ${keysHTML()}</div>${overlay(S,ui)}`;
}

/* ── تفاصيل الربع (7.3 · 5.4) ── */
function rangeTxt(x){const[a,b]=[x.first,x.last];return a[0]===b[0]?`من ${SN[a[0]]} ${N(a[1])} إلى ${N(b[1])}`:`من ${SN[a[0]]} ${N(a[1])} إلى ${SN[b[0]]} ${N(b[1])}`;}
function pagesTxt(x){const p=[];for(let i=x.firstPage;i<=x.lastPage;i++)p.push(N(i));return p.join(' · ');}
function details(S,ui){
  const r=ui.r,x=R[r],t=ui.t,h=S.hist[r]||[],a=S.age[r],q=(r-1)%4+1;
  const mini=`<div class="q t-${t} L${lvl(a)}${a===0?' today':''}" style="--cb:var(--paper)">${ui.shared?'<i class="cut"></i>':''}<span class="n">${N(q)}</span></div>`;
  const last=h.length?`<b class="two"><em>${rel(h[0].d)}</em><small>${dLong(h[0].d,S)} · ${h[0].t}</small></b>`:'<b class="none">لم يُتلَ بعد</b>';
  const chips=h.length?`<div class="chips">${h.slice(0,5).map((e,i)=>`<span class="chip${e.d===0?' now':''}">${e.d===0?'اليوم':dShort(e.d,S)}</span>`).join('')}</div>`:'<b class="none">لا تواريخ بعد</b>';
  return `<div class="dim" data-close></div><div class="sheet qd" role="dialog" aria-label="تفاصيل الربع"><div class="grab"></div>
  <div class="qhd">${mini}<div class="qtt"><h4>الحزب ${N(x.hizb)} · الربع ${N(q)}</h4><span>الجزء ${N(x.juz)}${ui.shared?'<span class="tag">ربع مشترك</span>':''}</span></div></div>
  <div class="kv"><span>المدى</span><b>${rangeTxt(x)}</b></div>
  <div class="kv"><span>السور</span><b>${x.suras.map(s=>SN[s]).join(' · ')}</b></div>
  <div class="kv"><span>الأوجه</span><b>${pagesTxt(x)}</b></div>
  <div class="kv"><span>آخر تلاوة</span>${last}</div>
  <div class="kv"><span>مرات التلاوة</span><b>${N(h.length)}</b></div>
  <div class="kv dates"><span>آخر التواريخ</span>${chips}</div>
  ${a===0?`<button class="btn undo" data-undo>${UNDO}تراجع عن تظليل اليوم</button>`:''}</div>`;
}
function overlay(S,ui){
  const toast=ui.toast?`<div class="toast" role="status">${ui.toast}</div>`:'';
  return (ui.ov==='qd'?details(S,ui):'')+toast;
}

/* الحالة المطويّة تملأ الشاشة، فتنزل الإشارة إلى أسفلها، ومفاتيح الرموز تحتها لا تُرى إلا بالسحب.
   مكان العدّاد (ش5) فراغ بلون الأرضية. وإن لم يبقَ للإشارة مكان (375×667 مع أحزاب كثيرة) خفيت */
function sizeFold(scr){const f=scr.querySelector('.fold');if(!f)return;const sc=scr.querySelector('.scroll'),cs=getComputedStyle(sc);
  const avail=sc.clientHeight-parseFloat(cs.paddingTop)-6;f.style.minHeight=avail+'px';
  const sp=f.querySelector('.spacer'),hn=f.querySelector('.hint');if(sp.offsetHeight<4&&f.scrollHeight>avail+2)hn.classList.add('tight');}

/* ── هاتف تفاعلي ── */
function interactive(scr,S,o={}){
  let ui={},tt;
  const render=(keep=true)=>{const y=scr.querySelector('.scroll')?.scrollTop||0;scr.innerHTML=screen(S,ui);sizeFold(scr);if(keep)scr.querySelector('.scroll').scrollTop=y;wire();o.onRender&&o.onRender(S);};
  function wire(){
    scr.querySelectorAll('[data-toggle]').forEach(e=>e.onclick=()=>{const t=e.dataset.toggle;S.open=S.open===t?null:t;ui={};render(false);if(S.open)W.scrollToBm(scr,S.open);});
    scr.querySelectorAll('[data-close]').forEach(e=>e.onclick=()=>{ui={};render();});
    const u=scr.querySelector('[data-undo]');if(u)u.onclick=()=>{tap(S,ui.r);ui={};render();};
    scr.querySelectorAll('.q[data-r]').forEach(el=>{let lp,long=false;
      const open=()=>{long=true;ui={ov:'qd',r:+el.dataset.r,t:el.dataset.t,shared:!!el.querySelector('.cut')};render();};
      el.onpointerdown=()=>{long=false;lp=setTimeout(open,450);};
      el.onpointerleave=()=>clearTimeout(lp);
      el.onpointerup=()=>{clearTimeout(lp);if(long)return;tap(S,+el.dataset.r);render();};
      el.oncontextmenu=ev=>{ev.preventDefault();clearTimeout(lp);open();};});
  }
  render();
  return {render,advance:n=>{advance(S,n);ui={};render();},S};
}
/* رسم ثابت لحالة واحدة (للصفحة واللقطات) */
function still(scr,S,ui,after){scr.innerHTML=screen(S,ui||{});sizeFold(scr);setTimeout(()=>after&&after(scr),40);}
window.S2={make,tap,advance,screen,still,interactive,rel,lvl,LV,dLong,dShort,keysHTML,details,sizeFold};
})();
