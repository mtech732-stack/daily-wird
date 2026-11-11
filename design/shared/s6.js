/* ش6 · الصقل · محرّك الصفحة المرجعية design/s6.html
   يبني على محرّك ش5 (التطبيق كما هو في آخرها) ويضيف: ورقة الإعدادات وصفحة «عن التطبيق» (7.4 · 5.8)،
   وشاشة البداية (8.3)، وأكبر أحجام الخط (م46). والوضع الليلي في ds.css (§17.1).
   هذا منطق عرض للصفحة وحدها. المرجع المكتوب: design/system.md §17. */
(function(){
const S5=window.S5;
const ARR='<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 6l6 6-6 6"/></svg>';   /* «رجوع» في RTL يشير يميناً */
const FWD='<svg class="chev" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 6l-6 6 6 6"/></svg>';
const CLOUD='<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M7 18h10a4 4 0 0 0 .6-7.95A6 6 0 0 0 6.1 9.5 4.3 4.3 0 0 0 7 18z"/></svg>';
const CHECK='<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>';
const SLASH='<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M7 18h10a4 4 0 0 0 .6-7.95A6 6 0 0 0 6.1 9.5 4.3 4.3 0 0 0 7 18z"/><path d="M4 4l16 16"/></svg>';
const PHONE='<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="7" y="3" width="10" height="18" rx="2.5"/><path d="M11 18h2"/></svg>';

/* حالة النسخ الاحتياطي (5.8): ثلاث، ونصّ «متوقّف» بنصّ الوثيقة */
const CLOUDS={
  on:{b:'ok',i:CHECK,t:'iCloud',s:'يُنسخ سجلّك إلى iCloud تلقائياً',f:'كل ما تظلّله وتحفظه يُنسخ إلى حسابك في iCloud، فيعود كاملاً إن حذفت التطبيق ثم ثبّتّه. والعدّاد في هذا الجهاز وحده.'},
  off:{b:'off',i:SLASH,t:'iCloud',s:'النسخ الاحتياطي متوقّف: iCloud غير مفعّل',f:'يعمل التطبيق في هذا الجهاز، وسجلّك محفوظ فيه. ويبدأ النسخ وحده متى سجّلت الدخول إلى iCloud في إعدادات الجهاز.'},
  local:{b:'loc',i:PHONE,t:'في هذا الجهاز',s:'سجلّك محفوظ في هذا الجهاز',f:'النسخ إلى iCloud يُفعَّل قبل الإطلاق (ش7)، ويُنقل إليه سجلّك كما هو.'},
};
function settingsHTML(o={}){
  const c=CLOUDS[o.cloud||'local'];
  return `<div class="dim"></div><div class="sheet tall set" role="dialog" aria-label="الإعدادات"><div class="shd"><div class="grab"></div>
    <div class="ttl"><h4>الإعدادات</h4><button class="lnk">تمّ</button></div></div>
    <div class="slist">
      <div class="sgh">النسخ الاحتياطي</div>
      <div class="sgrp"><div class="srow"><span class="badge ${c.b}" aria-hidden="true">${c.i}</span><div class="tx"><span>${c.t}</span><small>${c.s}</small></div></div></div>
      <div class="sfoot">${c.f}</div>
      <div class="sgh">التطبيق</div>
      <div class="sgrp"><div class="srow"><span class="tx">الإصدار</span><span class="v">1.0</span></div>
        <div class="srow nav" role="button"><span class="tx">عن التطبيق</span>${FWD}</div></div>
    </div></div>`;
}
function aboutHTML(o={}){
  const logo=o.logo?`<img class="logo" src="${o.logo}" alt="">`:`<div class="logo" aria-hidden="true">شعار المالك<br>(س8)</div>`;
  return `<div class="dim"></div><div class="sheet tall set about" role="dialog" aria-label="عن التطبيق"><div class="shd"><div class="grab"></div>
    <div class="ttl sub"><button class="back">${ARR}الإعدادات</button><h4>عن التطبيق</h4><button class="lnk">تمّ</button></div></div>
    <div class="slist">
      <div class="who">${logo}<b><span class="ph">${o.name||'اسم المالك (س8)'}</span></b><span>الورد اليومي · الإصدار 1.0</span></div>
      <div class="sgh">مصدر البيانات القرآنية</div>
      <div class="sgrp"><div class="src">
        <p>حدود الأوجه والأرباع والأحزاب والسور من بيانات مشروع «تنزيل» المفتوحة، على مصحف المدينة النبوية.</p>
        <p>وصُحّح منها 26 حدّاً على طبعة مجمّع الملك فهد، كما في مصحف المالك.</p>
        <p class="m">Tanzil.net · رخصة CC BY 3.0</p></div></div>
    </div></div>`;
}
/* الشاشة الرئيسية كما في ش5، وفوقها الورقة */
function settings(scr,S,o={}){S5.still(scr,S);scr.insertAdjacentHTML('beforeend',o.about?aboutHTML(o):settingsHTML(o));scr.classList.add('s6set');}
/* شاشة البداية: صورة واحدة بقياس الشاشة من design/launch/ (يولّدها design/tools/build_launch.py) */
function launch(scr,{theme='light',w=393}={}){
  scr.classList.add('launch');
  scr.innerHTML=`<img src="launch/launch-${theme}-${w}.svg" alt="شاشة البداية">`;
}
window.S6={settings,launch,settingsHTML,aboutHTML};
})();
