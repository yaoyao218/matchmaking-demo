# 前端架構參考文件

> 專案組隊媒合系統 · Project Matchmaking Demo  
> 線上展示：https://matchmaking-demo-eta.vercel.app

---

## 技術堆疊

| 層次 | 技術 |
|------|------|
| 框架 | Vue 3 Composition API |
| 語言 | TypeScript 5 |
| 建構工具 | Vite 8 |
| 樣式 | Tailwind CSS v3 |
| 狀態管理 | 原生 `ref()` + `reactive()`（無 Vuex / Pinia） |
| 演算法 | 50-bit BigInt 遮罩（`src/utils/scheduleAlgo.ts`） |
| 部署 | Vercel（靜態 SPA，零後端） |

---

## 專案目錄結構

```
matchmaking-demo/
├── docs/
│   ├── SPEC.md           # 系統規格說明
│   ├── API.md            # API 介面文件
│   ├── schema.sql        # 資料庫 Schema
│   ├── DEMO_SCRIPT.md    # 7 分鐘展示腳本
│   └── ARCHITECTURE.md   # 本文件
├── src/
│   ├── store/
│   │   └── globalState.ts     ★ 全局狀態核心（唯一資料源）
│   ├── utils/
│   │   └── scheduleAlgo.ts    # 50-bit 遮罩演算法（純函數）
│   ├── components/
│   │   ├── StudentView.vue    # 學生端（課表編輯 + 申請流程）
│   │   └── LeaderView.vue     # 組長端（審核 + 建立專案）
│   ├── App.vue                # 根元件（Navbar + 身份路由）
│   ├── main.ts                # 入口（BigInt polyfill + mount）
│   └── style.css              # Tailwind base / components / utilities
├── vercel.json                # SPA rewrites 設定
├── tailwind.config.js
├── vite.config.ts
└── package.json
```

---

## 資料流向

```
使用者操作
    ↓
Component 呼叫 Action（import from globalState.ts）
    ↓
globalState.ts 直接修改 reactive 物件
    ↓
所有引用該狀態的 Component 自動重新渲染
```

Vue 3 響應式系統追蹤相同物件參考，無需手動通知，任何身份切換後狀態即時同步。

---

## globalState.ts — 狀態一覽

### 響應式狀態

| 名稱 | 類型 | 說明 |
|------|------|------|
| `currentActiveUser` | `ref<MockUser>` | 目前登入的使用者（id / name / role / skills） |
| `projectsArray` | `reactive<Project[]>` | 所有專案；錄取時自動更新 mask 與人數 |
| `applicationsArray` | `reactive<Application[]>` | 所有申請；狀態：PENDING / ACCEPTED / REJECTED / CANCELED |
| `userSchedules` | `reactive<Record<number, string>>` | per-user 課表 mask（key = userId），切換身份後持久保留 |

### Actions（直接 import 呼叫）

```typescript
switchUser(key: string)                                // 切換 Mock 身份
submitApplication(projectId, studentId): Application  // 送出申請
withdrawApplication(appId)                            // 撤回申請
acceptApplication(appId)                              // 錄取（含 mask 合併 + 自動取消）
rejectApplication(appId, reason)                      // 拒絕（附原因）
createProject(courseCode, title, maxMembers): Project // 建立新專案
toggleProjectOpen(projectId)                          // 招募開關
getStudentById(id)                                    // 取得學生資料 + 課表 mask
```

### acceptApplication() 核心邏輯

```typescript
// 1. 更新狀態
app.status = 'ACCEPTED'

// 2. 合併遮罩
project.groupScheduleMask = (BigInt(project.groupScheduleMask) | BigInt(studentMask)).toString()

// 3. 成員數 +1，滿員自動關閉招募
project.currentMembers += 1
if (project.currentMembers >= project.maxMembers) project.isOpen = false

// 4. 自動取消同課程其他 PENDING 申請（Anti-duplicate）
applicationsArray.forEach(a => {
  if (a.studentId === app.studentId && a.status === 'PENDING'
      && a.id !== appId && sameCourseIds.includes(a.projectId)) {
    a.status = 'CANCELED'
  }
})
```

---

## 50-bit 遮罩演算法（scheduleAlgo.ts）

### 位元對應規則

```
bit i → 第 ⌊i/10⌋ + 1 天，第 (i % 10) + 1 節

週一 P1 = bit 0   (day=1, period=1)
週一 P2 = bit 1   (day=1, period=2)
週二 P1 = bit 10  (day=2, period=1)
週三 P1 = bit 20  (day=3, period=1)  ← 學生 A 的課（mask = 1048576 = 2²⁰）
```

### 核心公式

```typescript
// 衝突判斷：兩遮罩有重疊時段
const hasConflict = (groupMask & studentMask) > 0n

// 黃金共同空堂：雙方都空閒的時段
const goldenMask = ~(groupMask | studentMask) & ((1n << 50n) - 1n)

// 還原座標
function decompressMask(mask: bigint): { day: number; period: number }[] {
  const coords = []
  for (let i = 0; i < 50; i++) {
    if ((mask & (1n << BigInt(i))) !== 0n) {
      coords.push({ day: Math.floor(i / 10) + 1, period: (i % 10) + 1 })
    }
  }
  return coords
}
```

