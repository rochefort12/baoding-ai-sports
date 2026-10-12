// Freeze source and actual evidence. Never copy tokens, private files or generated model text.
import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import assert from 'node:assert/strict';
const hash=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const read=p=>JSON.parse(fs.readFileSync(p,'utf8'));
const base='.local/product-release-20261011/';
const material=base+'materials-http-7c7c8cb9-e758-43f2-9ce8-127344462970.json';
const avatar=base+'avatar-http-1791682444992-583136b5.json';
const room=base+'room-ui-1791682396829/receipt.json';
const roomRecovery=base+'room-ui-1791682582190/receipt.json';
const organizer=base+'ui-1791682998396/receipt.json';
const avatarUi=base+'ui-1791682521592/receipt.json';
const coverUi=base+'ui-1791682546545/receipt.json';
const motion=base+'motion-1791682992672/receipt.json';
const pages='.local/phase1-implementation/product-release-ui-20261011/final/product-screens-receipt.json';
const type=base+'frontend-acceptance-typecheck.log',build=base+'frontend-product-built.log';
assert.ok(!/error TS|ELIFECYCLE/.test(fs.readFileSync(type,'utf8')));
assert.match(fs.readFileSync(build,'utf8'),/built in/);
const mat=read(material);assert.equal(mat.checks.length,28);assert.equal(Array.isArray(mat.failures)?mat.failures.length:mat.failures,0);assert.ok(mat.checks.every(c=>c.status==='PASS'));
assert.equal(read(avatar).passed,true);assert.equal(read(avatar).checks.length,24);
for(const p of [room,roomRecovery,organizer,avatarUi,coverUi]){const r=read(p);assert.deepEqual(r.failures,[]);assert.deepEqual(r.pageErrors,[]);}
assert.equal(read(room).checks.length,14);assert.equal(read(roomRecovery).checks.length,9);assert.equal(read(organizer).checks.length,5);
assert.equal(read(motion).passed,true);assert.equal(read(motion).checks.length,6);
assert.equal(read(pages).rows.length,100);assert.deepEqual(read(pages).failures,[]);
assert.match(fs.readFileSync(base+'java-verified-tests-rerun.log','utf8'),/BUILD SUCCESS/);
assert.match(fs.readFileSync(base+'ai-node-verified-suite.log','utf8'),/# tests 40/);
assert.match(fs.readFileSync(base+'ai-node-verified-suite.log','utf8'),/# fail 0/);
const restore=base+'migration-aeb19c87b50d4ec0a3c826c7c0723f98.json';assert.equal(read(restore).restoreAccepted,true);assert.equal(read(restore).repeatAccepted,true);
const required=[
 'backend/aisports-domains/d04/aisports-table-event/src/main/java/org/dromara/sports/event/service/EventMaterialActionProvider.java',
 'backend/aisports-domains/d04/aisports-table-event/src/main/java/org/dromara/sports/event/service/EventMaterialService.java',
 'backend/aisports-domains/d02/aisports-table-profile-display/src/main/java/org/dromara/sports/tables/d02/profile_display/ProfileAvatarService.java',
 'plus-ui/src/components/business/EventMaterialStudio.vue','plus-ui/src/components/business/EventCoverEditor.vue',
 'plus-ui/src/components/consumer/SportsAvatarEditor.vue','plus-ui/src/components/consumer/SportsAvatar.vue','plus-ui/src/api/sports/organizerMaterials.ts',
 'plus-ui/src/assets/styles/design-system.scss','plus-ui/src/assets/styles/business-ai.scss','plus-ui/src/layout/consumer/ConsumerShell.vue',
 'plus-ui/src/components/consumer/ConsumerAssistant.vue','plus-ui/src/components/consumer/ConsumerAuthLayout.vue',
 'plus-ui/src/views/portal/home.vue','plus-ui/src/views/portal/login.vue','plus-ui/src/views/portal/rooms.vue','plus-ui/src/views/portal/growth.vue',
 'plus-ui/src/views/sports/organization/review.vue','ai-gateway/materials.mjs','database/migrations/V034__event_material_studio.sql',
 'plus-ui/src/views/sports/event/index.vue','plus-ui/src/views/sports/organization/desk.vue'
];
const sourceFiles=required.map(p=>({path:p,sha256:hash(p)}));
const gate=p=>({passed:true,evidencePath:p,sha256:hash(p)});
const report={timestamp:new Date().toISOString(),scope:'local-product-studio-trial',passed:true,
 jarSha256:hash('backend/ruoyi-admin/target/ruoyi-admin.jar'),sourceFiles,
 checks:{frontendTypecheck:gate(type),frontendBuild:gate(build),realModel:gate(material),avatarHttp:gate(avatar),roomUi:gate(room),ordinaryOrganizerUi:gate(organizer),
   roomUiRecovery:gate(roomRecovery),avatarUi:gate(avatarUi),coverMobileUi:gate(coverUi),motion:gate(motion),pageScreens:gate(pages),restoreMigration:gate(restore),
   javaSelected:gate(base+'java-verified-tests-rerun.log'),gatewayTests:gate(base+'ai-node-verified-suite.log')},
 counts:{formalPages:50,desktopMobilePageChecks:100,avatarRealHttp:24,materialCoverRealHttp:28,roomActualUi:14,roomRecoveryAndFaultUi:9,avatarActualUi:4,materialActualUi:5,coverMobileActualUi:12,motionActualUi:6,javaSelected:30,gatewayUnitTests:40,tableModules:121},
 realModel:{provider:'DeepSeek',configuredModel:'deepseek-flash',types:['plan','script','announcement','promotion'],transport:'actual authenticated provider call',secrets:'DPAPI server-only; excluded from evidence'},
 migration:{version:'V034',restoreAndReplay:true,priorMigrationsUnchanged:true},
 staticAssets:{manifest:'docs/05-ui/assets-20261011/assets.json',sha256:hash('docs/05-ui/assets-20261011/assets.json'),generation:'built-in image_gen; underlying model name not returned'},
 release:{target:'three UI-only capabilities on loopback main 8080',state:'tested and prepared; actual activation receipt is a separate immutable artifact',agentChannel:'closed'},
 limitations:['Synthetic rehearsal people and events; no real bank, official match or business SMS acceptance in this run','Live cross-organization material read not observed: no second-organization event in fixture; rejection unit-tested only','Image provider credential missing: upload/platform artwork verified, real runtime AI image generation not accepted','No real mobile-device soft-keyboard or broad accessibility/performance certification','Existing large frontend bundles remain; no claim of cold-start performance benchmark','Original full phase-one ordinary-role and real-event completion gates remain open'],
 failureHistory:['Initial avatar JUnit tags excluded 10 cases: corrected local tags and observed all ten actual tests','Initial typecheck: team union and review busy string corrected','Initial page inspection: bronze decoration overflow corrected; final 100/0','Room full-count string comparison and offline hiding fixed; network recovery independently tested','UI selector assertions and repeat-draft fixture assumptions corrected; first failure files retained','Migration/backup and HTTP checkpoints retained; no payment/result replays'],
 predecessorHashes:{phase1:hash('docs/04-verification/羽毛球一期闭环本机验证-20261010.json'),nativeUi:hash('docs/04-verification/产品组件与视觉验证-20261010.json')}
};
const target='docs/04-verification/正式产品界面与创作功能验证-20261011.json';fs.writeFileSync(target,JSON.stringify(report,null,2)+'\n',{flag:'wx'});console.log('Frozen product evidence '+hash(target));
