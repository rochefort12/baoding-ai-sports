<template>
  <div class="app-container">
    <div v-if="!eventKey && mode !== 'controls'" class="b-heading">
      <div>
        <span class="b-eyebrow">组织工作台</span>
        <h1>赛事管理</h1>
        <p>创建赛事、配置报名项目，进入工作区完成运营任务。</p>
      </div>
      <div class="b-create-actions">
        <el-button class="b-ai-button" @click="goFromDocument"><img class="sport-assistant-mark" src="/images/sports/assistant-orb-v2.webp" alt="" width="22" height="22" draggable="false"/>准备赛事</el-button>
        <el-button class="b-manual-button" @click="openCreate">＋ 手动创建赛事</el-button>
      </div>
    </div>
    <el-alert v-if="loadError" :title="loadError" type="error" :closable="false" />
    <el-card v-if="!['notifications', 'controls'].includes(mode)" shadow="never">
      <template #header>{{ eventKey ? '赛事发布与内容' : '本组织赛事' }}</template>
      <div v-if="!eventKey" class="b-toolbar">
        <el-input v-model="query" placeholder="搜索赛事名称" clearable /><el-select v-model="stage"
          ><el-option label="全部赛事" value="all" /><el-option label="报名中" value="registration" /><el-option
            label="已结束"
            value="finished" /><el-option label="已取消" value="cancelled" /></el-select
        ><el-button @click="load">刷新</el-button>
      </div>
      <p v-else class="b-muted">草稿可先保存缺项；首次发布、恢复公开、下架与取消分别办理。</p>
      <div v-if="!eventKey" class="managed-event-grid" v-loading="loading">
        <p v-if="!loading && !filteredRows.length" class="managed-event-empty">{{ query || stage !== 'all' ? '没有找到符合条件的赛事，试试调整筛选。' : '还没有赛事。可以上传办赛材料，或先创建一份草稿。' }}</p>
        <article v-for="row in filteredRows" :key="row.id" class="managed-event-card">
          <OrganizerEventCover :file-id="row.bannerFileId" />
          <div class="managed-event-content"><span>{{ row.publicationStatus === 'published' ? phaseLabel(row.phase) : publicationLabel(row.publicationStatus) }}</span><router-link :to="'/org-desk/workspace/' + row.id"><h2>{{row.name || '未命名赛事'}}</h2></router-link><p>{{showTime(row.startsAt)}} · {{row.location || '地点待完善'}}</p><small>{{row.registrationReview==='none'?'无需人工审核':'人工审核'}}{{row.registrationReviewLocked?' · 设置已锁定':''}}</small><div class="managed-event-primary"><router-link :to="'/org-desk/workspace/' + row.id">进入工作区 →</router-link><button @click="openPreview(row)">预览</button></div><footer><router-link :to="'/org-desk/workspace/'+row.id+'?task=materials'">策划与文稿</router-link><button v-if="canPromote" @click="openPromotion(row)">宣传材料</button><button v-if="canPromote && row.holdingStatus==='normal'" @click="openCover(row)">更换封面</button><button v-if="canPromote && row.publicationStatus==='draft' && row.holdingStatus==='normal'" class="danger" @click="removeDraftEvent(row)">删除草稿</button></footer></div>
        </article>
      </div>
      <el-table v-else :data="filteredRows" v-loading="loading">
        <el-table-column label="名称" min-width="200"
          ><template #default="{ row }"
            ><router-link :to="'/org-desk/workspace/' + row.id"
              ><el-button link type="primary">{{ row.name || '未命名赛事' }}</el-button></router-link
            ></template
          ></el-table-column
        >
        <el-table-column label="发布状态" width="100">
          <template #default="{ row }">{{ publicationLabel(row.publicationStatus) }}</template>
        </el-table-column>
        <el-table-column label="举办" width="100">
          <template #default="{ row }">{{ row.holdingStatus === 'cancelled' ? '已取消' : '正常' }}</template>
        </el-table-column>
        <el-table-column label="报名／比赛阶段" width="120">
          <template #default="{ row }">{{ phaseLabel(row.phase) }}</template>
        </el-table-column>
        <el-table-column label="审核方式" min-width="180">
          <template #default="{ row }">
            {{ row.registrationReview === 'none' ? '无需审核' : '人工审核' }}
            <span v-if="row.registrationReviewLocked">（已锁定）</span>
            <el-button
              v-if="eventKey && !row.registrationReviewLocked && row.holdingStatus === 'normal'"
              link
              type="primary"
              @click="switchReview(row)"
            >
              {{ row.registrationReview === 'none' ? '改为人工审核' : '改为无需审核' }}
            </el-button>
          </template>
        </el-table-column>
        <el-table-column label="操作" min-width="250" fixed="right">
          <template #default="{ row }">
            <router-link v-if="!eventKey" :to="'/org-desk/workspace/' + row.id"><el-button link type="primary">工作区</el-button></router-link>
            <el-button v-if="canPromote && row.publicationStatus === 'draft' && row.holdingStatus === 'normal'" link type="danger" @click="removeDraftEvent(row)">删除草稿</el-button>
            <el-button v-if="canPromote" link type="primary" @click="openPromotion(row)">宣传材料</el-button>
            <el-button v-if="canPromote && row.holdingStatus === 'normal'" link type="primary" @click="openCover(row)">更换封面</el-button>
            <el-button link type="primary" @click="openPreview(row)">预览</el-button>
            <el-button v-if="eventKey && row.editable" link type="primary" @click="openEdit(row)">编辑</el-button>
            <el-button
              v-if="eventKey && row.publicationStatus !== 'published' && row.holdingStatus === 'normal'"
              link
              type="primary"
              @click="publish(row)"
              >{{ row.publicationStatus === 'offline' ? '恢复公开' : '首次发布' }}</el-button
            >
            <el-button v-if="eventKey && canOffline(row)" link @click="offline(row)">下架</el-button>
            <el-button
              v-if="
                eventKey &&
                row.holdingStatus === 'normal' &&
                row.phase !== 'finished' &&
                (row.publicationStatus === 'published' || row.publicationStatus === 'offline')
              "
              link
              type="danger"
              @click="cancel(row)"
              >取消</el-button
            >
            <el-button v-if="row.holdingStatus === 'cancelled'" link type="primary" @click="openNotices(row)">取消通知</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <el-card v-if="mode === 'notifications'" shadow="never"
      ><template #header>取消通知投递</template>
      <p class="b-muted">站内信、短信回执与退款状态分别记录。查询失败不表示没有收件人。</p>
      <el-button @click="loadNotices">刷新投递记录</el-button>
      <p v-if="noticeError">{{ noticeError }}</p>
      <el-table :data="deliveries"
        ><el-table-column prop="channel" label="渠道" /><el-table-column prop="attempt" label="次数" /><el-table-column
          prop="status"
          label="状态"
        /><el-table-column prop="failureReason" label="原因" min-width="180" /><el-table-column label="操作" width="110"
          ><template #default="{ row }"
            ><el-button v-if="row.channel === 'sms' && row.status === 'failed'" link type="primary" @click="retrySms(row)"
              >重试短信</el-button
            ></template
          ></el-table-column
        ></el-table
      ></el-card
    >
    <el-dialog v-model="coverVisible" title="赛事封面" width="620px" class="b-dialog" append-to-body destroy-on-close>
      <EventCoverSettings v-if="coverRow" :event-id="coverRow.id" :initial-file-id="coverRow.bannerFileId" @saved="coverSaved" />
    </el-dialog>
    <el-dialog class="b-dialog" v-model="noticeVisible" title="取消通知投递" width="720px">
      <p>站内信送达不等于短信送达。短信未接通时，重试仍会记为失败。</p>
      <el-table :data="deliveries">
        <el-table-column prop="channel" label="渠道" width="100" />
        <el-table-column prop="attempt" label="次数" width="80" />
        <el-table-column prop="status" label="状态" width="120" />
        <el-table-column prop="failureReason" label="失败原因" min-width="180" />
        <el-table-column label="操作" width="120">
          <template #default="{ row }">
            <el-button v-if="row.channel === 'sms' && row.status === 'failed'" link type="primary" @click="retrySms(row)">重试短信</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-dialog>

    <el-dialog class="b-dialog" v-model="visible" :title="editingId ? '编辑赛事' : '新建赛事'" width="640px">
      <el-form label-position="top">
        <el-form-item label="名称">
          <el-input v-model="form.name" maxlength="200" />
        </el-form-item>
        <el-form-item label="地点">
          <el-input v-model="form.location" maxlength="200" />
        </el-form-item>
        <el-form-item label="运动项目说明（发布必填）">
          <el-input v-model="form.projectName" maxlength="200" placeholder="例如：羽毛球" />
          <p class="b-muted">这是赛事公开介绍；具体单打、双打等报名项目在“项目与费用”配置。</p>
        </el-form-item>
        <el-form-item label="公开收费说明（发布必填）">
          <el-input
            v-model="form.feeDescription"
            type="textarea"
            maxlength="1000"
            placeholder="例如：部分项目免费，部分项目收费，具体以各项目报名费用为准。"
          />
          <p class="b-muted">这是参赛者看到的总体说明，不能代替各报名项目的实际收费配置。</p>
        </el-form-item>
        <el-form-item label="报名开始">
          <el-date-picker v-model="form.registrationOpensAt" type="datetime" value-format="YYYY-MM-DD HH:mm:ss" />
        </el-form-item>
        <el-form-item label="赛事联系人（发布前需确认公开）"><el-input v-model="form.contactName" maxlength="100" :disabled="materialsLocked" /></el-form-item>
        <el-form-item label="赛事联系方式（发布前需确认公开）"><el-input v-model="form.contactMethod" maxlength="240" :disabled="materialsLocked" /></el-form-item>
        <el-form-item label="退赛与退款说明"><el-input v-model="form.refundTerms" type="textarea" maxlength="4000" :disabled="materialsLocked" /><p class="b-muted">请写明退赛、赛事取消时的办理条件。发布后将冻结本场承诺。</p></el-form-item>
        <el-form-item label="报名结束">
          <el-date-picker v-model="form.registrationClosesAt" type="datetime" value-format="YYYY-MM-DD HH:mm:ss" />
        </el-form-item>
        <el-form-item label="开赛">
          <el-date-picker v-model="form.startsAt" type="datetime" value-format="YYYY-MM-DD HH:mm:ss" />
        </el-form-item>
        <el-form-item label="结束">
          <el-date-picker v-model="form.endsAt" type="datetime" value-format="YYYY-MM-DD HH:mm:ss" />
        </el-form-item>
        <el-form-item label="赛事封面（可选）">
          <EventCoverEditor v-model="form.bannerFileId" :event-id="editingId || undefined" />
        </el-form-item>
        <el-form-item label="竞赛规程（文字或图片，可同时留）">
          <el-input v-model="form.rulesText" type="textarea" maxlength="4000" :disabled="materialsLocked" />
          <input
            :disabled="materialsLocked"
            type="file"
            accept="image/jpeg,image/png,image/webp"
            @change="pickImage('rules', 'event-rules', $event)"
          />
          <img v-if="previews.rules" :src="previews.rules" alt="竞赛规程" class="preview" />
        </el-form-item>
        <el-form-item label="报名须知（文字或图片，可同时留）">
          <el-input v-model="form.noticeText" type="textarea" maxlength="4000" :disabled="materialsLocked" />
          <input
            :disabled="materialsLocked"
            type="file"
            accept="image/jpeg,image/png,image/webp"
            @change="pickImage('notice', 'event-notice', $event)"
          />
          <img v-if="previews.notice" :src="previews.notice" alt="报名须知" class="preview" />
        </el-form-item>
        <el-form-item label="参赛声明（文字或图片，可同时留）">
          <el-input v-model="form.declarationText" type="textarea" maxlength="4000" :disabled="materialsLocked" />
          <input
            :disabled="materialsLocked"
            type="file"
            accept="image/jpeg,image/png,image/webp"
            @change="pickImage('declaration', 'event-declaration', $event)"
          />
          <img v-if="previews.declaration" :src="previews.declaration" alt="参赛声明" class="preview" />
          <p class="b-muted">免责声明、反兴奋剂声明可以写在这里。勾选后，每位参赛者都要自己点确认，队长不能代点。</p>
          <el-checkbox v-model="form.declarationAckRequired" :disabled="materialsLocked">报名时需要本人确认这段声明</el-checkbox>
        </el-form-item>
        <el-form-item label="比赛地点 / 路线（文字或图片）">
          <p>地图嵌入需要地图服务商账号和选点，本期先用文字或图片。地点短句仍填在上面的「地点」。</p>
          <el-input v-model="form.routeText" type="textarea" maxlength="4000" :disabled="materialsLocked" />
          <input
            :disabled="materialsLocked"
            type="file"
            accept="image/jpeg,image/png,image/webp"
            @change="pickImage('route', 'event-route', $event)"
          />
          <img v-if="previews.route" :src="previews.route" alt="路线" class="preview" />
        </el-form-item>
        <p v-if="materialsLocked">已有正式报名，规程、须知、声明和路线不能再改。宣传图仍可更换。</p>
        <el-form-item label="审核方式">
          <el-radio-group v-model="form.registrationReview">
            <el-radio value="manual">人工审核</el-radio>
            <el-radio value="none">无需审核</el-radio>
          </el-radio-group>
          <p>首笔正式报名提交后不能再改。免费会在提交通过后直接取得资格，收费要等承办方确认到账后再自动通过。</p>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="visible = false">关闭</el-button>
        <el-button type="primary" :loading="saving" @click="save">保存</el-button>
      </template>
    </el-dialog>
    <el-drawer v-model="previewVisible" title="参赛者页面预览 · 仅内部" size="min(1200px, calc(100vw - 24px))" class="b-drawer b-event-drawer" append-to-body :close-on-click-modal="true"
      ><template v-if="previewRow"
        ><p class="b-muted">按当前组织管理数据预览，草稿与下架赛事不会因此公开。</p>
        <el-radio-group v-model="previewMode"
          ><el-radio-button value="desktop">电脑详情</el-radio-button><el-radio-button value="mobile">手机详情</el-radio-button
          ><el-radio-button value="card">首页卡片</el-radio-button></el-radio-group
        >
        <div class="consumer-app b-consumer-preview" :class="{ 'is-mobile': previewMode === 'mobile' }">
          <PublicEventCard
            v-if="previewMode === 'card'"
            :event="previewRow"
            preview
            :banner-override="previewImages.banner || ''"
            style="max-width: 360px"
          /><EventDetailContent v-else :event="previewRow" :fees="previewFees" :fee-error="previewFeesError" :media="previewImages" preview />
        </div>
        <router-link v-if="previewRow.publicationStatus === 'published'" :to="'/public/events/' + previewRow.id"
          ><el-button>查看公开详情</el-button></router-link
        ></template
      ></el-drawer
    >
    <el-drawer v-model="promotionVisible" title="AI 宣传工作室" size="min(1000px, calc(100vw - 24px))" class="b-drawer b-event-drawer" append-to-body :close-on-click-modal="true">
      <PromotionBoard v-if="promotionVisible && promotionId" :event-id="promotionId" />
    </el-drawer>
    <el-dialog v-model="publishVisible" title="确认公开赛事" width="520px" class="b-dialog" :close-on-click-modal="!publishing">
      <el-form label-position="top">
        <el-form-item label="承办组织"><el-input :model-value="publishContact.organizationName" readonly /></el-form-item>
        <el-form-item label="公开联系人"><el-input v-model="publishContact.contactName" maxlength="100" :readonly="publishRow?.publicationStatus === 'offline' && !!publishContact.frozen" /></el-form-item>
        <el-form-item label="公开联系方式"><el-input v-model="publishContact.contactMethod" maxlength="240" :readonly="publishRow?.publicationStatus === 'offline' && !!publishContact.frozen" /></el-form-item>
        <el-form-item label="本场退改说明"><el-input :model-value="publishContact.refundTerms" type="textarea" :rows="4" readonly /><p class="b-muted">如需调整，请取消发布并返回赛事设置修改。</p></el-form-item>
        <p class="b-muted event-publish-note">首次发布会冻结联系信息。组织资料变化不会覆盖这场赛事的公开依据。项目费用以已确认的收费配置为准。</p>
        <el-checkbox v-model="publishConsent" class="event-publish-consent">我已核对赛事、费用和退改内容，并同意公开上述联系信息</el-checkbox>
      </el-form>
      <template #footer><el-button :disabled="publishing" @click="publishVisible = false">取消</el-button><el-button type="primary" :loading="publishing" :disabled="!publishConsent || !publishContact.contactName.trim() || !publishContact.contactMethod.trim()" @click="confirmPublish">确认发布</el-button></template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts" name="SportsEventIndex">
