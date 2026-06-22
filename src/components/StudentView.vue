<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue'
import {
  currentActiveUser,
  projectsArray,
  applicationsArray,
  userSchedules,
  submitApplication,
  withdrawApplication,
  type Application,
  type Project,
} from '../store/globalState'
import { calculateOverlay, decompressMask } from '../utils/scheduleAlgo'

// ── Tab ───────────────────────────────────────────────────────────────
const activeTab = ref<'explore' | 'myapps'>('explore')

// ── 5x10 Schedule Grid ────────────────────────────────────────────────
const busyCells = ref<Set<string>>(new Set())
const isDragging = ref(false)
const dragSetMode = ref(true) // true = set busy, false = clear

const cellKey = (d: number, p: number) => `${d}-${p}`

function isBusy(d: number, p: number) { return busyCells.value.has(cellKey(d, p)) }

function setCellMode(d: number, p: number) {
  const key = cellKey(d, p)
  if (dragSetMode.value) busyCells.value.add(key)
  else busyCells.value.delete(key)
}

function onMousedown(d: number, p: number) {
  isDragging.value = true
  dragSetMode.value = !busyCells.value.has(cellKey(d, p))
  setCellMode(d, p)
}

function onMouseenter(d: number, p: number) {
  if (isDragging.value) setCellMode(d, p)
}

function onMouseup() { isDragging.value = false }

function selectAll() {
  for (let d = 1; d <= 5; d++)
    for (let p = 1; p <= 10; p++)
      busyCells.value.add(cellKey(d, p))
}

function clearAll() { busyCells.value.clear() }

// Paste binary string (50 chars, LSB first)
const pasteError = ref('')
function onPasteImport(e: Event) {
  const val = (e.target as HTMLInputElement).value.trim()
  if (!/^[01]{50}$/.test(val)) {
    pasteError.value = '格式錯誤：需要恰好 50 個 0 或 1'
    return
  }
  pasteError.value = ''
  busyCells.value.clear()
  for (let i = 0; i < 50; i++) {
    if (val[i] === '1') {
      const d = Math.floor(i / 10) + 1
      const p = (i % 10) + 1
      busyCells.value.add(cellKey(d, p))
    }
  }
  ;(e.target as HTMLInputElement).value = ''
}

// Computed bitmask from grid
const studentMask = computed(() => {
  let mask = 0n
  for (let d = 1; d <= 5; d++)
    for (let p = 1; p <= 10; p++)
      if (busyCells.value.has(cellKey(d, p)))
        mask |= 1n << BigInt((d - 1) * 10 + (p - 1))
  return mask.toString()
})

// Sync grid → userSchedules when cells change
watch(studentMask, (val) => {
  userSchedules[currentActiveUser.value.id] = val
})

// Initialize grid from persisted mask on mount / user switch
onMounted(initGrid)
watch(() => currentActiveUser.value.id, initGrid)

function initGrid() {
  const maskStr = userSchedules[currentActiveUser.value.id] ?? '0'
  const slots = decompressMask(BigInt(maskStr))
  busyCells.value.clear()
  slots.forEach(s => busyCells.value.add(cellKey(s.day, s.period)))
}

// ── Open projects (exclude full / closed) ────────────────────────────
const openProjects = computed(() =>
  projectsArray.filter(p => p.isOpen && p.currentMembers < p.maxMembers)
)

// Per-project application status for current user
function getAppStatus(projectId: number): Application | undefined {
  return applicationsArray
    .filter(a => a.projectId === projectId && a.studentId === currentActiveUser.value.id)
    .sort((a, b) => b.id - a.id)[0]
}

// ── Pre-check Modal ───────────────────────────────────────────────────
const modalOpen = ref(false)
const selectedProject = ref<Project | null>(null)
const preCheckResult = ref<ReturnType<typeof calculateOverlay> | null>(null)
const submitSuccess = ref(false)

function openPreCheck(project: Project) {
  selectedProject.value = project
  preCheckResult.value = calculateOverlay(project.groupScheduleMask, studentMask.value)
  submitSuccess.value = false
  modalOpen.value = true
}

