<template>
  <div>
    <section v-if="loading" class="b-state">正在读取赛事…</section>
    <section v-else-if="error" class="b-state">
      <h2>暂时无法查看赛事</h2>
      <p>{{ error }}</p>
      <el-button @click="load">重试</el-button><router-link to="/org-desk/events"><el-button>返回赛事列表</el-button></router-link>
    </section>
    <template v-else-if="event"
      ><div class="b-heading">
        <div>
          <span class="b-eyebrow">赛事工作区</span>
          <h1>{{ event.name || '未命名赛事' }}</h1>
          <p>{{ event.location || '地点待填写' }} · {{ event.startsAt?.slice(0, 10) || '时间待填写' }}</p>
        </div>
        <div class="b-actions"><el-button @click="eventTools?.openPreview(event)">预览参赛者页面</el-button><router-link v-if="event.publicationStatus === 'published'" :to="'/public/events/' + event.id"><el-button>打开公开页面</el-button></router-link><router-link to="/org-desk/events"><el-button>返回赛事列表</el-button></router-link></div>
      </div>
      <section class="b-panel b-context">
        <div class="b-toolbar" style="margin: 0">
          <span>发布状态：</span><el-tag>{{ publicationLabel(event.publicationStatus) }}</el-tag
          ><span>报名／比赛阶段：</span><el-tag :type="stopped ? 'warning' : 'success'">{{ event.holdingStatus === 'cancelled' ? '已取消' : phaseLabel(event.phase) }}</el-tag
          ><span class="b-muted"
            >审核方式：{{ event.registrationReview === 'none' ? '无需人工审核' : '人工审核' }}{{ event.registrationReviewLocked ? ' · 已锁定' : '' }}</span
          >
        </div>
        <el-button @click="load">刷新赛事状态</el-button>
      </section>
      <el-alert v-if="stopped" title="已停止新增报名和现场操作，仍可查看名单、赛果并处理资金。" type="warning" :closable="false" />
      <nav class="b-task-tabs" aria-label="赛事任务">
        <router-link
          v-for="item in tasks"
          :key="item.key"
          :to="{ path: route.path, query: { task: item.key } }"
          :class="{ active: task === item.key }"
          >{{ item.label }}</router-link
        >
      </nav>
      <template v-if="task === 'overview'"
        ><section class="b-panel sport-art-ribbon">
          <div class="b-toolbar"><h3>基础信息</h3><el-button v-if="event.editable" @click="eventTools?.openEdit(event)">编辑基础信息</el-button></div>
          <div class="b-grid">
            <div class="b-stat">
              <span>报名截止（北京时间）</span>
              <h3>{{ businessTime(event.registrationClosesAt) }}</h3>
            </div>
            <div class="b-stat">
              <span>举办时间</span>
              <h3>{{ businessTime(event.startsAt) }}</h3>
            </div>
            <div>
              <span class="b-muted">运动项目说明（发布必填）</span>
              <h3>{{ event.projectName || '未填写' }}</h3>
            </div>
          </div>
          <p>{{ event.feeDescription || '未填写公开收费说明（发布必填），请编辑基础信息补全。' }}</p>
        </section>
        <section class="b-panel">
          <h3>运营待办</h3>
          <p v-if="summaryError" class="b-muted">{{ summaryError }}<el-button text @click="loadSummary">重试</el-button></p>
          <div v-else class="b-grid">
            <router-link
              v-for="item in counters"
              :key="item.label"
              :to="{ path: route.path, query: { task: 'registrations', filter: item.filter } }"
              class="b-task"
              ><div>
                {{ item.label }}<small>{{ item.note }}</small>
              </div>
              <strong>{{ summaryLoading ? '—' : item.value }}</strong></router-link
            >
          </div>
          <p class="b-muted">数量按整单报名计算，历史与当前办理分开。</p>
        </section>
        <router-link :to="{path: route.path, query: {task: 'publication'}}"><el-button>前往发布管理</el-button></router-link></template>
      <RegistrationReview
        v-else-if="task === 'projects' || task === 'registrations'"
        :key="event.id + task"
        :event-key="event.id"
        :mode="task"
        :event-stopped="stopped"
        :pricing-locked="event.registrationReviewLocked"
        :approval-closed="stopped || event.phase === 'ongoing'"
      />
      <div v-else-if="task === 'fields'"><EventPaymentSettings :event-key="event.id" :locked="event.registrationReviewLocked || stopped" /><section class="b-panel"><h3>报名设置</h3><p>报名截止：{{ businessTime(event.registrationClosesAt) }} <el-button v-if="event.editable" link @click="eventTools?.openEdit(event)">编辑时间</el-button></p><p>审核方式：{{event.registrationReview === 'none' ? '无需人工审核' : '人工审核'}} <el-button v-if="!event.registrationReviewLocked && !stopped" @click="eventTools?.switchReview(event)">调整审核方式</el-button><span v-else>首次正式提交后锁定，或赛事已停止办理。</span></p><FieldPanel :event-key="event.id" :locked="event.registrationReviewLocked || stopped"/></section></div>
      <Competition
        v-else-if="['checkin', 'matches', 'awards'].includes(task)"
        :key="event.id + task"
        :event-key="event.id"
        :mode="task"
        :event-stopped="stopped"
      />
      <ClosureAndFixtures v-else-if="task === 'closure'" :event-key="event.id" />
      <EventMaterialStudio v-else-if="task === 'materials'" :key="event.id" :event-id="event.id" />
      <EventManage
        v-else-if="task === 'publication' || task === 'notifications'"
        :key="event.id + task"
        :event-key="event.id"
        :mode="task"
        @changed="load"
      />
      <EventManage ref="eventTools" :event-key="event.id" mode="controls" @changed="load"/>
    </template>
  </div>