import EventDetailContent, { type PublicFees } from '@/components/consumer/EventDetailContent.vue';
import PublicEventCard from '@/components/consumer/PublicEventCard.vue';
import PromotionBoard from '@/components/business/PromotionBoard.vue';
import EventCoverEditor from '@/components/business/EventCoverEditor.vue';
import EventCoverSettings from '@/components/business/EventCoverSettings.vue';
import OrganizerEventCover from '@/components/business/OrganizerEventCover.vue';
import type { DeskContext } from '@/api/sports/desk';
import { businessTime } from '@/utils/business';
import { newRequestKey } from '@/utils/requestKey';
import { computed, inject, onMounted, onUnmounted, reactive, ref, watch, type Ref } from 'vue';
import { businessAiKey, businessRevisionKey } from '@/utils/businessAi';
import { businessPickerTime } from '@/utils/business';
import { useRouter } from 'vue-router';

import request from '@/utils/request';
import { ElMessage, ElMessageBox } from 'element-plus';
import { uploadOrganizerImage } from '@/api/sports/media';
import {
  cancelEvent,
  changeRegistrationReview,
  createEvent,
  EventCard,
  EventDraft,
  listManagedEvents,
  offlineEvent,
  phaseLabel,
  publicationLabel,
  showTime,
  publishEvent,
  updateEvent,
  deleteEventDraft
} from '@/api/sports/event';

