<template>
  <div class="min-h-screen bg-slate-50 p-6 font-sans">
    <header class="mb-8 border-b border-slate-200 bg-white p-4 rounded-xl shadow-sm flex justify-between items-center">
      <div>
        <h1 class="text-xl font-bold text-slate-800">專案組隊媒合系統 — 組長端控制台</h1>
        <p class="text-sm text-slate-500">專案名稱：{{ projectInfo.title }} (課程：{{ projectInfo.courseCode }})</p>
      </div>
      <div class="text-right">
        <span class="text-sm font-medium text-slate-600">當前人數：</span>
        <span class="text-lg font-bold text-blue-600">{{ projectInfo.currentMembers }} / {{ projectInfo.maxMembers }}</span>
        <div class="w-32 bg-slate-200 h-2 rounded-full mt-1 overflow-hidden">
          <div
            class="bg-blue-600 h-full transition-all duration-300"
            :style="{ width: (projectInfo.currentMembers / projectInfo.maxMembers) * 100 + '%' }"
          ></div>
        </div>
      </div>
    </header>

    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
      <!-- 左側：申請者列表 -->
      <div class="lg:col-span-1 space-y-4">
        <h2 class="text-md font-semibold text-slate-700 px-1">待審核名單 (Applications)</h2>

        <div
          v-for="app in applicants"
          :key="app.id"
          @click="selectApplicant(app)"
          :class="[
            'p-4 bg-white rounded-xl border transition-all cursor-pointer shadow-sm hover:border-blue-300',
            selectedApp?.id === app.id ? 'border-blue-500 ring-2 ring-blue-100' : 'border-slate-200',
          ]"
        >
          <div class="flex justify-between items-start mb-2">
            <div>
              <h3 class="font-bold text-slate-800 text-base">{{ app.name }}</h3>
              <div class="flex gap-1 mt-1 flex-wrap">
                <span
                  v-for="skill in app.skills"
                  :key="skill"
                  class="text-xs bg-slate-100 text-slate-600 px-2 py-0.5 rounded"
                >{{ skill }}</span>
              </div>
            </div>
            <span
              :class="[
                'text-xs px-2 py-0.5 rounded-full font-medium shrink-0',
                app.status === 'PENDING' ? 'bg-amber-100 text-amber-700' : 'bg-emerald-100 text-emerald-700',
              ]"
            >{{ app.status }}</span>
          </div>

          <div class="mt-3 pt-3 border-t border-slate-100 flex justify-between text-xs">
            <span class="text-slate-500">
              時間預檢：
              <span v-if="app.calc.hasConflict" class="text-red-500 font-bold">⚠️ 時間衝突</span>
              <span v-else class="text-emerald-600 font-bold">✅ 通過</span>
            </span>
            <span class="text-blue-600 font-medium">共同空堂：{{ app.calc.goldenSlots.length }} 節</span>
          </div>

          <div v-if="app.status === 'PENDING'" class="mt-4 flex gap-2 justify-end" @click.stop>
            <button
              @click="handleReject(app.id)"
              class="px-3 py-1.5 text-xs font-medium text-red-600 bg-red-50 hover:bg-red-100 rounded-lg transition-colors"
            >拒絕</button>
            <button
              @click="handleAccept(app)"
              :disabled="app.calc.hasConflict || projectInfo.currentMembers >= projectInfo.maxMembers"
              :class="[
                'px-3 py-1.5 text-xs font-medium text-white rounded-lg transition-colors',
                app.calc.hasConflict || projectInfo.currentMembers >= projectInfo.maxMembers
                  ? 'bg-slate-300 cursor-not-allowed'
                  : 'bg-blue-600 hover:bg-blue-700',
              ]"
            >錄取</button>
          </div>
        </div>

        <p v-if="applicants.length === 0" class="text-center text-slate-400 text-sm py-8">
          沒有待審核的申請
        </p>
      </div>

      <!-- 右側：5x10 課表網格 -->
      <div class="lg:col-span-2 bg-white p-6 rounded-xl border border-slate-200 shadow-sm">
        <div class="flex justify-between items-center mb-6">
          <div>
            <h2 class="text-lg font-bold text-slate-800">團隊課表即時疊加看板</h2>
            <p class="text-xs text-slate-500 mt-0.5">
              {{ selectedApp ? `正在檢視：${selectedApp.name}` : '點擊左側申請人以檢視課表疊加' }}
            </p>
          </div>
          <div class="flex gap-4 text-xs font-medium flex-wrap justify-end">
            <div class="flex items-center gap-1.5"><div class="w-3 h-3 bg-slate-200 rounded border border-slate-300"></div>原有組員課</div>
            <div class="flex items-center gap-1.5"><div class="w-3 h-3 bg-red-500 rounded"></div>時間衝突</div>
            <div class="flex items-center gap-1.5"><div class="w-3 h-3 bg-emerald-500 rounded"></div>黃金共同空堂</div>
          </div>
        </div>

        <div class="grid gap-1.5 bg-slate-50 p-3 rounded-xl border border-slate-100" style="grid-template-columns: 2rem repeat(5, 1fr);">
          <!-- 標題列 -->
          <div class="text-center font-bold text-slate-400 text-xs py-1">節</div>
          <div v-for="d in 5" :key="`h${d}`" class="text-center font-bold text-slate-700 text-sm py-1">
            週{{ ['一','二','三','四','五'][d - 1] }}
          </div>

          <!-- 10 節 x 5 天 -->
          <template v-for="p in 10" :key="`row${p}`">
            <div class="flex items-center justify-center font-mono text-xs text-slate-400 font-bold">{{ p }}</div>
            <div
              v-for="d in 5"
              :key="`${d}-${p}`"
              :class="[
                'h-11 rounded-lg border text-xs font-bold flex flex-col items-center justify-center transition-all duration-300 select-none',
                getSlotStyle(d, p),
              ]"
            >
              <span>{{ getSlotText(d, p) }}</span>
            </div>
          </template>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { calculateOverlay, decompressMask } from '../utils/scheduleAlgo'

