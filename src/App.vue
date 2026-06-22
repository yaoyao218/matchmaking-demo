<script setup lang="ts">
import { currentActiveUser, switchUser } from './store/globalState'
import StudentView from './components/StudentView.vue'
import LeaderView from './components/LeaderView.vue'

const userOptions = [
  { key: 'studentA', label: '🎓 張小明（空閒學生 A）' },
  { key: 'studentB', label: '🎓 李小華（衝突學生 B）' },
  { key: 'leader',   label: '👑 王組長（組長）' },
]
</script>

<template>
  <div class="min-h-screen bg-slate-100">
    <nav class="bg-white border-b border-slate-200 shadow-sm px-6 py-3 flex items-center justify-between sticky top-0 z-50">
      <div class="flex items-center gap-3">
        <div class="w-8 h-8 bg-blue-600 rounded-lg flex items-center justify-center shrink-0">
          <span class="text-white text-sm font-bold">M</span>
        </div>
        <div>
          <h1 class="text-sm font-bold text-slate-800 leading-tight">專案組隊媒合系統</h1>
          <p class="text-xs text-slate-400">Project Matchmaking System</p>
        </div>
      </div>

      <div class="flex items-center gap-4">
        <!-- Identity Switcher -->
        <div class="flex items-center gap-2 bg-slate-50 border border-slate-200 rounded-lg px-3 py-2">
          <span class="text-xs text-slate-500 font-medium shrink-0">身份切換：</span>
          <select
            @change="switchUser(($event.target as HTMLSelectElement).value)"
            class="text-xs font-semibold text-slate-700 bg-transparent border-none outline-none cursor-pointer"
          >
            <option v-for="opt in userOptions" :key="opt.key" :value="opt.key">
              {{ opt.label }}
            </option>
          </select>
        </div>

        <!-- Active Badge -->
        <div class="flex items-center gap-2 text-xs">
          <div :class="['w-2.5 h-2.5 rounded-full', currentActiveUser.role === 'LEADER' ? 'bg-purple-500' : 'bg-emerald-500']"></div>
          <span class="font-semibold text-slate-700">{{ currentActiveUser.name }}</span>
          <span :class="['px-2 py-0.5 rounded-full font-medium', currentActiveUser.role === 'LEADER' ? 'bg-purple-100 text-purple-700' : 'bg-emerald-100 text-emerald-700']">
            {{ currentActiveUser.role === 'LEADER' ? '組長' : '學生' }}
          </span>
        </div>
      </div>
    </nav>

    <Transition name="fade" mode="out-in">
      <StudentView v-if="currentActiveUser.role === 'STUDENT'" :key="currentActiveUser.id" />
      <LeaderView v-else :key="currentActiveUser.id" />
    </Transition>
  </div>
</template>

<style>
.fade-enter-active, .fade-leave-active { transition: opacity 0.18s ease; }
.fade-enter-from, .fade-leave-to { opacity: 0; }
</style>