const props = withDefaults(defineProps<{ eventKey?: string; mode?: string }>(), { mode: 'list' });
const desk = inject<Ref<DeskContext | undefined>>('deskContext');
const canPromote = computed(() => desk?.value?.organize !== false);
const emit = defineEmits<{ changed: [] }>();
const router = useRouter();
const aiCommand = inject(businessAiKey, undefined);
const revision = inject(businessRevisionKey, ref(0));
const goFromDocument = () => (aiCommand ? aiCommand('AI办赛') : router.push('/org-desk/events/from-document'));
const query = ref(''),
  stage = ref('all'),
  loading = ref(false),
  loadError = ref(''),
  noticeError = ref('');
const rows = ref<EventCard[]>([]);
const coverVisible=ref(false),coverRow=ref<EventCard>();
const openCover=(row:EventCard)=>{coverRow.value=row;coverVisible.value=true;};
const coverSaved=async()=>{coverVisible.value=false;await load();emit('changed');};
const filteredRows = computed(() =>
  rows.value.filter(
    (r) =>
      (!props.eventKey || r.id === props.eventKey) &&
      (!query.value || r.name?.includes(query.value)) &&
      (stage.value === 'all' || (stage.value === 'cancelled' ? r.holdingStatus === 'cancelled' : r.phase === stage.value))
  )
);
const previewVisible = ref(false),
  previewRow = ref<EventCard>(),
  previewImages = reactive<Record<string, string>>({});