</template>
<script setup lang="ts">
import { businessTime } from '@/utils/business';
import { computed, inject, onMounted, ref, type Ref, watch } from 'vue';
import { businessRevisionKey } from '@/utils/businessAi';
import { useRoute, type RouteLocationNormalized } from 'vue-router';
import { useTagsViewStore } from '@/store/modules/tagsView';
import { listManagedEvents, phaseLabel, publicationLabel, type EventCard } from '@/api/sports/event';
import { listManagedUnits, listUnitEntries, type EntryCard } from '@/api/sports/registration';
import type { DeskContext } from '@/api/sports/desk';
import RegistrationReview from '@/views/sports/registration/review.vue';
import Competition from '@/views/sports/competition/index.vue';
import FieldPanel from '@/views/sports/field/index.vue';
import EventManage from '@/views/sports/event/index.vue';
import EventPaymentSettings from '@/components/business/EventPaymentSettings.vue';
import ClosureAndFixtures from './ClosureAndFixtures.vue';
import EventMaterialStudio from '@/components/business/EventMaterialStudio.vue';
const eventTools = ref<InstanceType<typeof EventManage>>();
const route = useRoute(),
  event = ref<EventCard>(),
  loading = ref(true),
  error = ref(''),
  summaryError = ref(''),
  summaryLoading = ref(false),
  entries = ref<EntryCard[]>([]);
const context = inject<Ref<DeskContext | undefined>>('deskContext', ref());
const businessRevision = inject(businessRevisionKey, ref(0));
const tasks = [
  { key: 'overview', label: '概览' },
  { key: 'projects', label: '项目与费用' },
  { key: 'registrations', label: '报名名单' },
  { key: 'fields', label: '赛事设置' },
  { key: 'checkin', label: '赛事报到' },
  { key: 'matches', label: '场次与录分' },
  { key: 'awards', label: '获奖证明' },
  { key: 'closure', label: '场次安排与赛后收尾' },
  { key: 'materials', label: '策划与文稿' },
  { key: 'publication', label: '发布管理' },
  { key: 'notifications', label: '取消通知' }
];
const task = computed(() => (tasks.some((t) => t.key === route.query.task) ? String(route.query.task) : 'overview'));
const stopped = computed(() => event.value?.holdingStatus === 'cancelled' || event.value?.phase === 'finished');
const counters = computed(() => [
  { label: '待审核', filter: 'submitted', value: stopped.value ? 0 : entries.value.filter((e) => e.status === 'submitted').length, note: '资格审核' },
  {
    label: '待核对付款',
    filter: 'declared',
    value: stopped.value ? 0 : entries.value.filter((e) => e.paymentDeclared && e.obligationStatus === 'open').length,
    note: '声明不等于实际到账'
  },
  {
    label: '待资金收尾',
    filter: 'refund',
    value: entries.value.filter((e) => e.pendingActionId).length,
    note: context.value?.payment ? '资金授权可办理' : '需资金授权办理'
  }
]);
const loadSummary = async () => {
  if (!event.value) return;
  summaryLoading.value = true;
  summaryError.value = '';
  const id = event.value.id;
  try {
    const units = await listManagedUnits(id);
    const lists = await Promise.all(units.data.map((u: { id: string }) => listUnitEntries(u.id)));
    if (event.value?.id === id) entries.value = lists.flatMap((r) => r.data);
  } catch {
    summaryError.value = '待办读取失败，不展示估算数量。';
  } finally {
    summaryLoading.value = false;
  }
};
const load = async () => {
  loading.value = true;
  error.value = '';
  event.value = undefined;
  try {
    const res = await listManagedEvents();
    event.value = res.data.find((e: EventCard) => e.id === String(route.params.eventId));
    if (!event.value) error.value = '赛事不存在或当前组织无权访问。';
    else {
      useTagsViewStore().updateVisitedView({ ...route, title: event.value.name || '赛事工作区' } as RouteLocationNormalized);
      await loadSummary();
    }
  } catch {
    error.value = '赛事读取失败，请稍后重试。';
  } finally {
    loading.value = false;
  }
};
onMounted(load);
watch(() => route.params.eventId, load);
watch(businessRevision, load);
watch(
  () => task.value,
  (value) => {
    if (value === 'overview' && event.value) loadSummary();
  }
);
</script>
