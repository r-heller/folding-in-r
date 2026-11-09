const {chromium}=require('playwright');
const fs=require('node:fs/promises'),path=require('node:path'),http=require('node:http'),assert=require('node:assert/strict');
(async()=>{
 const root=path.resolve(process.env.BOOK_DIR||'docs');let server,base=process.env.BOOK_URL;
 if(!base){server=http.createServer(async(req,res)=>{const pathname=decodeURIComponent(new URL(req.url,'http://local').pathname);let file=path.join(root,pathname);if(pathname.endsWith('/'))file+='index.html';try{const data=await fs.readFile(file);res.setHeader('Content-Type',({'.html':'text/html','.js':'application/javascript','.json':'application/json','.css':'text/css','.svg':'image/svg+xml'})[path.extname(file)]||'application/octet-stream');res.end(data);}catch{res.statusCode=404;res.end('Missing');}});await new Promise(r=>server.listen(0,'127.0.0.1',r));base=`http://127.0.0.1:${server.address().port}/`;}
 const browser=await chromium.launch();const errors=[],tracking=[];
 try{
  const page=await browser.newPage({viewport:{width:1440,height:1000}});
  page.on('pageerror',e=>errors.push(e.message));page.on('request',r=>{if(/(?:met\.)?vgwort\.de/i.test(r.url()))tracking.push(r.url())});
  await page.goto(base,{waitUntil:'networkidle'});
  await page.locator('#mode-switch').click();assert.equal(await page.locator('html').getAttribute('data-theme'),'dark');
  await page.reload({waitUntil:'networkidle'});assert.equal(await page.locator('html').getAttribute('data-theme'),'dark');
  await page.locator('#search').fill('Miura');await page.locator('.aa-suggestion').first().waitFor();assert.ok(await page.locator('.aa-suggestion').count());
  await page.locator('#search').fill('');
  const links=await page.locator('a[href]').evaluateAll(es=>[...new Set(es.filter(e=>/\.(pdf|epub)$/.test(e.href)).map(e=>e.href))]);
  assert.ok(links.some(x=>x.endsWith('.epub')),'EPUB must be available');assert.ok(links.some(x=>x.endsWith('.pdf')),'PDF must be available');
  for(const url of links)assert.equal((await page.request.get(url)).status(),200,url);
  await page.goto(base+'intro.html',{waitUntil:'networkidle'});const figure=page.frameLocator('iframe');await figure.locator('#theta').waitFor();const before=await figure.locator('#thetaOut').textContent();await figure.locator('#theta').fill('3');assert.notEqual(await figure.locator('#thetaOut').textContent(),before);await figure.locator('#reset').click();
  await page.setViewportSize({width:390,height:844});assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1));
  const menu=page.locator('button[data-target="#main-nav"]');await menu.click();await page.locator('#main-nav.show').waitFor();await menu.click();await page.locator('#main-nav:not(.show):not(.collapsing)').waitFor({state:'attached'});
  for(const chapter of ['folding-geometry.html','generative.html','evaluation.html']) {
    await page.goto(base+chapter,{waitUntil:'networkidle'});
    await page.evaluate(()=>document.fonts.ready);
    await page.evaluate(()=>new Promise(resolve=>window.MathJax&&MathJax.Hub?MathJax.Hub.Queue(resolve):resolve()));
    assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),chapter+' must fit a mobile viewport');
  }
  assert.deepEqual(await page.locator('img').evaluateAll(es=>es.filter(e=>!e.complete||!e.naturalWidth).map(e=>e.src)),[]);assert.deepEqual(errors,[]);assert.deepEqual(tracking,[]);
  console.log('PASS: search, persistent theme, PDF/EPUB, folding controls, mobile navigation, images and no counting requests.');
 }finally{await browser.close();if(server){server.closeAllConnections();await new Promise(r=>server.close(r));}}
})().catch(e=>{console.error(e);process.exitCode=1});