const materialSlots: { key: string; label: string; text: keyof EventCard; file: keyof EventCard }[] = [
  { key: 'banner', label: '宣传图', text: 'name', file: 'bannerFileId' },
  { key: 'rules', label: '竞赛规程', text: 'rulesText', file: 'rulesFileId' },
  { key: 'notice', label: '报名须知', text: 'noticeText', file: 'noticeFileId' },
  { key: 'declaration', label: '参赛声明', text: 'declarationText', file: 'declarationFileId' },
  { key: 'route', label: '地点与路线', text: 'routeText', file: 'routeFileId' }
];
const previewMode = ref('desktop'),
  previewFees = ref<PublicFees>(),
  previewFeesError = ref('');
const clearPreview = () => {
  Object.values(previewImages).forEach(URL.revokeObjectURL);
  Object.keys(previewImages).forEach((k) => delete previewImages[k]);
};
const promotionVisible = ref(false);
const promotionId = ref('');
const openPromotion = (row: EventCard) => {
  promotionId.value = row.id;
  promotionVisible.value = true;
};
const openPreview = async (row: EventCard) => {
  clearPreview();
  previewRow.value = row;
  previewVisible.value = true;
  previewFees.value = undefined;
  previewFeesError.value = '';
  try {
    const res = await request({ url: '/sports/b/events/' + row.id + '/preview-fees', method: 'get' });
    if (previewRow.value?.id === row.id) previewFees.value = res.data;
  } catch {
    previewFeesError.value = '预览价格与联系信息读取失败，请重试；不把缺价格当免费。';
  }
  await Promise.all(
    materialSlots.map(async (m) => {
      const id = row[m.file];
      if (!id) return;
      try {
        const blob = (await request({ url: '/sports/b/media/' + id, method: 'get', responseType: 'blob' })) as unknown as Blob;
        if (previewRow.value?.id === row.id && previewVisible.value) previewImages[m.key] = URL.createObjectURL(blob);
      } catch {
        /* 失败提示保留在对应图片位置。 */
      }
    })
  );
};
const loadNotices = async () => {
  noticeError.value = '';
  deliveries.value = [];
  noticeEventId.value = props.eventKey || noticeEventId.value;
  if (!noticeEventId.value) return;
  try {
    const res = await request({ url: '/sports/b/events/' + noticeEventId.value + '/notices', method: 'get' });
    deliveries.value = res.data || [];
  } catch {
    noticeError.value = '通知投递记录读取失败，请重试。';
  }
};
onUnmounted(() => {
  clearPreview();
  Object.values(previews).forEach(URL.revokeObjectURL);
});
const noticeVisible = ref(false);
const noticeEventId = ref('');
const deliveries = ref<{ notificationId: string; channel: string; attempt: number; status: string; failureReason: string }[]>([]);
const visible = ref(false);
const editingId = ref('');
const form = reactive<EventDraft>({
  name: '',
  location: '',
  projectName: '',
  feeDescription: '',
  contactName: '', contactMethod: '', refundTerms: '',
  registrationOpensAt: '',
  registrationClosesAt: '',
  startsAt: '',
  endsAt: '',
  registrationReview: 'manual',
  bannerFileId: null,
  rulesText: '',
  rulesFileId: null,
  noticeText: '',
  noticeFileId: null,
  declarationText: '',
  declarationFileId: null,
  declarationAckRequired: false,
  routeText: '',
  routeFileId: null
});
const materialsLocked = ref(false);
const previews = reactive<Record<string, string>>({});

