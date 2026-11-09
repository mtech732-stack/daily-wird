/* محرّك صفحات التصميم المرجعية · يرسم الشاشات من الحدود الحقيقية (quran.js) ومن رموز ds.css.
   منقول من منطق النماذج المعتمدة (design/mockups.html) مع تعميمه على أي حزب، وجمع السور القصيرة (7.1.1). */
(function(){
const Q=window.QURAN, R={}; Q.quarters.forEach(x=>R[x.n]=x);
const SN=Q.suras;
const N=n=>String(n); // الأرقام إنجليزية دائماً
const BM='<svg class="bmk" width="11" height="14" viewBox="0 0 11 14"><path class="b1" d="M1 1h9v12l-4.5-3.2L1 13z" fill="currentColor"/><path class="b2" d="M1 0h9v14l-4.5-4.6L1 14z" fill="currentColor"/></svg>';
const CHEV='<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 9l6 6 6-6"/></svg>';
const GEAR='<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="12" cy="12" r="3"/><path d="M12 2v3M12 19v3M4.2 4.2l2.1 2.1M17.7 17.7l2.1 2.1M2 12h3M19 12h3M4.2 19.8l2.1-2.1M17.7 6.3l2.1-2.1"/></svg>';
const CLOCK='<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>';
const TT={far:'مراجعة البعيد',near:'مراجعة القريب',new:'المحفوظ الجديد'};
const quartersOf=h=>[1,2,3,4].map(i=>(h-1)*4+i);

function rel(d){if(d===0)return 'اليوم';if(d===1)return 'أمس';if(d===2)return 'قبل يومين';if(d<=6)return `قبل ${N(d)} أيام`;
  if(d<=13)return 'قبل أسبوع';if(d<=20)return 'قبل أسبوعين';if(d<=29)return 'قبل 3 أسابيع';if(d<=59)return 'قبل شهر';if(d<=89)return 'قبل شهرين';return `قبل ${N(Math.floor(d/30))} أشهر`;}
/* درجات العمر (القرار 13): خلال 7 · خلال 15 · خلال 22 · أكثر · لم يُتلَ */
const lvl=a=>a==null?5:a<=7?1:a<=15?2:a<=22?3:4;

/* الحالة: أحزاب كل مسار، وعمر كل ربع بالأيام (null = لم يُتلَ)، وما ظُلّل في الدورة الحالية */
function state(o){
  const S={far:o.far||[],near:o.near||[],newHizb:o.newHizb||null,age:{},cyc:{far:new Set(),near:new Set()},done:{},count:o.count??33,open:o.open||null,
    last:o.last||{far:[0,'الاثنين 9 نوفمبر · 5:08 ص'],near:[3,'الجمعة 6 نوفمبر · 5:34 ص'],new:[1,'الأحد 8 نوفمبر · 4:51 ص']}};
  (o.ages||(()=>null))(S);
  return S;
}
const trackQuarters=(S,t)=>S[t].flatMap(quartersOf);
const bookmark=(S,t)=>trackQuarters(S,t).find(r=>!S.cyc[t].has(r));

/* أقسام السور (7.1.1): قسم لكل سورة، وتُجمع السور المتجاورة التي تقع كلها في الأرباع نفسها */
function sections(S,t){
  const qs=trackQuarters(S,t), bySura=new Map();
  qs.forEach(r=>R[r].suras.forEach(s=>{if(!bySura.has(s))bySura.set(s,[]);bySura.get(s).push(r);}));
  const list=[...bySura.entries()].sort((a,b)=>a[0]-b[0]).map(([s,rs])=>({suras:[s],rs}));
  const merged=[];
  list.forEach(sec=>{const p=merged[merged.length-1];
    if(p&&p.rs.join()===sec.rs.join()&&p.suras[p.suras.length-1]===sec.suras[0]-1)p.suras.push(sec.suras[0]);else merged.push(sec);});
  const seen={};merged.forEach(sec=>sec.rs.forEach(r=>seen[r]=(seen[r]||0)+1));
  merged.forEach(sec=>sec.shared=new Set(sec.rs.filter(r=>seen[r]>1)));
  return merged;
}
function qBox(S,r,t,shared){
  const a=S.age[r],cls=['q','t-'+t,'L'+lvl(a)];
  if(a===0)cls.push('today');
  if(bookmark(S,t)===r)cls.push('bm');
  return `<div class="${cls.join(' ')}" data-r="${r}" data-t="${t}" role="button" aria-label="الحزب ${R[r].hizb} الربع ${(r-1)%4+1}">${shared?'<i class="cut"></i>':''}<span class="n">${N((r-1)%4+1)}</span></div>`;
}
function archive(S,t){
  const secs=sections(S,t),bm=bookmark(S,t),juzSeen=new Set();let h='';
  secs.forEach(sec=>{
    const hz=[...new Set(sec.rs.map(r=>R[r].hizb))];
    const rng=hz.length>1?`ح ${N(hz[0])} ← ح ${N(hz[hz.length-1])}`:`ح ${N(hz[0])}`;
    h+=`<div class="sur"><div class="sh"><b>${sec.suras.map(s=>SN[s]).join(' · ')}</b><span>${rng}</span></div>`;
    hz.forEach(hb=>{let qs='';
      quartersOf(hb).forEach(r=>qs+=sec.rs.includes(r)?qBox(S,r,t,sec.shared.has(r)):'<div class="q gap"></div>');
      const j=R[(hb-1)*4+1].juz, jz=juzSeen.has(j)?'':`<span class="juzw"><span class="juz">الجزء ${N(j)}</span></span>`;juzSeen.add(j);
      const isBm=quartersOf(hb).includes(bm)&&sec.rs.includes(bm);
      h+=`<div class="row"><div class="lbl">${isBm?BM:''}ح ${N(hb)}</div><div class="qs">${qs}</div>${jz}</div>`;});
    h+='</div>';});
  return h;
}
function current(S,t){
  const bm=bookmark(S,t)||trackQuarters(S,t)[0],hb=R[bm].hizb,rs=quartersOf(hb),tq=trackQuarters(S,t);
  const secs=sections(S,t),sharedAll=new Set(secs.flatMap(s=>[...s.shared]));
  const sur=[...new Set(rs.filter(r=>tq.includes(r)).flatMap(r=>R[r].suras))];
  const name=sur.length>3?`${SN[sur[0]]} ← ${SN[sur[sur.length-1]]}`:sur.map(s=>SN[s]).join(' · ');
  const qs=rs.map(r=>tq.includes(r)?qBox(S,r,t,sharedAll.has(r)&&R[r].suras.length>1):'<div class="q gap"></div>').join('');
  return `<div class="cur"><div class="row"><div class="lbl">${BM}ح ${N(hb)}</div><div class="qs">${qs}</div><div class="side"><b>${name}</b><span>الجزء ${N(R[bm].juz)}</span></div></div></div>`;
}
const stamp=(S,t)=>`<div class="stamp">${CLOCK}<b>آخر إدخال ${rel(S.last[t][0])}</b><span class="sd">${S.last[t][1]}</span></div>`;
const head=(t,meta)=>`<div class="th"><span class="mk"></span><h3>${TT[t]}</h3><span class="meta2">${meta}</span><span class="more" aria-label="قائمة المسار">⋯</span></div>`;
const pull=(t,open,label)=>`<div class="pull ${open?'up':''}" data-toggle="${t}" role="button"><span>${open?'طيّ':label}</span><span class="chev">${CHEV}</span></div>`;
function trackHTML(S,t){
  if(!S[t].length)return '';
  const open=S.open===t,total=trackQuarters(S,t).length,done=S.cyc[t].size;
  return `${stamp(S,t)}<div class="track ${open?'open':''}" style="--c:var(--${t})" data-track="${t}">${head(t,`${N(done)} من ${N(total)}`)}
  ${open?archive(S,t):current(S,t)}${pull(t,open,'عرض كامل المراجعة')}</div>`;
}
function hizbPages(h){const a=R[(h-1)*4+1].firstPage,b=R[h*4].lastPage;const out=[];for(let p=a;p<=b;p++)out.push(p);return out;}
function newHTML(S){
  if(!S.newHizb)return '';
  const h=S.newHizb,list=hizbPages(h),next=list.find(p=>S.done[p]===undefined),n=list.filter(p=>S.done[p]!==undefined).length,open=S.open==='new';
  const idx=Math.max(0,list.indexOf(next===undefined?list[list.length-1]:next)),start=Math.min(Math.floor(idx/5)*5,Math.max(0,list.length-5));
  const shown=open?list:list.slice(start,start+5);
  const sharedFirst=R[(h-1)*4].lastPage===list[0];
  const box=p=>{const a=S.done[p],cls=['q','t-new',a===undefined?'L5':'L1'];if(a===0)cls.push('today');if(p===next)cls.push('bm');
    return `<div class="${cls.join(' ')}" data-p="${p}" role="button">${p===list[0]&&sharedFirst?'<i class="cut"></i>':''}<span class="n">${N(p)}</span></div>`;};
  const sur=[...new Set(quartersOf(h).flatMap(r=>R[r].suras))].map(s=>SN[s]).join(' · ');
  return `${stamp(S,'new')}<div class="track ${open?'open':''}" style="--c:var(--new)" data-track="new">${head('new',`${N(n)} من ${N(list.length)}`)}
  <div class="cur"><div class="sub">${BM} ح ${N(h)} · ${sur} · الجزء ${N(R[h*4].juz)}</div>
  <div class="pages">${shown.map(box).join('')}</div></div>${pull('new',open,'عرض كل أوجه الحزب')}</div>`;
}
const counterHTML=(S,big)=>`<div class="counter ${big?'big':''}"><button class="reset">تصفير</button><button class="plus" aria-label="زيادة"><b class="cv">${N(S.count)}</b><span>+</span></button></div>`;
function keysHTML(){
  const k=(c,t,txt)=>`<div class="key"><div class="q ${c} t-${t}" style="--cb:var(--card)">${c.includes('shared')?'<i class="cut"></i>':''}<span class="n">3</span></div><span>${txt}</span></div>`;
  return `<div class="keys"><h3>مفاتيح الرموز</h3>
  <div class="kgrp">عمر الربع منذ آخر تلاوة · يتغيّر وحده مع الأيام</div>
  <div class="krow k5">${k('L1','far','خلال 7 أيام')}${k('L2','far','خلال 15 يوماً')}${k('L3','far','خلال 22 يوماً')}${k('L4','far','أكثر من 22')}${k('L5','far','لم يُتلَ')}</div>
  <div class="kgrp">علامات تُضاف فوق أي ربع، أياً كان عمره</div>
  <div class="krow">${k('ghost today','ink','تلوته اليوم')}${k('ghost bm','ink','موضع التوقّف')}${k('ghost shared','ink','بين سورتين')}<div></div></div>
  <div class="kgrp">المحفوظ الجديد</div>
  <div class="krow">${k('L1','new','وجه محفوظ')}${k('L5','new','لم يُحفظ')}<div></div><div></div></div>
  <div class="ktxt">ضغطة: تلوته أو تراجع · ضغطة مطوّلة: التفاصيل</div></div>`;
}
function screenHTML(S,o={}){
  const big=!S.open;
  return `<div class="island"></div><div class="status"><span>5:12</span><span>●●● ▮</span></div>
  <div class="scroll">${big?'<div class="fold">':''}<div class="apphead"><div><h2>الورد اليومي</h2><span class="dt">الاثنين 9 نوفمبر</span></div><div class="ic" role="button" aria-label="الإعدادات">${GEAR}</div></div>
  ${trackHTML(S,'far')}${trackHTML(S,'near')}${newHTML(S)}${big?counterHTML(S,true)+'<div class="hint">اسحب للأعلى لمفاتيح الرموز</div></div>':''}
  ${o.keys===false?'':keysHTML()}</div>${big?'':counterHTML(S,false)}`;
}
/* ارتفاع الحالة المطويّة = ارتفاع الشاشة ناقص شريط الحالة والهامش، فيملأ العدّاد ما بقي */
/* والعدّاد الكبير قطره 122 أساساً، يتقلّص حتى 76 إن ضاق المكان ويتّسع حتى 136، فتبقى البطاقات الثلاث والإشارة ظاهرة بلا تمرير */
function sizeFold(scr){const f=scr.querySelector('.fold');if(!f)return;const st=scr.querySelector('.status').offsetHeight;const avail=scr.clientHeight-st-4-6;
  f.style.minHeight=avail+'px';const c=f.querySelector('.counter.big');c.style.setProperty('--plus','76px');
  const used=[...f.children].filter(e=>e!==c).reduce((a,e)=>a+e.offsetHeight+parseFloat(getComputedStyle(e).marginTop)+parseFloat(getComputedStyle(e).marginBottom),0);
  const room=avail-used-(c.querySelector('.reset').offsetHeight+6+4)-8;
  if(room<76){scr.classList.add('short');c.classList.add('tight');f.querySelector('.hint')?.classList.add('tight');c.style.setProperty('--plus','64px');}
  else c.style.setProperty('--plus',Math.min(136,Math.floor(room))+'px');}
function scrollToBm(scr,t){const sc=scr.querySelector('.scroll'),b=scr.querySelector(`[data-track="${t}"] .bm`);if(sc&&b)sc.scrollTop=b.getBoundingClientRect().top-sc.getBoundingClientRect().top+sc.scrollTop-300;}

/* تفاعل خفيف للهاتف التفاعلي: تظليل وتراجع، وإسدال وطيّ، وعدّاد */
function interactive(scr,S,o={}){
  const render=()=>{const y=scr.querySelector('.scroll')?.scrollTop||0;scr.innerHTML=screenHTML(S,o);sizeFold(scr);scr.querySelector('.scroll').scrollTop=y;wire();};
  function wire(){
    scr.querySelectorAll('[data-toggle]').forEach(h=>h.onclick=()=>{const t=h.dataset.toggle;S.open=S.open===t?null:t;scr.innerHTML=screenHTML(S,o);sizeFold(scr);wire();if(S.open&&S.open!=='new')scrollToBm(scr,S.open);});
    scr.querySelectorAll('.q[data-r]').forEach(el=>el.onclick=()=>{const r=+el.dataset.r,t=el.dataset.t;
      if(S.age[r]===0){S.age[r]=S.prev?.[r]??null;S.cyc[t].delete(r);}else{(S.prev=S.prev||{})[r]=S.age[r];S.age[r]=0;S.cyc[t].add(r);}render();});
    scr.querySelectorAll('.q[data-p]').forEach(el=>el.onclick=()=>{const p=+el.dataset.p;if(S.done[p]===0)delete S.done[p];else if(S.done[p]===undefined)S.done[p]=0;render();});
    const pl=scr.querySelector('.plus');if(pl)pl.onclick=()=>{S.count++;scr.querySelector('.cv').textContent=N(S.count);if(navigator.vibrate)navigator.vibrate(12);};
  }
  render();
}

/* إطار الهاتف، مصغّراً ليتّسع لعرض الشاشة التي يُعرض عليها (هاتف المالك) */
function phone(host,{size='',cls='',title='',cap=''}={}){
  const f=document.createElement('figure');f.className='fig';
  f.innerHTML=`<div class="fit"><div class="phone ${size} ${cls}"><div class="scr ${size}"></div></div></div><figcaption><b>${title}</b>${cap}</figcaption>`;
  host.appendChild(f);return f.querySelector('.scr');
}
function fitAll(){document.querySelectorAll('.fit').forEach(w=>{const p=w.firstElementChild;const W=p.offsetWidth,H=p.offsetHeight;const s=Math.min(1,w.parentElement.clientWidth/W);
  p.style.transform=`scale(${s})`;p.style.transformOrigin='top right';w.style.height=(H*s)+'px';w.style.width=(W*s)+'px';});}
addEventListener('resize',fitAll);

/* الحالة الواقعية نفسها في النماذج: البعيد ح 1–9، والقريب ح 10–11، والجديد ح 12 */
function owner(o={}){
  return state(Object.assign({far:[1,2,3,4,5,6,7,8,9],near:[10,11],newHizb:12,ages:S=>{
    for(let r=1;r<=36;r++)S.age[r]=r<=8?12:r<=19?3:r<=22?0:r<=30?41:r<=34?20:null;
    for(let r=37;r<=44;r++)S.age[r]=r<=38?3:r<=40?9:15;
    for(let r=1;r<=22;r++)S.cyc.far.add(r);S.cyc.near.add(37);S.cyc.near.add(38);
    Object.assign(S.done,{112:4,113:4,114:3,115:2,116:1});}},o));
}
window.WIRD={Q,R,SN,N,state,owner,screenHTML,sections,keysHTML,qBox,interactive,phone,fitAll,sizeFold,scrollToBm,BM};
})();