interface Applicant {
  id: number
  name: string
  skills: string[]
  studentScheduleMask: string
  status: 'PENDING' | 'ACCEPTED' | 'REJECTED'
  calc: {
    hasConflict: boolean
    conflictSlots: { day: number; period: number }[]
    goldenSlots: { day: number; period: number }[]
  }
}

const projectInfo = ref({
  id: 1,
  title: 'AI 雲端影像辨識專案隊伍',
  courseCode: 'CS-101-A',
  currentMembers: 3,
  maxMembers: 5,
  groupScheduleMask: '1125899906842624',
})

const applicants = ref<Applicant[]>([
  {
    id: 101,
    name: '陳阿明 (前端高手)',
    skills: ['Vue3', 'Tailwind', 'TypeScript'],
    studentScheduleMask: '4398046511104', // 與團隊無衝突
    status: 'PENDING',
    calc: { hasConflict: false, conflictSlots: [], goldenSlots: [] },
  },
  {
    id: 102,
    name: '林小華 (後端專員)',
    skills: ['Node.js', 'Docker', 'MySQL'],
    studentScheduleMask: '1125899906842624', // 與團隊完全衝突
    status: 'PENDING',
    calc: { hasConflict: false, conflictSlots: [], goldenSlots: [] },
  },
])

const selectedApp = ref<Applicant | null>(null)

onMounted(() => {
  applicants.value.forEach((app) => {
    app.calc = calculateOverlay(projectInfo.value.groupScheduleMask, app.studentScheduleMask)
  })
  selectedApp.value = applicants.value[0] ?? null
})

function selectApplicant(app: Applicant) {
  selectedApp.value = app
}

function handleAccept(app: Applicant) {
  app.status = 'ACCEPTED'
  projectInfo.value.currentMembers += 1

  // 樂觀 UI：將學生課表融入團隊 mask
  const newMask = BigInt(projectInfo.value.groupScheduleMask) | BigInt(app.studentScheduleMask)
  projectInfo.value.groupScheduleMask = newMask.toString()

  // 重算其餘 PENDING 者的衝突狀態
  applicants.value.forEach((a) => {
    if (a.status === 'PENDING') {
      a.calc = calculateOverlay(projectInfo.value.groupScheduleMask, a.studentScheduleMask)
    }
  })

  // 若被選中的人剛被錄取，切換到下一個 pending
  if (selectedApp.value?.id === app.id) {
    selectedApp.value = applicants.value.find((a) => a.status === 'PENDING') ?? null
  }
}

function handleReject(id: number) {
  applicants.value = applicants.value.filter((a) => a.id !== id)
  if (selectedApp.value?.id === id) {
    selectedApp.value = applicants.value.find((a) => a.status === 'PENDING') ?? null
  }
}

function getSlotStyle(day: number, period: number): string {
  if (!selectedApp.value) {
    const groupSlots = decompressMask(BigInt(projectInfo.value.groupScheduleMask))
    if (groupSlots.some((s) => s.day === day && s.period === period)) {
      return 'bg-slate-200 border-slate-300 text-slate-500'
    }
    return 'bg-white border-slate-200 text-slate-300'
  }

  const { conflictSlots, goldenSlots } = selectedApp.value.calc

  if (conflictSlots.some((s) => s.day === day && s.period === period)) {
    return 'bg-red-500 border-red-600 text-white animate-pulse shadow-md'
  }
  if (goldenSlots.some((s) => s.day === day && s.period === period)) {
    return 'bg-emerald-500 border-emerald-600 text-white shadow-sm'
  }

  const groupSlots = decompressMask(BigInt(projectInfo.value.groupScheduleMask))
  if (groupSlots.some((s) => s.day === day && s.period === period)) {
    return 'bg-slate-200 border-slate-300 text-slate-500'
  }

  return 'bg-white border-slate-200 text-slate-300 hover:bg-slate-50'
}

function getSlotText(day: number, period: number): string {
  if (!selectedApp.value) return ''
  const { conflictSlots, goldenSlots } = selectedApp.value.calc
  if (conflictSlots.some((s) => s.day === day && s.period === period)) return '衝突'
  if (goldenSlots.some((s) => s.day === day && s.period === period)) return '開會'
  return ''
}
</script>