const openNotices = async (row: EventCard) => {
  noticeEventId.value = row.id;
  const res = await request({ url: '/sports/b/events/' + row.id + '/notices', method: 'get' });
  deliveries.value = res.data || [];
  noticeVisible.value = true;
};

const retrySms = async (row: { notificationId: string }) => {
  await request({ url: '/sports/b/events/notices/' + row.notificationId + '/retry-sms', method: 'post' });
  ElMessage.success('已提交短信重试，结果以投递记录为准');
  const res = await request({ url: '/sports/b/events/' + noticeEventId.value + '/notices', method: 'get' });
  deliveries.value = res.data || [];
};

const load = async () => {
  loading.value = true;
  loadError.value = '';
  try {
    const res = await listManagedEvents();
    rows.value = res.data;
    if (props.mode === 'notifications') await loadNotices();
  } catch {
    rows.value = [];
    loadError.value = '赛事读取失败，请刷新重试。';
  } finally {
    loading.value = false;
  }
};

const blankForm = () => {
  form.name = '';
  form.location = '';
  form.projectName = '';
  form.feeDescription = '';
  form.contactName = ''; form.contactMethod = ''; form.refundTerms = '';
  form.registrationOpensAt = '';
  form.registrationClosesAt = '';
  form.startsAt = '';
  form.endsAt = '';
  form.registrationReview = 'manual';
  form.bannerFileId = null;
  form.rulesText = '';
  form.rulesFileId = null;
  form.noticeText = '';
  form.noticeFileId = null;
  form.declarationText = '';
  form.declarationFileId = null;
  form.declarationAckRequired = false;
  form.routeText = '';
  form.routeFileId = null;
  Object.keys(previews).forEach((key) => {
    URL.revokeObjectURL(previews[key]);
    delete previews[key];
  });
};

