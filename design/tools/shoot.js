// يصوّر حالات صفحة تصميم بالألوان وبالرمادي (وليلاً لما وُسم dark) إلى design/shots/
// الاستعمال: node design/tools/shoot.js s2 [مجلد الإخراج]
const {chromium}=require('playwright');const path=require('path');
(async()=>{
  const page=process.argv[2]||'s2',out=process.argv[3]||path.join(__dirname,'..','shots');
  const b=await chromium.launch();const p=await b.newPage({viewport:{width:1500,height:1200},deviceScaleFactor:2});
  const errs=[];p.on('pageerror',e=>errs.push(e.message));p.on('console',m=>{if(m.type()==='error')errs.push(m.text());});
  await p.goto('file://'+path.join(__dirname,'..',page+'.html'));await p.waitForTimeout(800);
  const ids=await p.$$eval('.scr[data-id]',a=>a.map(s=>s.dataset.id).filter(Boolean));
  // صفحة اللقطات تصوّر الشاشة بحجمها الحقيقي، لا مصغّرة
  await p.addStyleTag({content:'.phone{transform:none!important}.fit{height:auto!important;width:auto!important}.phone{position:relative!important}'});
  await p.waitForTimeout(300);
  for(const id of ids){const el=await p.$(`.scr[data-id="${id}"]`);
    await el.screenshot({path:path.join(out,id+'.png')});
    await el.evaluate(s=>s.closest('.phone').classList.add('gray'));await el.screenshot({path:path.join(out,id+'-gray.png')});
    await el.evaluate(s=>s.closest('.phone').classList.remove('gray'));}
  console.log(ids.length+' حالة',errs.length?'\nأخطاء: '+errs.join('\n'):'');await b.close();})();
