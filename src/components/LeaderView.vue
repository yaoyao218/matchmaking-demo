<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import {
  currentActiveUser,
  projectsArray,
  applicationsArray,
  acceptApplication,
  rejectApplication,
  createProject,
  toggleProjectOpen,
  getStudentById,
  type Application,
} from '../store/globalState'
import { calculateOverlay, decompressMask } from '../utils/scheduleAlgo'

// ── Leader's projects ─────────────────────────────────────────────────
const leaderProjects = computed(() =>
  projectsArray.filter(p => p.leaderId === currentActiveUser.value.id)
)

const selectedProjectId = ref<number>(leaderProjects.value[0]?.id ?? -1)
watch(leaderProjects, (list) => {
  if (!list.find(p => p.id === selectedProjectId.value))
    selectedProjectId.value = list[0]?.id ?? -1
}, { immediate: true })

const activeProject = computed(() =>
  projectsArray.find(p => p.id === selectedProjectId.value) ?? null
)

// ── PENDING applications for active project ───────────────────────────
interface RichApp {
  app: Application
  studentName: string
  skills: string[]
  studentMask: string
  calc: ReturnType<typeof calculateOverlay>
}

const pendingApps = computed<RichApp[]>(() => {
  if (!activeProject.value) return []
  return applicationsArray
    .filter(a => a.projectId === activeProject.value!.id && a.status === 'PENDING')
    .map(a => {
      const student = getStudentById(a.studentId)
      const mask = student?.courseScheduleMask ?? '0'
      return {
        app: a,
        studentName: student?.name ?? `學生 #${a.studentId}`,
        skills: student?.skills ?? [],
        studentMask: mask,
        calc: calculateOverlay(activeProject.value!.groupScheduleMask, mask),
      }
    })
})

// ── ACCEPTED members for active project ──────────────────────────────
const acceptedMembers = computed(() => {
  if (!activeProject.value) return []
  return applicationsArray
    .filter(a => a.projectId === activeProject.value!.id && a.status === 'ACCEPTED')
    .map(a => {
      const student = getStudentById(a.studentId)
      return {
        app: a,
        name: student?.name ?? `學生 #${a.studentId}`,
        mask: student?.courseScheduleMask ?? '0',
      }
    })
})

// ── Selected applicant (for grid preview) ────────────────────────────
const selectedApp = ref<RichApp | null>(null)

watch(pendingApps, (list) => {
  if (selectedApp.value && !list.find(r => r.app.id === selectedApp.value!.app.id))
    selectedApp.value = list[0] ?? null
}, { immediate: true })

function selectApp(rich: RichApp) { selectedApp.value = rich }

// ── Accept ────────────────────────────────────────────────────────────
function handleAccept(rich: RichApp) {
  acceptApplication(rich.app.id)
  selectedApp.value = pendingApps.value[0] ?? null
}

// ── Reject Modal ──────────────────────────────────────────────────────
const rejectModalOpen = ref(false)
const rejectTargetId = ref<number | null>(null)
const rejectTags = ['時間衝突', '技能不符', '人數已達上限', '其他原因']
const rejectTagSelected = ref('')
const rejectCustom = ref('')

function openRejectModal(appId: number) {
  rejectTargetId.value = appId
  rejectTagSelected.value = ''
  rejectCustom.value = ''
  rejectModalOpen.value = true
}

function confirmReject() {
  if (!rejectTargetId.value) return
  const reason = rejectTagSelected.value
    ? (rejectTagSelected.value === '其他原因' ? (rejectCustom.value || '其他原因') : rejectTagSelected.value)
    : (rejectCustom.value || '未提供原因')
  rejectApplication(rejectTargetId.value, reason)
  rejectModalOpen.value = false
}

// ── Project Creation Modal ────────────────────────────────────────────
const createModalOpen = ref(false)
const newCourseCode = ref('')
const newTitle = ref('')
const newMaxMembers = ref(5)
const createError = ref('')

function openCreateModal() {
  newCourseCode.value = ''
  newTitle.value = ''
  newMaxMembers.value = 5
  createError.value = ''
  createModalOpen.value = true
}

function confirmCreate() {
  if (!newCourseCode.value.trim() || !newTitle.value.trim()) {
    createError.value = '課程代碼與專案名稱不可為空'
    return
  }
  const project = createProject(newCourseCode.value.trim(), newTitle.value.trim(), newMaxMembers.value)
  selectedProjectId.value = project.id
  createModalOpen.value = false
}

