<template>
  <el-dialog v-model="visible" class="ai-draft-dialog" title="核对办赛草稿" width="1120px" append-to-body :close-on-click-modal="false" :close-on-press-escape="!saving" :show-close="!saving" @closed="releaseImages">
    <div class="ai-draft-intro"><span>已按资料预填，缺项留空。选原句填入表单，或选图片作为封面。</span><el-tag type="info">{{ task.status==='CREATED'?'已保存':'候选草稿' }}</el-tag></div>
    <div v-if="error" class="ai-draft-error" role="alert">{{ error }}</div>
    <div class="ai-draft-layout">
      <aside class="ai-source-inspector" aria-label="资料原文与图片">
        <el-input v-model="search" placeholder="搜索原句、项目或金额" clearable aria-label="搜索资料原文" />
        <el-tabs v-model="sourceTab"><el-tab-pane label="原句与元素" name="text"/><el-tab-pane label="摘出图片" name="images"/></el-tabs>
        <p v-if="loading" role="status">正在读取原文元素…</p>
        <section v-if="sourceTab==='text'&&recognized.length" class="ai-recognized-elements" aria-label="已识别表单元素"><h3>已识别元素</h3><button v-for="item in recognized" :key="item.key+item.value" type="button" :disabled="readOnly||saving" @click="form[item.key]=item.value"><small>{{item.label}}</small><span>{{item.value}}</span><b>填入 →</b></button></section>
        <template v-for="file in sources" :key="file.fileId">
          <h3>{{ file.originalName || '办赛资料' }}</h3>
          <template v-if="sourceTab==='text'">
            <label v-for="block in filteredBlocks(file)" :key="file.fileId+block.label" class="ai-source-quote" :class="{selected:selected.includes(file.fileId+':'+block.label)}" @mouseup="captureSelection(block.text)">
              <input v-model="selected" type="checkbox" :value="file.fileId+':'+block.label" :disabled="readOnly||saving"/><span><small>{{ block.label }}</small><span>{{ block.text }}</span></span>
            </label>
            <label v-for="image in file.visuals.filter(i=>i.text&&(!search||i.text.includes(search)))" :key="image.index" class="ai-source-transcription ai-source-quote" :class="{selected:selected.includes(file.fileId+':visual:'+image.index)}" @mouseup="captureSelection(image.text||'')"><input v-model="selected" type="checkbox" :value="file.fileId+':visual:'+image.index" :disabled="readOnly||saving||image.recognitionStatus!=='read'"/><span><small>{{image.location}} · 图片识别，须对照原件</small><span>{{image.text}}</span></span></label>
          </template>
          <div v-else class="ai-source-image-grid">
            <button v-for="image in file.visuals" :key="image.index" type="button" :disabled="readOnly||saving||image.kind==='unsupported'" class="ai-source-image" :class="{selected:cover.fileId===file.fileId&&cover.index===image.index}" :aria-label="'选择封面：'+image.location" @click="chooseCover(file,image)">
              <img v-if="previews[key(file.fileId,image.index)]" :src="previews[key(file.fileId,image.index)]" :alt="image.caption||image.location" loading="lazy"/><span v-else class="ai-source-image-placeholder">{{ image.kind==='unsupported'?'需对照原件':'图片加载中' }}</span>
              <strong>{{ roleLabels[image.role||'other'] }}</strong><small>{{image.location}} · {{image.caption||'点选后作为封面候选'}}</small>
            </button>
          </div>
        </template>
        <p v-if="!loading&&!sources.length">这份草稿来自文字对话，暂无附件原文。</p>
        <div v-if="sourceTab==='text'&&!readOnly" class="ai-source-insert"><el-select v-model="target" :disabled="saving" aria-label="填入目标字段"><el-option v-for="field in textFields" :key="field.key" :label="field.label" :value="field.key"/></el-select><button type="button" :disabled="saving||!selected.length&&!selectedFragment" @click="insertSelection">{{selectedFragment?'填入划选文字':'填入选中原句'}}</button><small>也可划选一句或几个字。长文追加；名称、地点等短项替换。</small></div>
      </aside>
      <main class="ai-candidate-form" aria-label="AI预填赛事表单">
        <el-form label-position="top" :disabled="readOnly||saving">
          <section class="ai-cover-field"><div><h3>赛事封面</h3><p>{{coverLabel}}</p><button v-if="cover.fileId&&!readOnly" type="button" :disabled="saving" @click="cover={fileId:''}">移除封面</button></div><img v-if="cover.fileId&&previews[key(cover.fileId,cover.index!)]" :src="previews[key(cover.fileId,cover.index!)]" alt="当前封面候选"/><button v-else type="button" :disabled="readOnly||saving" @click="sourceTab='images'">从资料中选择图片</button></section>
          <div class="ai-form-grid"><el-form-item v-for="field in scalarFields" :key="field.key" :label="field.label"><el-input v-model="form[field.key]" :maxlength="field.key==='name'?200:500" placeholder="资料未说明，待补充" /></el-form-item></div>
          <div class="ai-form-grid"><el-form-item v-for="field in dateFields" :key="field.key" :label="field.label"><el-date-picker v-model="form[field.key]" type="datetime" value-format="YYYY-MM-DD HH:mm:ss" placeholder="待确认时间"/></el-form-item></div>
          <el-form-item label="报名审核"><el-select v-model="form.registrationReview" placeholder="默认无需人工审核"><el-option label="待确认" value=""/><el-option label="人工审核" value="manual"/><el-option label="无需人工审核" value="none"/></el-select><p class="ai-form-help">资料未说明时默认无需人工审核，可在这里修改。收费报名仍需实际足额收款。</p></el-form-item>
          <el-collapse><el-collapse-item :title="'参赛项目 · '+units.length+' 项'" name="units"><p class="ai-form-help">核对分类、每单人数、名额与整单价格。按人或兼项收费须由你确定整单总价，留空不代表免费。</p><article v-for="(unit,index) in units" :key="index" class="ai-form-unit"><el-form-item :label="'项目 '+(index+1)"><el-input v-model="unit.name" maxlength="200" /></el-form-item><div class="ai-form-grid"><el-form-item label="参赛形式"><el-select v-model="unit.entryType"><el-option label="待确认" value=""/><el-option label="个人" value="individual"/><el-option label="双人" value="pair"/><el-option label="团队" value="team"/></el-select></el-form-item><el-form-item label="报名名额 / 单"><el-input v-model="unit.limitCount" inputmode="numeric" placeholder="待补充"/></el-form-item><el-form-item label="每单最少人数"><el-input v-model="unit.minMembers" inputmode="numeric"/></el-form-item><el-form-item label="每单最多人数"><el-input v-model="unit.maxMembers" inputmode="numeric"/></el-form-item><el-form-item label="费用 / 元"><el-input v-model="unit.feeAmount" inputmode="decimal" placeholder="未明不填0"/></el-form-item><el-form-item label="费用单位"><el-select v-model="unit.feeBasis"><el-option label="待确认" value=""/><el-option label="整单总价" value="order"/><el-option label="原文按人" value="per_person"/><el-option label="原文附加费用" value="additional"/><el-option label="原文未明" value="unknown"/></el-select></el-form-item></div></article></el-collapse-item></el-collapse>
          <el-form-item v-for="field in longFields" :key="field.key" :label="field.label"><el-input v-model="form[field.key]" type="textarea" :autosize="{minRows:3,maxRows:9}" :maxlength="field.key==='rulesText'||field.key==='declarationText'?120000:12000" placeholder="可从左侧选择原句填入" /></el-form-item>
          <el-checkbox v-if="form.declarationText" v-model="declarationRequired">要求每位参赛成员阅读并确认声明</el-checkbox>
        </el-form>
      </main>
    </div>
    <template #footer><p>{{task.status==='CREATED'?'保存会更新同一赛事草稿，发布前仍可继续聊天修改。':'保存草稿可以继续修改；创建赛事会按当前表单确认建立，之后可在聊天中核对发布。'}}</p><el-button :disabled="saving" @click="visible=false">关闭</el-button><el-button v-if="!readOnly" :loading="saving" @click="save(false)">{{task.status==='CREATED'?'保存赛事修改':'保存表单到草稿'}}</el-button><el-button v-if="!readOnly&&task.status!=='CREATED'" type="primary" :loading="saving" @click="save(true)">创建赛事</el-button></template>
  </el-dialog>