const pickImage = async (slot: string, purpose: string, event: Event) => {
  const file = (event.target as HTMLInputElement).files?.[0];
  if (!file) {
    return;
  }
  const res = await uploadOrganizerImage(purpose, file);
  const fileId = res.data.fileId as string;
  if (slot === 'banner') form.bannerFileId = fileId;
  if (slot === 'rules') form.rulesFileId = fileId;
  if (slot === 'notice') form.noticeFileId = fileId;
  if (slot === 'declaration') form.declarationFileId = fileId;
  if (slot === 'route') form.routeFileId = fileId;
  if (previews[slot]) URL.revokeObjectURL(previews[slot]);
  previews[slot] = URL.createObjectURL(file);
};

const openCreate = () => {
  editingId.value = '';
  materialsLocked.value = false;
  blankForm();
  visible.value = true;
};

const openEdit = async (row: EventCard) => {
  blankForm();
  editingId.value = row.id;
  form.name = row.name || '';
  form.location = row.location || '';
  form.projectName = row.projectName || '';
  form.feeDescription = row.feeDescription || '';
  form.contactName = row.contactName || ''; form.contactMethod = row.contactMethod || ''; form.refundTerms = row.refundTerms || '';
  form.registrationOpensAt = toPicker(row.registrationOpensAt);
  form.registrationClosesAt = toPicker(row.registrationClosesAt);
  form.startsAt = toPicker(row.startsAt);
  form.endsAt = toPicker(row.endsAt);
  form.registrationReview = row.registrationReview || 'manual';
  form.bannerFileId = row.bannerFileId;
  form.rulesText = row.rulesText || '';
  form.rulesFileId = row.rulesFileId;
  form.noticeText = row.noticeText || '';
  form.noticeFileId = row.noticeFileId;
  form.declarationText = row.declarationText || '';
  form.declarationFileId = row.declarationFileId;
  form.declarationAckRequired = Boolean(row.declarationAckRequired);
  form.routeText = row.routeText || '';
  form.routeFileId = row.routeFileId;
  materialsLocked.value = row.registrationReviewLocked;
  visible.value = true;
  await Promise.all(
    materialSlots.map(async (item) => {
      const id = row[item.file];
      if (!id) return;
      try {
        const blob = (await request({ url: '/sports/b/media/' + id, method: 'get', responseType: 'blob' })) as unknown as Blob;
        if (editingId.value === row.id && visible.value) previews[item.key] = URL.createObjectURL(blob);
      } catch {
        /* 已保存引用保留，不把加载失败当成未上传。 */
      }
    })
  );
};