// ── Grid slot helpers ─────────────────────────────────────────────────
function getSlotStyle(d: number, p: number): string {
  if (!selectedApp.value || !activeProject.value) {
    const gSlots = decompressMask(BigInt(activeProject.value?.groupScheduleMask ?? '0'))
    return gSlots.some(s => s.day === d && s.period === p)
      ? 'bg-slate-200 border-slate-300 text-slate-500'
      : 'bg-white border-slate-200 text-slate-300'
  }
  const { conflictSlots, goldenSlots } = selectedApp.value.calc
  if (conflictSlots.some(s => s.day === d && s.period === p))
    return 'bg-red-500 border-red-600 text-white'
  if (goldenSlots.some(s => s.day === d && s.period === p))
    return 'bg-emerald-500 border-emerald-600 text-white'
  const gSlots = decompressMask(BigInt(activeProject.value.groupScheduleMask))
  if (gSlots.some(s => s.day === d && s.period === p))
    return 'bg-slate-200 border-slate-300 text-slate-500'
  return 'bg-white border-slate-200 text-slate-200'
}

function getSlotText(d: number, p: number): string {
  if (!selectedApp.value) return ''
  const { conflictSlots, goldenSlots } = selectedApp.value.calc
  if (conflictSlots.some(s => s.day === d && s.period === p)) return '衝突'
  if (goldenSlots.some(s => s.day === d && s.period === p)) return '開會'
  return ''
}

// Member mini-grid
function getMemberSlotStyle(mask: string, d: number, p: number): string {
  const slots = decompressMask(BigInt(mask))
  return slots.some(s => s.day === d && s.period === p)
    ? 'bg-blue-500 border-blue-600'
    : 'bg-slate-100 border-slate-200'
}
</script>