function closeModal() { modalOpen.value = false }

function confirmApply() {
  if (!selectedProject.value) return
  try {
    submitApplication(selectedProject.value.id, currentActiveUser.value.id)
    submitSuccess.value = true
    setTimeout(() => { modalOpen.value = false; submitSuccess.value = false }, 1200)
  } catch { /* DUPLICATE_APPLICATION — already applied */ }
}

function getModalStyle(d: number, p: number): string {
  if (!preCheckResult.value || !selectedProject.value) return 'bg-white border-slate-200'
  const { conflictSlots, goldenSlots } = preCheckResult.value
  if (conflictSlots.some(s => s.day === d && s.period === p))
    return 'bg-red-500 border-red-600 text-white'
  if (goldenSlots.some(s => s.day === d && s.period === p))
    return 'bg-emerald-500 border-emerald-600 text-white'
  const gSlots = decompressMask(BigInt(selectedProject.value.groupScheduleMask))
  if (gSlots.some(s => s.day === d && s.period === p))
    return 'bg-slate-200 border-slate-300 text-slate-500'
  return 'bg-white border-slate-200'
}

function getModalText(d: number, p: number): string {
  if (!preCheckResult.value) return ''
  const { conflictSlots, goldenSlots } = preCheckResult.value
  if (conflictSlots.some(s => s.day === d && s.period === p)) return '衝'
  if (goldenSlots.some(s => s.day === d && s.period === p)) return '空'
  return ''
}

// ── My Applications tab ───────────────────────────────────────────────
const myApps = computed(() =>
  applicationsArray
    .filter(a => a.studentId === currentActiveUser.value.id && a.status !== 'CANCELED')
    .map(a => ({
      app: a,
      project: projectsArray.find(p => p.id === a.projectId),
    }))
    .reverse()
)

const statusLabel: Record<string, string> = {
  PENDING: '審核中',
  ACCEPTED: '已錄取',
  REJECTED: '已拒絕',
  CANCELED: '已撤回',
}
const statusClass: Record<string, string> = {
  PENDING: 'bg-amber-100 text-amber-700',
  ACCEPTED: 'bg-emerald-100 text-emerald-700',
  REJECTED: 'bg-red-100 text-red-700',
  CANCELED: 'bg-slate-100 text-slate-500',
}
</script>

