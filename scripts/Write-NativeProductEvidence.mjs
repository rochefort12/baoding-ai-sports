// Publish only sanitized UI evidence; private sessions and credentials are never read.
import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import assert from 'node:assert/strict';
const root=process.cwd(),base=path.join(root,'.local/phase1-implementation'),doc='docs/04-verification/产品组件与视觉验证-20261010.json',shots='docs/05-ui/native-product-ui';
assert.equal(fs.existsSync(doc),false,'Existing published evidence must not be overwritten');
const read=rel=>JSON.parse(fs.readFileSync(path.join(base,rel),'utf8'));
const screens=read('native-ui-final/product-screens-receipt.json'),polish=read('native-ui-polish/product-screens-targeted-receipt.json'),growth=read('native-ui-growth-final/product-screens-targeted-receipt.json'),interactions=read('native-ui-interactions/receipt.json'),main=read('native-ui-public-final/receipt.json');
assert.equal(screens.rows.length,100);assert.deepEqual(screens.failures,[]);assert.equal(polish.rows.length,8);assert.deepEqual(polish.failures,[]);assert.equal(growth.rows.length,2);assert.deepEqual(growth.failures,[]);assert.equal(interactions.checks.length,23);assert.deepEqual(interactions.errors,[]);assert.equal(main.checks.length,4);
const build='ui-component-build-accepted.log';assert.match(fs.readFileSync(path.join(base,build),'utf8'),/built in/);assert.equal(fs.readFileSync(path.join(base,'ui-component-types-final.log'),'utf8').trim(),'');
const hash=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex'),relative=file=>path.relative(root,file).split(path.sep).join('/');
const records=[];
function bind(file){records.push({path:relative(file),sha256:hash(file)});}
fs.mkdirSync(shots,{recursive:true});
const selection=[
 ['native-ui-public-final','desktop-login.png'],['native-ui-public-final','mobile-login.png'],['native-ui-public-final','desktop-home.png'],['native-ui-public-final','mobile-home.png'],
 ['native-ui-final/product-screens','desktop-work-login.png'],['native-ui-final/product-screens','desktop-room-detail.png'],['native-ui-final/product-screens','mobile-room-detail.png'],
 ['native-ui-growth-final/product-screens','desktop-growth.png'],
 ['native-ui-polish/product-screens','desktop-organizer-home.png'],['native-ui-polish/product-screens','mobile-organizer-home.png'],['native-ui-polish/product-screens','desktop-government-home.png'],['native-ui-polish/product-screens','desktop-platform-objects.png']
];
for(const[folder,name]of selection){const source=path.join(base,folder,name),target=path.resolve(shots,name);fs.copyFileSync(source,target,fs.constants.COPYFILE_EXCL);bind(target);}
const evidence=['native-ui-final/product-screens-receipt.json','native-ui-polish/product-screens-targeted-receipt.json','native-ui-growth-final/product-screens-targeted-receipt.json','native-ui-interactions/receipt.json','native-ui-public-final/receipt.json','ui-auth-fields.log','ui-component-types-final.log',build];
for(const e of evidence)bind(path.join(base,e));
const components=fs.readdirSync('plus-ui/src/components/sport-ui').filter(n=>n.endsWith('.vue'));assert.equal(components.length,9);
for(const name of components)bind(path.resolve('plus-ui/src/components/sport-ui',name));
for(const file of ['plus-ui/src/components/sport-ui/useAuthFields.ts','plus-ui/src/components/sport-ui/useAuthFields.spec.ts','plus-ui/src/assets/styles/design-system.scss','plus-ui/src/assets/styles/index.scss','plus-ui/src/assets/logo/sports-mark.svg','plus-ui/src/views/login.vue','plus-ui/src/views/portal/login.vue','plus-ui/src/views/portal/register.vue','plus-ui/src/views/portal/forgot.vue','plus-ui/src/views/portal/home.vue','plus-ui/src/views/portal/rooms.vue','plus-ui/src/views/portal/growth.vue','plus-ui/src/views/sports/government/index.vue','plus-ui/src/views/sports/organization/desk.vue','plus-ui/src/layout/business/BusinessFrame.vue','plus-ui/src/layout/consumer/ConsumerShell.vue'])bind(path.resolve(file));
const parent='docs/04-verification/羽毛球一期闭环本机验证-20261010.json';assert.equal(hash(parent),'6d18927802b75867876af4753f6cdc2b7151689b92af35eca8dc744ba687a0ee');
const data={timestamp:new Date().toISOString(),scope:'Actual Vue product UI and actual local services. Role data are fictional isolated fixtures; main service was inspected anonymously. No SMS/model/money/event acceptance.',implementation:{nativeComponents:components,style:'plus-ui/src/assets/styles/design-system.scss',complexControls:'Existing tables, uploads, date inputs, dialogs and transactional forms retained'},checks:{types:'passed',deliveryBuild:'passed',fieldRules:7,readOnlyPageChecks:100,layoutFollowups:10,nativeInteractionChecks:23,mainAnonymousChecks:4},observedLimitations:['Existing shared JavaScript chunk exceeds 500KiB; build succeeds.','Real first registration/password recovery/SMS/model/event and money acceptance remain in the phase-one list.'],preservedFailures:['Early role screenshots could not open with expired isolated sessions; safe session recovery performed without replaying business facts.','Earlier CSS specificity and duplicate imports overrode intended layout; centralized assembly fixed it.'],parentEvidence:{path:parent,sha256:hash(parent)},artifacts:records};
fs.writeFileSync(doc,JSON.stringify(data,null,2)+'\n',{flag:'wx'});console.log('Published sanitized UI evidence: '+components.length+' components, '+screens.rows.length+' page checks, 12 screenshots.');