### BigInt JSON 序列化

`BigInt` 無法原生 JSON 序列化，`main.ts` 加入 polyfill：

```typescript
;(BigInt.prototype as any).toJSON = function () { return this.toString() }
```

遮罩在 state 中以**字串**儲存，運算時轉回 `BigInt(str)`。

---

## 元件說明

### App.vue（根元件）

- Sticky Navbar + 身份切換 `<select>`
- 依 `currentActiveUser.role` 渲染 `<StudentView>` 或 `<LeaderView>`
- `<Transition name="fade">` 淡入淡出動畫

### StudentView.vue（學生端）

| 功能 | 說明 |
|------|------|
| 兩個 Tab | 探索專案 / 我的申請，Tab 顯示申請計數 badge |
| 課表編輯器 | mousedown / mouseenter / mouseup 實現拖曳圈選；dragSetMode 決定設定或清除 |
| 批次操作 | 全選、全清；貼上 50 字元二進位字串匯入 |
| 遮罩同步 | `watch(studentMask)` → 自動寫入 `userSchedules[userId]`；`onMounted` 從 store 還原 |
| 申請預檢 | `calculateOverlay()` 計算衝突 / 黃金空堂；衝突時隱藏送出按鈕 |
| 送出申請 | 呼叫 `submitApplication()`，成功動畫後 1.2s 自動關閉 Modal |
| 我的申請 | 顯示狀態 badge、拒絕原因、撤回按鈕 |

### LeaderView.vue（組長端）

| 功能 | 說明 |
|------|------|
| 多專案 Tab | 組長可切換自己建立的所有專案 |
| 待審核列表 | 從 `applicationsArray` 過濾 PENDING，即時顯示 |
| 課表疊加看板 | 點擊申請人 → 右側大格子顯示衝突（紅）/ 黃金空堂（綠）/ 組員課（灰） |
| 錄取 | `acceptApplication()`，完成後 mask 合併、成員 +1 |
| 拒絕 Modal | 4 個快速標籤 + 自訂 textarea；`rejectApplication(appId, reason)` |
| 已錄取名冊 | 每位成員顯示迷你 5×10 課表格子 |
| 建立新專案 | Modal 輸入課程代碼、名稱、人數（±按鈕）；`createProject()` |
| 招募開關 | `toggleProjectOpen()`，滿員時自動關閉 |

---

## Mock 使用者

| 身份 | userId | 課表 mask | 說明 |
|------|--------|-----------|------|
| 張小明（學生 A） | 901 | `1048576`（bit 20 = 週三第 1 節） | 無衝突，可正常申請 |
| 李小華（學生 B） | 902 | `3`（bits 0,1 = 週一第 1、2 節） | 與初始專案衝突，示範封鎖 |
| 王組長 | 801 | `0`（全空） | 審核 / 建立專案 |

初始專案 mask = `1125899906842627`（週一 P1、P2 忙碌）

---

## 常用指令

```bash
# 本機開發
npm install
npm run dev          # http://localhost:5173

# 型別檢查
npx tsc --noEmit

# 打包
npm run build        # 輸出到 dist/

# 重新部署（打包 + 部署）
npm run build && npx vercel --prod --yes

# 推送到 GitHub
git add .
git commit -m "說明"
git push
```

---

## 擴充指引

### 新增狀態

在 `globalState.ts` 新增 `ref()` 或 `reactive()` 並 export：

```typescript
export const newState = ref<string>('')
```

### 新增 Action

在 `globalState.ts` 底部新增 function 並 export，直接操作上方 reactive 物件：

```typescript
export function doSomething(id: number) {
  const target = projectsArray.find(p => p.id === id)
  if (target) target.someField = 'newValue'
}
```

### 新增 Mock 使用者

1. `baseUsers` 物件新增一筆
2. `userSchedules` 補上初始 mask（`userId: 'maskString'`）
3. `App.vue` 的 `userOptions` 陣列加入選項

### 修改遮罩邏輯

只改 `scheduleAlgo.ts`，與 UI 完全解耦。改完執行 `npx tsc --noEmit` 確認型別。

---

## 對接真實後端

目前所有狀態在 `globalState.ts` 的 Actions 中以 in-memory 方式運作。  
對接後端時只需：

1. 將各 Action 的邏輯替換為 `fetch()` / `axios` API 呼叫
2. 收到 API 回應後更新對應的 reactive 物件
3. 元件端程式碼**完全不需要修改**（資料流向不變）

```typescript
// 替換前（in-memory）
export function submitApplication(projectId, studentId) {
  applicationsArray.push({ id: nextAppId++, ... })
}

// 替換後（真實 API）
export async function submitApplication(projectId, studentId) {
  const res = await fetch('/api/applications', {
    method: 'POST',
    body: JSON.stringify({ projectId, studentId })
  })
  const app = await res.json()
  applicationsArray.push(app)
}
```