<template>
  <div class="p-6 max-w-7xl mx-auto">

    <!-- Top bar: project selector + actions -->
    <div class="flex items-center justify-between mb-6 flex-wrap gap-3">
      <div class="flex items-center gap-2 flex-wrap">
        <span class="text-sm font-medium text-slate-500">我的專案：</span>
        <button
          v-for="p in leaderProjects"
          :key="p.id"
          @click="selectedProjectId = p.id"
          :class="[
            'px-4 py-1.5 text-sm font-semibold rounded-lg border transition-all',
            selectedProjectId === p.id
              ? 'bg-blue-600 text-white border-blue-700 shadow'
              : 'bg-white text-slate-600 border-slate-200 hover:border-blue-300',
          ]"
        >{{ p.title }}</button>
        <span v-if="leaderProjects.length === 0" class="text-sm text-slate-400">尚無專案</span>
      </div>
      <div class="flex items-center gap-2">
        <button
          v-if="activeProject"
          @click="toggleProjectOpen(activeProject.id)"
          :class="[
            'px-4 py-2 text-xs font-semibold rounded-lg border transition-all',
            activeProject.isOpen
              ? 'bg-slate-50 text-slate-600 border-slate-200 hover:bg-red-50 hover:text-red-600 hover:border-red-200'
              : 'bg-emerald-50 text-emerald-700 border-emerald-200 hover:bg-emerald-100',
          ]"
        >{{ activeProject.isOpen ? '關閉招募' : '開啟招募' }}</button>
        <button
          @click="openCreateModal"
          class="px-4 py-2 text-xs font-semibold text-white bg-blue-600 hover:bg-blue-700 rounded-lg transition-colors shadow"
        >+ 建立新專案</button>
      </div>
    </div>

    <!-- No project -->
    <div v-if="!activeProject" class="bg-white rounded-xl border border-slate-200 shadow-sm p-16 text-center">
      <p class="text-slate-400 text-sm mb-3">尚未建立任何專案</p>
      <button @click="openCreateModal" class="text-blue-600 text-sm font-semibold hover:underline">立即建立第一個專案</button>
    </div>

    <div v-else class="grid grid-cols-1 lg:grid-cols-3 gap-6">

      <!-- ── Left: Applicants ───────────────────────────────────────── -->
      <div class="lg:col-span-1 space-y-3">

        <!-- Project info card -->
        <div class="bg-white rounded-xl border border-slate-200 shadow-sm p-4">
          <div class="flex justify-between items-start">
            <div>
              <h3 class="font-bold text-slate-800 text-sm">{{ activeProject.title }}</h3>
              <p class="text-xs text-slate-400 mt-0.5">{{ activeProject.courseCode }}</p>
            </div>
            <span :class="['text-xs px-2 py-0.5 rounded-full font-medium', activeProject.isOpen ? 'bg-emerald-100 text-emerald-700' : 'bg-slate-100 text-slate-500']">
              {{ activeProject.isOpen ? '招募中' : '已關閉' }}
            </span>
          </div>
          <div class="mt-3">
            <div class="flex justify-between text-xs text-slate-400 mb-1">
              <span>成員進度</span>
              <span class="font-bold text-blue-600">{{ activeProject.currentMembers }}/{{ activeProject.maxMembers }}</span>
            </div>
            <div class="w-full bg-slate-100 h-2 rounded-full overflow-hidden">
              <div class="bg-blue-600 h-full rounded-full transition-all duration-500" :style="{ width: (activeProject.currentMembers / activeProject.maxMembers) * 100 + '%' }"></div>
            </div>
          </div>
        </div>

        <!-- Pending applicant cards -->
        <h4 class="text-xs font-semibold text-slate-500 uppercase tracking-wide px-1">
          待審核（{{ pendingApps.length }}）
        </h4>

        <div
          v-for="rich in pendingApps"
          :key="rich.app.id"
          @click="selectApp(rich)"
          :class="[
            'p-4 bg-white rounded-xl border transition-all cursor-pointer shadow-sm hover:border-blue-300',
            selectedApp?.app.id === rich.app.id ? 'border-blue-500 ring-2 ring-blue-100' : 'border-slate-200',
          ]"
        >
          <div class="flex justify-between items-start mb-1">
            <h3 class="font-bold text-slate-800 text-sm">{{ rich.studentName }}</h3>
            <span :class="['text-xs px-2 py-0.5 rounded-full font-medium shrink-0', rich.calc.hasConflict ? 'bg-red-100 text-red-600' : 'bg-emerald-100 text-emerald-700']">
              {{ rich.calc.hasConflict ? '⚠️ 衝突' : '✅ 通過' }}
            </span>
          </div>
          <div class="flex gap-1 flex-wrap mb-2">
            <span v-for="skill in rich.skills" :key="skill" class="text-xs bg-slate-100 text-slate-600 px-1.5 py-0.5 rounded">{{ skill }}</span>
          </div>
          <p class="text-xs text-slate-400">黃金空堂：<span class="font-semibold text-emerald-600">{{ rich.calc.goldenSlots.length }} 節</span></p>

          <div class="mt-3 flex gap-2 justify-end" @click.stop>
            <button
              @click="openRejectModal(rich.app.id)"
              class="px-3 py-1.5 text-xs font-medium text-red-600 bg-red-50 hover:bg-red-100 rounded-lg transition-colors"
            >拒絕</button>
            <button
              @click="handleAccept(rich)"
              :disabled="rich.calc.hasConflict || activeProject.currentMembers >= activeProject.maxMembers"
              :class="[
                'px-3 py-1.5 text-xs font-medium text-white rounded-lg transition-colors',
                rich.calc.hasConflict || activeProject.currentMembers >= activeProject.maxMembers
                  ? 'bg-slate-300 cursor-not-allowed'
                  : 'bg-blue-600 hover:bg-blue-700',
              ]"
            >錄取</button>
          </div>
        </div>

        <p v-if="pendingApps.length === 0" class="text-center text-slate-400 text-sm py-6 bg-white rounded-xl border border-slate-200">
          目前沒有待審核的申請
        </p>

        <!-- Accepted Roster -->
        <h4 v-if="acceptedMembers.length > 0" class="text-xs font-semibold text-slate-500 uppercase tracking-wide px-1 pt-2">
          已錄取成員（{{ acceptedMembers.length }}）
        </h4>
        <div
          v-for="m in acceptedMembers"
          :key="m.app.id"
          class="p-4 bg-white rounded-xl border border-emerald-200 shadow-sm"
        >
          <div class="flex justify-between items-center mb-2">
            <span class="font-semibold text-slate-800 text-sm">{{ m.name }}</span>
            <span class="text-xs bg-emerald-100 text-emerald-700 px-2 py-0.5 rounded-full">已錄取</span>
          </div>
          <!-- Mini 5x10 schedule -->
          <div class="grid gap-0.5" style="grid-template-columns: repeat(5, 1fr);">
            <div v-for="d in 5" :key="`rh${d}-${m.app.id}`" class="text-center text-[9px] text-slate-400 pb-0.5">
              {{ ['一','二','三','四','五'][d - 1] }}
            </div>
            <template v-for="p in 10" :key="`rrow${p}-${m.app.id}`">
              <div
                v-for="d in 5"
                :key="`r${d}-${p}-${m.app.id}`"
                :class="['h-4 rounded-sm border', getMemberSlotStyle(m.mask, d, p)]"
              ></div>
            </template>
          </div>
        </div>
      </div>

      <!-- ── Right: Schedule Grid ──────────────────────────────────── -->
      <div class="lg:col-span-2 bg-white p-6 rounded-xl border border-slate-200 shadow-sm">
        <div class="flex justify-between items-start mb-5 gap-4">
          <div>
            <h2 class="text-lg font-bold text-slate-800">課表即時疊加看板</h2>
            <p class="text-xs text-slate-400 mt-0.5">
              {{ selectedApp ? `正在檢視：${selectedApp.studentName}` : '點擊左側申請人以檢視課表' }}
            </p>
          </div>
          <div class="flex flex-col gap-1.5 text-xs font-medium shrink-0">
            <div class="flex items-center gap-1.5"><div class="w-3 h-3 bg-slate-200 rounded border border-slate-300"></div>原有組員課</div>
            <div class="flex items-center gap-1.5"><div class="w-3 h-3 bg-red-500 rounded"></div>時間衝突</div>
            <div class="flex items-center gap-1.5"><div class="w-3 h-3 bg-emerald-500 rounded"></div>黃金共同空堂</div>
          </div>
        </div>

        <div class="grid gap-1.5 bg-slate-50 p-3 rounded-xl border border-slate-100" style="grid-template-columns: 2rem repeat(5, 1fr);">
          <div class="text-center font-bold text-slate-400 text-xs py-1">節次</div>
          <div v-for="d in 5" :key="`lh${d}`" class="text-center font-bold text-slate-700 text-sm py-1">
            週{{ ['一','二','三','四','五'][d - 1] }}
          </div>

          <template v-for="p in 10" :key="`lrow${p}`">
            <div class="flex items-center justify-center font-mono text-sm text-slate-400 font-bold">{{ p }}</div>
            <div
              v-for="d in 5"
              :key="`l${d}-${p}`"
              :class="['h-11 rounded-lg border text-xs font-bold flex items-center justify-center transition-all duration-200 select-none', getSlotStyle(d, p)]"
            >{{ getSlotText(d, p) }}</div>
          </template>
        </div>

        <div v-if="selectedApp" class="mt-4 flex gap-6 text-sm px-1">
          <span class="text-slate-500">黃金空堂：<span class="font-bold text-emerald-600">{{ selectedApp.calc.goldenSlots.length }} 節</span></span>
          <span v-if="selectedApp.calc.hasConflict" class="text-slate-500">衝突：<span class="font-bold text-red-500">{{ selectedApp.calc.conflictSlots.length }} 節</span></span>
        </div>
      </div>
    </div>

    <!-- ════════════════════════════════════════════════════════════════ -->
    <!-- Reject Modal -->
    <!-- ════════════════════════════════════════════════════════════════ -->
    <Transition name="modal">
      <div v-if="rejectModalOpen" class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40 backdrop-blur-sm" @click.self="rejectModalOpen = false">
        <div class="bg-white rounded-2xl shadow-2xl w-full max-w-md overflow-hidden">
          <div class="p-5 border-b border-slate-100 flex justify-between items-center">
            <h3 class="font-bold text-slate-800">填寫拒絕原因</h3>
            <button @click="rejectModalOpen = false" class="text-slate-400 hover:text-slate-600 text-xl leading-none">✕</button>
          </div>
          <div class="p-5 space-y-4">
            <!-- Quick tags -->
            <div>
              <p class="text-xs font-medium text-slate-500 mb-2">快速標籤</p>
              <div class="flex flex-wrap gap-2">
                <button
                  v-for="tag in rejectTags"
                  :key="tag"
                  @click="rejectTagSelected = tag"
                  :class="[
                    'text-xs px-3 py-1.5 rounded-full border font-medium transition-all',
                    rejectTagSelected === tag
                      ? 'bg-red-500 text-white border-red-600'
                      : 'bg-slate-50 text-slate-600 border-slate-200 hover:border-red-300 hover:text-red-500',
                  ]"
                >{{ tag }}</button>
              </div>
            </div>
            <!-- Custom textarea -->
            <div>
              <p class="text-xs font-medium text-slate-500 mb-1">自訂說明（選填）</p>
              <textarea
                v-model="rejectCustom"
                rows="3"
                placeholder="可輸入更詳細的說明..."
                class="w-full text-sm border border-slate-200 rounded-lg px-3 py-2 resize-none focus:outline-none focus:ring-2 focus:ring-red-300 placeholder:text-slate-300"
              ></textarea>
            </div>
          </div>
          <div class="px-5 pb-5 flex justify-end gap-2">
            <button @click="rejectModalOpen = false" class="px-4 py-2 text-sm text-slate-500 hover:text-slate-700 transition-colors">取消</button>
            <button
              @click="confirmReject"
              class="px-5 py-2 text-sm font-semibold text-white bg-red-500 hover:bg-red-600 rounded-lg transition-colors"
            >確認拒絕</button>
          </div>
        </div>
      </div>
    </Transition>

    <!-- ════════════════════════════════════════════════════════════════ -->
    <!-- Create Project Modal -->
    <!-- ════════════════════════════════════════════════════════════════ -->
    <Transition name="modal">
      <div v-if="createModalOpen" class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40 backdrop-blur-sm" @click.self="createModalOpen = false">
        <div class="bg-white rounded-2xl shadow-2xl w-full max-w-md overflow-hidden">
          <div class="p-5 border-b border-slate-100 flex justify-between items-center">
            <h3 class="font-bold text-slate-800">建立新專案</h3>
            <button @click="createModalOpen = false" class="text-slate-400 hover:text-slate-600 text-xl leading-none">✕</button>
          </div>
          <div class="p-5 space-y-4">
            <div>
              <label class="text-xs font-medium text-slate-500 block mb-1">課程代碼</label>
              <input v-model="newCourseCode" type="text" placeholder="例如 CS-201-B" class="w-full text-sm border border-slate-200 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-300 placeholder:text-slate-300" />
            </div>
            <div>
              <label class="text-xs font-medium text-slate-500 block mb-1">專案名稱</label>
              <input v-model="newTitle" type="text" placeholder="輸入專案名稱..." class="w-full text-sm border border-slate-200 rounded-lg px-3 py-2 focus:outline-none focus:ring-2 focus:ring-blue-300 placeholder:text-slate-300" />
            </div>
            <div>
              <label class="text-xs font-medium text-slate-500 block mb-1">招募人數上限（含組長）</label>
              <div class="flex items-center gap-3">
                <button @click="newMaxMembers = Math.max(2, newMaxMembers - 1)" class="w-8 h-8 rounded-full border border-slate-200 text-slate-600 hover:bg-slate-50 font-bold text-lg leading-none flex items-center justify-center">−</button>
                <span class="text-lg font-bold text-slate-800 w-6 text-center">{{ newMaxMembers }}</span>
                <button @click="newMaxMembers = Math.min(10, newMaxMembers + 1)" class="w-8 h-8 rounded-full border border-slate-200 text-slate-600 hover:bg-slate-50 font-bold text-lg leading-none flex items-center justify-center">+</button>
              </div>
            </div>
            <p v-if="createError" class="text-xs text-red-500">{{ createError }}</p>
          </div>
          <div class="px-5 pb-5 flex justify-end gap-2">
            <button @click="createModalOpen = false" class="px-4 py-2 text-sm text-slate-500 hover:text-slate-700 transition-colors">取消</button>
            <button @click="confirmCreate" class="px-5 py-2 text-sm font-semibold text-white bg-blue-600 hover:bg-blue-700 rounded-lg transition-colors shadow">建立專案</button>
          </div>
        </div>
      </div>
    </Transition>
  </div>
</template>

<style scoped>
.modal-enter-active, .modal-leave-active { transition: opacity 0.2s ease; }
.modal-enter-from, .modal-leave-to { opacity: 0; }
</style>