const switchReview = async (row: EventCard) => {
  const next = row.registrationReview === 'none' ? 'manual' : 'none';
  await changeRegistrationReview(row.id, next);
  ElMessage.success(next === 'none' ? '已改为无需审核' : '已改为人工审核');
  await load();
  emit('changed');
};

const toPicker = businessPickerTime;

const saving = ref(false);
const save = async () => {
  if (saving.value) return;
  saving.value = true;
  try {
    if (editingId.value) await updateEvent(editingId.value, form);
    else await createEvent(form);
    ElMessage.success('已保存');
    visible.value = false;
    await load();
    emit('changed');
  } finally {
    saving.value = false;
  }
};

const publishVisible = ref(false), publishConsent = ref(false), publishing = ref(false), publishRow = ref<EventCard>();
const publishContact = reactive({ organizationName: '', contactName: '', contactMethod: '', refundTerms: '', frozen: false });
let publishRequestKey = '';
const confirmPublish = async () => {
  if (!publishRow.value || !publishConsent.value || publishing.value) return;
  publishing.value = true;
  try {
    await publishEvent(publishRow.value.id, publishRequestKey, publishContact.contactName.trim(), publishContact.contactMethod.trim());
    publishVisible.value = false;
    ElMessage.success('已发布');
    await load();
    emit('changed');
  } catch {
    // 请求层已显示失败；保留核对内容和同一请求键，避免事件回调产生未处理拒绝。
  } finally { publishing.value = false; }
};

const publish = async (row: EventCard) => {
  const missing = [!row.projectName?.trim() && '运动项目说明', !row.feeDescription?.trim() && '公开收费说明'].filter(Boolean);
  if (missing.length) {
    try {
      await ElMessageBox.alert(`基础信息仍缺少：${missing.join('、')}。它们与“项目与费用”里的报名项目及价格分开填写。`, '请先补全发布信息', {
        confirmButtonText: '补全基础信息'
      });
      openEdit(row);
    } catch {
      /* 关闭提示时不写入或发布。 */
    }
    return;
  }
  try {
    const response = await request({ url: '/sports/b/events/' + row.id + '/preview-fees', method: 'get' });
    publishRow.value = row;
    Object.assign(publishContact, { organizationName: response.data.organizationName || '', contactName: response.data.contactName || '', contactMethod: response.data.contactMethod || '', refundTerms: response.data.refundNote || '', frozen: response.data.contactFrozen === true });
    publishConsent.value = false;
    publishRequestKey = newRequestKey();
    publishVisible.value = true;
  } catch {
    // 预览不可用时不能猜测联系人或打开可发布状态，失败由请求层提示。
  }
};