<template>
  <div class="p-6 max-w-6xl mx-auto" @mouseup="onMouseup">

    <!-- Tabs -->
    <div class="flex gap-1 mb-6 bg-white border border-slate-200 rounded-xl p-1 w-fit shadow-sm">
      <button
        v-for="tab in [{ key: 'explore', label: '探索專案' }, { key: 'myapps', label: '我的申請' }]"
        :key="tab.key"
        @click="activeTab = tab.key as 'explore' | 'myapps'"
        :class="[
          'px-5 py-2 text-sm font-semibold rounded-lg transition-all',
          activeTab === tab.key
            ? 'bg-blue-600 text-white shadow'
            : 'text-slate-500 hover:text-slate-700 hover:bg-slate-50',
        ]"
      >
        {{ tab.label }}
        <span
          v-if="tab.key === 'myapps' && myApps.length > 0"
          class="ml-1.5 text-xs bg-white/30 px-1.5 py-0.5 rounded-full"
        >{{ myApps.length }}</span>
      </button>
    </div>

    <!-- ═══════════════════════════════════════════════════════════════ -->
    <!-- TAB: 探索專案 -->
    <!-- ═══════════════════════════════════════════════════════════════ -->
    <div v-if="activeTab === 'explore'" class="grid grid-cols-1 lg:grid-cols-5 gap-6 items-start">

      <!-- 左：課表編輯器 -->
      <div class="lg:col-span-2 bg-white rounded-xl border border-slate-200 shadow-sm p-5">
        <h2 class="text-base font-bold text-slate-800 mb-0.5">我的課表編輯器</h2>
        <p class="text-xs text-slate-400 mb-3">拖曳或點擊格子切換忙碌 / 空閒</p>

        <!-- Batch Buttons -->
        <div class="flex gap-2 mb-3">
          <button @click="selectAll" class="flex-1 text-xs py-1.5 bg-slate-100 hover:bg-slate-200 text-slate-600 font-medium rounded-lg transition-colors">全選</button>
          <button @click="clearAll" class="flex-1 text-xs py-1.5 bg-slate-100 hover:bg-slate-200 text-slate-600 font-medium rounded-lg transition-colors">全清</button>
        </div>

        <!-- Paste Import -->
        <div class="mb-3">
          <input
            type="text"
            maxlength="50"
            placeholder="貼上 50-bit 二進位字串（0/1）..."
            @change="onPasteImport"
            class="w-full text-xs border border-slate-200 rounded-lg px-3 py-1.5 font-mono placeholder:text-slate-300 focus:outline-none focus:ring-2 focus:ring-blue-300"
          />
          <p v-if="pasteError" class="text-xs text-red-500 mt-1">{{ pasteError }}</p>
        </div>

        <!-- Legend -->
        <div class="flex gap-4 text-xs mb-2">
          <div class="flex items-center gap-1.5"><div class="w-3 h-3 bg-blue-600 rounded"></div>有課</div>
          <div class="flex items-center gap-1.5"><div class="w-3 h-3 bg-white border border-slate-300 rounded"></div>空閒</div>
        </div>

        <!-- 5x10 Grid -->
        <div
          class="grid gap-1 select-none"
          style="grid-template-columns: 1.5rem repeat(5, 1fr);"
          @mouseleave="onMouseup"
        >
          <div class="text-xs text-slate-400 text-center font-mono">節</div>
          <div v-for="d in 5" :key="`sh${d}`" class="text-center text-xs font-bold text-slate-700 py-1">
            週{{ ['一','二','三','四','五'][d - 1] }}
          </div>

          <template v-for="p in 10" :key="`srow${p}`">
            <div class="flex items-center justify-center text-xs font-mono text-slate-400 font-bold">{{ p }}</div>
            <div
              v-for="d in 5"
              :key="`s${d}-${p}`"
              @mousedown.prevent="onMousedown(d, p)"
              @mouseenter="onMouseenter(d, p)"
              :class="[
                'h-9 rounded border cursor-pointer transition-all duration-100 text-xs font-bold flex items-center justify-center',
                isBusy(d, p)
                  ? 'bg-blue-600 border-blue-700 text-white'
                  : 'bg-white border-slate-200 text-slate-300 hover:bg-blue-50 hover:border-blue-300',
              ]"
            >
              {{ isBusy(d, p) ? '課' : '' }}
            </div>
          </template>
        </div>

        <!-- Mask Output -->
        <div class="mt-4 pt-3 border-t border-slate-100 space-y-1">
          <p class="text-xs text-slate-500">BigInt 遮罩：</p>
          <p class="font-mono text-xs text-blue-600 break-all bg-slate-50 px-2 py-1.5 rounded">{{ studentMask }}</p>
          <p class="text-xs text-slate-400">已選 {{ busyCells.size }} 個忙碌時段</p>
        </div>
      </div>

      <!-- 右：專案列表 -->
      <div class="lg:col-span-3 space-y-4">
        <h2 class="text-base font-bold text-slate-800 px-1">開放中的專案</h2>

        <div v-if="openProjects.length === 0" class="bg-white rounded-xl border border-slate-200 shadow-sm p-10 text-center">
          <p class="text-slate-400 text-sm">目前沒有開放中的專案</p>
        </div>

        <div
          v-for="project in openProjects"
          :key="project.id"
          class="bg-white rounded-xl border border-slate-200 shadow-sm p-5 hover:border-blue-300 transition-all"
        >
          <div class="flex justify-between items-start gap-2">
            <div>
              <h3 class="font-bold text-slate-800">{{ project.title }}</h3>
              <p class="text-xs text-slate-400 mt-0.5">課程：{{ project.courseCode }} ・ 成員：{{ project.currentMembers }}/{{ project.maxMembers }}</p>
            </div>
            <span class="text-xs px-2 py-0.5 bg-emerald-100 text-emerald-700 rounded-full font-medium shrink-0">招募中</span>
          </div>

          <div class="mt-3">
            <div class="w-full bg-slate-100 h-1.5 rounded-full overflow-hidden">
              <div class="bg-blue-600 h-full rounded-full transition-all duration-300" :style="{ width: (project.currentMembers / project.maxMembers) * 100 + '%' }"></div>
            </div>
          </div>

          <div class="mt-4 flex items-center justify-end gap-2">
            <!-- Apply status badge -->
            <template v-if="getAppStatus(project.id)">
              <span :class="['text-xs font-semibold px-3 py-1.5 rounded-lg', statusClass[getAppStatus(project.id)!.status]]">
                {{ statusLabel[getAppStatus(project.id)!.status] }}
              </span>
            </template>
            <button
              v-if="!getAppStatus(project.id) || getAppStatus(project.id)!.status === 'REJECTED'"
              @click="openPreCheck(project)"
              class="px-4 py-2 text-xs font-semibold text-white bg-blue-600 hover:bg-blue-700 rounded-lg transition-colors"
            >
              申請預檢
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- ═══════════════════════════════════════════════════════════════ -->
    <!-- TAB: 我的申請 -->
    <!-- ═══════════════════════════════════════════════════════════════ -->
    <div v-else class="max-w-2xl">
      <h2 class="text-base font-bold text-slate-800 mb-4">申請紀錄</h2>

      <div v-if="myApps.length === 0" class="bg-white rounded-xl border border-slate-200 shadow-sm p-12 text-center">
        <p class="text-slate-400">還沒有任何申請紀錄</p>
        <button @click="activeTab = 'explore'" class="mt-3 text-sm text-blue-600 hover:underline">去探索專案</button>
      </div>

      <div v-for="{ app, project } in myApps" :key="app.id" class="bg-white rounded-xl border border-slate-200 shadow-sm p-4 mb-3">
        <div class="flex justify-between items-start gap-2">
          <div>
            <h3 class="font-semibold text-slate-800 text-sm">{{ project?.title ?? `專案 #${app.projectId}` }}</h3>
            <p class="text-xs text-slate-400 mt-0.5">{{ project?.courseCode }}</p>
          </div>
          <span :class="['text-xs font-semibold px-2 py-0.5 rounded-full shrink-0', statusClass[app.status]]">
            {{ statusLabel[app.status] }}
          </span>
        </div>

        <!-- Reject reason -->
        <div v-if="app.status === 'REJECTED' && app.rejectReason" class="mt-2 bg-red-50 border border-red-100 rounded-lg px-3 py-2 text-xs text-red-600">
          拒絕原因：{{ app.rejectReason }}
        </div>

        <div class="mt-3 flex justify-between items-center text-xs text-slate-400">
          <span>申請時間：{{ new Date(app.createdAt).toLocaleString('zh-TW') }}</span>
          <button
            v-if="app.status === 'PENDING'"
            @click="withdrawApplication(app.id)"
            class="text-red-500 hover:text-red-700 font-medium transition-colors"
          >撤回申請</button>
        </div>
      </div>
    </div>

    <!-- ═══════════════════════════════════════════════════════════════ -->
    <!-- Pre-check Modal -->
    <!-- ═══════════════════════════════════════════════════════════════ -->
    <Transition name="modal">
      <div
        v-if="modalOpen"
        class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40 backdrop-blur-sm"
        @click.self="closeModal"
      >
        <div class="bg-white rounded-2xl shadow-2xl w-full max-w-2xl overflow-hidden">

          <!-- Success overlay -->
          <Transition name="fade-fast">
            <div v-if="submitSuccess" class="absolute inset-0 z-10 flex flex-col items-center justify-center bg-white/95 rounded-2xl gap-3">
              <div class="text-5xl">✅</div>
              <p class="text-lg font-bold text-emerald-700">申請已送出！</p>
              <p class="text-sm text-slate-400">正在跳轉至我的申請...</p>
            </div>
          </Transition>

          <!-- Header -->
          <div :class="['p-5 flex justify-between items-start border-b', preCheckResult?.hasConflict ? 'bg-red-50 border-red-100' : 'bg-emerald-50 border-emerald-100']">
            <div>
              <h3 class="font-bold text-slate-800 text-lg">申請預檢結果</h3>
              <p class="text-sm text-slate-500 mt-0.5">{{ selectedProject?.title }}</p>
            </div>
            <div class="flex items-center gap-3">
              <span :class="['text-sm font-bold px-3 py-1 rounded-full', preCheckResult?.hasConflict ? 'bg-red-100 text-red-700' : 'bg-emerald-100 text-emerald-700']">
                {{ preCheckResult?.hasConflict ? '⚠️ 時間衝突' : '✅ 可以申請' }}
              </span>
              <button @click="closeModal" class="text-slate-400 hover:text-slate-600 text-xl leading-none">✕</button>
            </div>
          </div>

          <!-- Body -->
          <div class="p-5">
            <div class="flex gap-4 text-xs mb-3 flex-wrap">
              <div class="flex items-center gap-1.5"><div class="w-3 h-3 bg-slate-200 rounded border border-slate-300"></div>團隊有課</div>
              <div class="flex items-center gap-1.5"><div class="w-3 h-3 bg-red-500 rounded"></div>時間衝突</div>
              <div class="flex items-center gap-1.5"><div class="w-3 h-3 bg-emerald-500 rounded"></div>黃金共同空堂</div>
            </div>

            <!-- Mini Grid -->
            <div class="grid gap-1 bg-slate-50 p-3 rounded-xl border border-slate-100" style="grid-template-columns: 1.5rem repeat(5, 1fr);">
              <div class="text-xs text-slate-400 text-center font-mono">節</div>
              <div v-for="d in 5" :key="`mh${d}`" class="text-center text-xs font-bold text-slate-700">
                週{{ ['一','二','三','四','五'][d - 1] }}
              </div>
              <template v-for="p in 10" :key="`mrow${p}`">
                <div class="flex items-center justify-center text-xs font-mono text-slate-400 font-bold">{{ p }}</div>
                <div
                  v-for="d in 5"
                  :key="`m${d}-${p}`"
                  :class="['h-8 rounded border text-xs font-bold flex items-center justify-center transition-all', getModalStyle(d, p)]"
                >{{ getModalText(d, p) }}</div>
              </template>
            </div>

            <div class="mt-4 flex justify-between items-center">
              <span class="text-sm text-slate-500">
                黃金空堂：<span class="font-bold text-emerald-600">{{ preCheckResult?.goldenSlots.length ?? 0 }} 節</span>
              </span>
              <span v-if="preCheckResult?.hasConflict" class="text-sm text-red-400">
                衝突：<span class="font-bold">{{ preCheckResult?.conflictSlots.length }} 節</span>
              </span>
            </div>

            <!-- Submit Button (hidden if conflict) -->
            <div class="mt-5 flex justify-end gap-3">
              <button @click="closeModal" class="px-4 py-2 text-sm text-slate-500 hover:text-slate-700 transition-colors">取消</button>
              <button
                v-if="!preCheckResult?.hasConflict"
                @click="confirmApply"
                class="px-6 py-2 text-sm font-semibold text-white bg-blue-600 hover:bg-blue-700 rounded-lg transition-colors shadow"
              >確認送出申請</button>
              <span v-else class="text-sm text-red-500 italic self-center">時間衝突，無法申請</span>
            </div>
          </div>
        </div>
      </div>
    </Transition>
  </div>
</template>

<style scoped>
.modal-enter-active, .modal-leave-active { transition: opacity 0.2s ease; }
.modal-enter-from, .modal-leave-to { opacity: 0; }
.fade-fast-enter-active, .fade-fast-leave-active { transition: opacity 0.15s; }
.fade-fast-enter-from, .fade-fast-leave-to { opacity: 0; }
</style>
