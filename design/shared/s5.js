/* ش5 · العدّاد · محرّك الصفحة المرجعية design/s5.html
   يبني على محرّك ش4 (المسارات الثلاثة كاملة) ويضع العدّاد مكان الفراغ الذي تركته ش2–ش4 (5.7 · 7.1):
   دائرة كبيرة تملأ ما تحت البطاقات، والعدد فيها وتحته «+»، والضغط في أي موضع منها يزيد واحداً مع اهتزاز خفيف،
   و«تصفير» فوقها لا يعمل إلا بالإمساك 0.8 ث. وعند فتح أرشيف مسار يصغر إلى شريط أسفل الشاشة.
   ومفاتيح الرموز تبقى ختام الصفحة تحت العدّاد بالسحب (القرار 27).
   هذا منطق عرض للصفحة وحدها. المرجع المكتوب: design/system.md §16. */
(function(){
const W=window.WIRD,S4=window.S4,{N}=W;
const HOLD=800;          /* مدّة الإمساك للتصفير (5.7) */
const MIN=76,MAX=136,BASE=122,BAR=64;

/* حجم الرقم بعدد خاناته (ذ39): حتى ثلاث 0.39 من القطر، وأربع 0.31، وخمس فأكثر 0.25 */
const ratio=n=>{const d=String(n).length;return d<=3?.39:d===4?.31:.25;};
const digits=n=>Math.min(5,String(n).length);

function counterHTML(S,mode,ui={}){
  const c=S.count,zero=c===0,hold=ui.hold||0;
  const fill=`<i style="--k:${hold}"></i>`;
  return `<div class="counter s5c ${mode==='big'?'big':''}" data-mode="${mode}">
    <button class="reset${zero?' idle':''}${hold?' holding':''}" aria-label="تصفير العدّاد" aria-describedby="rsh" ${zero?'aria-disabled="true"':''}>${fill}<span>تصفير</span></button>
    <button class="plus${ui.press?' press':''}" data-d="${digits(c)}" aria-label="العدّاد، ${N(c)}"><b class="cv">${N(c)}</b><span>+</span></button></div>`;
}
/* القطر = ما بقي من الشاشة بين البطاقات والإشارة، بين 76 و136 (§6، ت6). وإن قلّ عن 76 صار العدّاد صفّاً أفقياً بدائرة 64 وخفيت الإشارة */
function sizeFold(scr){
  const f=scr.querySelector('.fold');if(!f)return;const c=f.querySelector('.counter.big');if(!c)return;
  const sc=scr.querySelector('.scroll'),cs=getComputedStyle(sc);
  const avail=sc.clientHeight-parseFloat(cs.paddingTop)-6;f.style.minHeight=avail+'px';
  c.classList.remove('tight');scr.classList.remove('short','s5short');f.querySelector('.hint')?.classList.remove('tight');
  const mt=e=>{const s=getComputedStyle(e);return e.offsetHeight+parseFloat(s.marginTop)+parseFloat(s.marginBottom);};
  const used=[...f.children].filter(e=>e!==c).reduce((a,e)=>a+mt(e),0);
  const rs=c.querySelector('.reset');
  const room=avail-used-(rs.offsetHeight+6+4)-8;
  /* الشاشة القصيرة (ذ44): صفّ أفقي بدائرة 64، وتضيق المسافات بين البطاقات حتى يُرى العدّاد كاملاً بلا تمرير */
  if(room<MIN){scr.classList.add('short','s5short');c.classList.add('tight');f.querySelector('.hint')?.classList.add('tight');setD(c,BAR);}
  else setD(c,Math.min(MAX,Math.floor(room)));
}
function setD(c,d){c.style.setProperty('--plus',d+'px');const p=c.querySelector('.plus');p.style.setProperty('--r',ratio(+p.dataset.n||0));}
/* يضع العدّاد في الشاشة التي رسمها محرّك ش4: كبيراً مكان الفراغ، أو شريطاً تحت التمرير حين يُفتح أرشيف */
function mount(scr,S,ui={}){
  scr.querySelectorAll('.s5c').forEach(e=>e.remove());
  const sp=scr.querySelector('.fold .spacer');
  if(sp){sp.insertAdjacentHTML('beforebegin',counterHTML(S,'big',ui));sp.remove();}
  else scr.querySelector('.scroll').insertAdjacentHTML('afterend',counterHTML(S,'bar',ui));
  scr.classList.toggle('s5bar',!sp);
  const p=scr.querySelector('.s5c .plus');p.dataset.n=S.count;
  if(sp)sizeFold(scr);else setD(scr.querySelector('.s5c'),BAR);
}
function bump(scr,S){
  const p=scr.querySelector('.s5c .plus');if(!p)return;
  p.querySelector('.cv').textContent=N(S.count);p.dataset.n=S.count;p.dataset.d=digits(S.count);p.setAttribute('aria-label',`العدّاد، ${N(S.count)}`);
  p.style.setProperty('--r',ratio(S.count));
  const r=scr.querySelector('.s5c .reset');r.classList.toggle('idle',S.count===0);r.toggleAttribute('aria-disabled',S.count===0);
}

/* رسم ثابت لحالة واحدة */
function still(scr,S,ui={},after){
  S4.still(scr,S,ui.s4||{},after);mount(scr,S,ui); /* يُوضع قبل النزول إلى موضع التوقّف، لأن الشريط يأخذ من ارتفاع التمرير */
}
/* هاتف تفاعلي: كل ما في ش4، والعدّاد */
function interactive(scr,S,o={}){
  let hT,raf,t0;
  const vib=ms=>{try{navigator.vibrate&&navigator.vibrate(ms);}catch(e){}};
  const wireCounter=()=>{
    const p=scr.querySelector('.s5c .plus'),r=scr.querySelector('.s5c .reset'),bar=r.querySelector('i');
    /* الضغطة: يزيد واحداً فوراً، ويخفت الدائرة لحظة الضغط (ذ40)، واهتزاز خفيف (ذ41) */
    p.onpointerdown=()=>p.classList.add('press');
    p.onpointerup=p.onpointerleave=p.onpointercancel=()=>p.classList.remove('press');
    p.onclick=()=>{S.count++;bump(scr,S);vib(10);o.onCount&&o.onCount(S);};
    /* الإمساك: يمتلئ الزرّ من اليمين في 0.8 ث، فإذا تمّ صُفّر العدد مع اهتزاز أوضح (ذ41)؛ وإن رُفع الإصبع قبله انحسر ولم يتغيّر شيء (ذ42) */
    const stop=()=>{cancelAnimationFrame(raf);clearTimeout(hT);r.classList.remove('holding');bar.classList.add('back');bar.style.setProperty('--k',0);};
    r.onpointerdown=ev=>{if(S.count===0)return;ev.preventDefault();r.classList.add('holding');bar.classList.remove('back');t0=performance.now();
      const step=()=>{const k=Math.min(1,(performance.now()-t0)/HOLD);bar.style.setProperty('--k',k);if(k<1)raf=requestAnimationFrame(step);};raf=requestAnimationFrame(step);
      hT=setTimeout(()=>{S.count=0;bump(scr,S);vib(30);stop();o.onCount&&o.onCount(S);},HOLD);};
    r.onpointerup=r.onpointerleave=r.onpointercancel=stop;
    r.oncontextmenu=ev=>ev.preventDefault();
  };
  const api=S4.interactive(scr,S,Object.assign({},o,{onRender:s=>{mount(scr,S);wireCounter();o.onRender&&o.onRender(s);}}));
  return api;
}
window.S5={counterHTML,mount,still,interactive,sizeFold,ratio,HOLD};
})();