const canOffline = (row: EventCard) =>
  row.publicationStatus === 'published' &&
  row.holdingStatus === 'normal' &&
  (row.phase === 'pre_registration' || row.phase === 'registration' || row.phase === 'registration_closed');

const offline = async (row: EventCard) => {
  try {
    await ElMessageBox.confirm('下架后公开页立即看不到这场赛事。已经提交的报名保持原样，不会撤回。可以再编辑，重新发布会重新校验。', '下架赛事');
  } catch {
    return;
  }
  await offlineEvent(row.id);
  ElMessage.success('已下架');
  await load();
  emit('changed');
};

const removeDraftEvent = async (row: EventCard) => {
  if (row.publicationStatus !== 'draft' || row.holdingStatus !== 'normal') return;
  try {
    await ElMessageBox.confirm('将删除这场尚未发布的办赛草稿及其项目、费用和收款设置。已有报名、资金或发布记录时不会删除。', '删除办赛草稿', {
      confirmButtonText: '删除草稿',
      cancelButtonText: '留下',
      type: 'warning'
    });
  } catch {
    return;
  }
  try {
    await deleteEventDraft(row.id);
    ElMessage.success('已删除办赛草稿');
    await load();
    emit('changed');
  } catch {
    // 请求层已显示失败原因。
  }
};

const cancel = async (row: EventCard) => {
  let reason = '';
  try {
    const result = await ElMessageBox.prompt('取消后不能恢复，停止新增报名与现场执行，历史保留；退款与通知分别处理。原因可以不填。', '取消赛事', {
      confirmButtonText: '确认取消',
      cancelButtonText: '返回',
      inputPlaceholder: '取消原因，可空'
    });
    reason = result.value || '';
  } catch {
    return;
  }
  await cancelEvent(row.id, reason);
  ElMessage.success('已取消');
  await load();
  emit('changed');
};

onMounted(load);
watch(revision, () => {
  if (props.mode !== 'controls') load();
});
defineExpose({ openCreate, openEdit, openPreview, switchReview });
</script>
<style scoped lang="scss">
.event-publish-note,.event-publish-consent{grid-column:1/-1;min-width:0;}.event-publish-consent{height:auto;max-width:100%;margin-right:0;white-space:normal;align-items:flex-start;:deep(.el-checkbox__input){margin-top:5px;}:deep(.el-checkbox__label){min-width:0;white-space:normal;line-height:1.7;overflow:visible;text-overflow:clip;}}
.managed-event-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:22px;}.managed-event-empty{grid-column:1/-1;color:var(--s-muted);text-align:center;padding:60px 15px;font-size:13px;line-height:1.8;}.managed-event-card{overflow:hidden;border-radius:24px;border:1px solid var(--s-line);background:var(--s-surface);transition:transform .25s,box-shadow .25s;:deep(.organizer-cover){height:190px;min-height:190px;border-radius:0;} &:hover{transform:translateY(-3px);box-shadow:0 12px 28px #20232109;}}.managed-event-content{padding:22px 20px 15px;>span{font-size:10px;color:var(--s-primary);background:#fff1e9;padding:5px 9px;border-radius:7px;display:inline-block;}h2{font-size:20px;letter-spacing:-.5px;line-height:1.45;margin:15px 0 12px;}p{font-size:12px;color:var(--s-muted);line-height:1.7;margin:0 0 9px;}small{font-size:11px;color:var(--s-muted);}>footer{border-top:1px solid var(--s-line);display:flex;gap:15px;flex-wrap:wrap;padding-top:14px;margin-top:20px;font-size:11px;color:var(--s-muted);button{background:none;border:0;padding:0;cursor:pointer;font:inherit;color:inherit;&.danger{color:#a34c3e;}}}}.managed-event-primary{display:flex;justify-content:space-between;align-items:center;margin-top:22px;font-size:12px;>a{color:var(--s-primary);font-weight:650;}button{border:0;border-radius:10px;background:var(--s-paper);padding:9px 13px;font:inherit;color:var(--s-muted);cursor:pointer;}}@media(max-width:600px){.managed-event-grid{grid-template-columns:1fr;gap:18px;}.managed-event-card :deep(.organizer-cover){height:auto;aspect-ratio:16/9;}.managed-event-content{padding:20px 17px;}}@media(prefers-reduced-motion:reduce){.managed-event-card{transition:none;&:hover{transform:none;}}}
</style>