</template>
<script setup lang="ts">
import {computed,ref,reactive,watch,onUnmounted} from 'vue';
import {ElMessage} from 'element-plus';
import {getAiSourceElements,aiTaskVisualBlob,editAiCandidate,type AiTaskCard,type AiSourceFile,type AiSourceVisual} from '@/api/sports/aiTask';
import {businessPickerTime} from '@/utils/business';
const props=defineProps<{task:AiTaskCard;declarationAckRequired:boolean;readOnly?:boolean}>(),visible=defineModel<boolean>({required:true});
const emit=defineEmits<{saved:[task:AiTaskCard,declarationRequired:boolean];create:[task:AiTaskCard,declarationRequired:boolean]}>();
const sources=ref<AiSourceFile[]>([]),form=reactive<Record<string,string>>({}),units=ref<Record<string,string>[]>([]),cover=ref<{fileId:string;index?:number}>({fileId:''}),search=ref(''),sourceTab=ref('text'),selected=ref<string[]>([]),target=ref('rulesText'),loading=ref(false),saving=ref(false),error=ref(''),declarationRequired=ref(false),previews=reactive<Record<string,string>>({});
let revision=0,loadedVersion:number|undefined,baseline='';
const snapshot=()=>JSON.stringify({event:form,units:units.value,cover:cover.value,declaration:declarationRequired.value});
const hasUnsavedChanges=()=>visible.value&&(saving.value||!!baseline&&snapshot()!==baseline);
defineExpose({hasUnsavedChanges});
const scalarFields=[{key:'name',label:'赛事名称'},{key:'location',label:'比赛地点'},{key:'projectName',label:'运动项目说明（发布必填）'},{key:'contactName',label:'联系人'},{key:'contactMethod',label:'联系方式'}];
const dateFields=[{key:'registrationOpensAt',label:'报名开始'},{key:'registrationClosesAt',label:'报名截止'},{key:'startsAt',label:'比赛开始'},{key:'endsAt',label:'比赛结束'}];
const longFields=[{key:'feeDescription',label:'收费说明与条件'},{key:'rulesText',label:'竞赛规程'},{key:'refundTerms',label:'退改说明'},{key:'declarationText',label:'参赛声明原文'}];
const textFields=[...scalarFields,...longFields],roleLabels:Record<string,string>={poster:'赛事海报 · 可作封面',photo:'现场照片 · 可作封面',logo:'标志',table:'表格 · 资料依据',qr:'二维码 · 资料依据',other:'图片 · 请核对用途'};
const selectedFragment=ref('');
const recognized=computed(()=>{try{const event=JSON.parse(props.task.proposal||'{}').event||{};return scalarFields.flatMap(field=>{const node=event[field.key],values=node?.status==='conflict'?node.alternatives||[]:node?.value?[node.value]:[];return values.filter((value:unknown)=>typeof value==='string'&&value.length<=300).slice(0,8).map((value:string)=>({key:field.key,label:field.label,value}));});}catch{return [];}});
const readOnly=computed(()=>props.readOnly||!['PENDING_CONFIRMATION','CREATED'].includes(props.task.status));
const coverLabel=computed(()=>cover.value.fileId?'已选择资料图片，可在左侧更换':'资料中没有合适的海报或照片时，封面留空');
const key=(file:string,index:number)=>file+':'+index;
function releaseImages(){revision++;Object.values(previews).forEach(URL.revokeObjectURL);Object.keys(previews).forEach(k=>delete previews[k]);}
function filteredBlocks(file:AiSourceFile){return (file.blocks||[]).filter(b=>b.text&&(!search.value||b.text.includes(search.value)));}
function captureSelection(sourceText:string){const text=window.getSelection()?.toString().trim()||'';selectedFragment.value=text&&text.length<=12000&&sourceText.includes(text)?text:'';}
function insertSelection(){if(readOnly.value||saving.value)return;const text=selectedFragment.value||sources.value.flatMap(f=>[...(f.blocks||[]).filter(b=>selected.value.includes(f.fileId+':'+b.label)).map(b=>b.text),...(f.visuals||[]).filter(image=>image.recognitionStatus==='read'&&selected.value.includes(f.fileId+':visual:'+image.index)).map(image=>image.text||'')]).join('\n');if(!text)return;form[target.value]=longFields.some(f=>f.key===target.value)&&form[target.value]?form[target.value]+'\n'+text:text;selected.value=[];selectedFragment.value='';ElMessage.success('已填入表单，保存后更新候选草稿');}
function chooseCover(file:AiSourceFile,image:AiSourceVisual){if(readOnly.value||saving.value)return;cover.value={fileId:file.fileId,index:image.index};if(['table','qr'].includes(image.role||''))ElMessage.info('这张图片识别为表格或二维码，请核对是否适合作为封面');}
async function load(){releaseImages();const stamp=revision;error.value='';selected.value=[];selectedFragment.value='';search.value='';declarationRequired.value=props.declarationAckRequired;loadedVersion=props.task.version;
  try{const proposal=JSON.parse(props.task.proposal||'{}');for(const field of [...scalarFields,...dateFields,...longFields,{key:'registrationReview'}]){const value=proposal.event?.[field.key]?.value||'';form[field.key]=field.key.endsWith('At')?businessPickerTime(value):String(value);}units.value=(proposal.units||[]).map((u:Record<string,{value?:unknown}>)=>Object.fromEntries(['name','entryType','limitCount','minMembers','maxMembers','feeAmount','feeBasis'].map(k=>[k,String(u[k]?.value??'')])));cover.value=proposal.cover?{fileId:proposal.cover.fileId,index:proposal.cover.index}:{fileId:''};}catch{error.value='草稿内容无法读取，请关闭后重新查看';return;}
  baseline=snapshot();loading.value=true;try{const result=await getAiSourceElements(props.task.id);if(stamp!==revision)return;sources.value=result.data.files||[];const pictures=sources.value.flatMap(f=>(f.visuals||[]).map(i=>({file:f,image:i})));let next=0;await Promise.all(Array.from({length:Math.min(3,pictures.length)},async()=>{while(next<pictures.length){const item=pictures[next++];if(item.image.kind==='unsupported')continue;try{const body=await aiTaskVisualBlob(props.task.id,item.file.fileId,item.image.index);if(stamp===revision)previews[key(item.file.fileId,item.image.index)]=URL.createObjectURL(body as unknown as Blob);}catch{if(stamp===revision)error.value='部分图片暂时无法预览，文字与表单仍可核对';}}}));}catch{if(stamp===revision)error.value='资料读取失败，请关闭后重新打开';}finally{if(stamp===revision)loading.value=false;}}
async function save(create=false){if(readOnly.value||saving.value||loadedVersion===undefined)return;saving.value=true;error.value='';try{const result=await editAiCandidate(props.task.id,{expectedVersion:loadedVersion,event:{...form},units:units.value,cover:cover.value.fileId?cover.value:{fileId:'0'},declarationAckRequired:declarationRequired.value});loadedVersion=result.data.version;baseline=snapshot();saving.value=false;visible.value=false;if(create&&props.task.status!=='CREATED')emit('create',result.data,declarationRequired.value);else{emit('saved',result.data,declarationRequired.value);ElMessage.success(props.task.status==='CREATED'?'修改已保存到原赛事草稿':'表单已保存到候选草稿');}}catch(reason){error.value=reason instanceof Error?reason.message:'保存未完成，请重新核对草稿版本';}finally{saving.value=false;}}
watch(visible,value=>{if(value)void load();});onUnmounted(releaseImages);
</script>
