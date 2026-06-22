# 專案組隊媒合系統 — Project Matchmaking Demo

> 以 50-bit BigInt 遮罩演算法實現課表衝突偵測與組隊媒合的前端 Demo

**線上展示：** https://matchmaking-demo-eta.vercel.app

## 功能總覽

- **身份切換**：三種 Mock 使用者（空閒學生 / 衝突學生 / 組長），無需登入
- **課表編輯器**：拖曳圈選 5×10 格子，支援全選、全清、貼上 50-bit 二進位字串匯入
- **申請預檢**：即時計算衝突格（紅）與黃金共同空堂（綠），衝突時封鎖送出
- **申請追蹤**：我的申請分頁，顯示審核中 / 已錄取 / 已拒絕 / 撤回
- **組長審核**：課表疊加看板、快速錄取 / 拒絕（含原因標籤）
- **專案管理**：建立新專案、招募開關、已錄取成員名冊

## 技術架構

| 層次 | 技術 |
|------|------|
| 框架 | Vue 3 Composition API + TypeScript |
| 建構 | Vite 8 |
| 樣式 | Tailwind CSS v3 |
| 狀態 | 原生 `ref()` + `reactive()`（無 Vuex/Pinia） |
| 演算法 | 50-bit BigInt 遮罩（`src/utils/scheduleAlgo.ts`） |
| 部署 | Vercel（靜態 SPA，零後端） |

## 50-bit 遮罩演算法

```
bit i → 第 ⌊i/10⌋+1 天，第 (i%10)+1 節
衝突 = (groupMask & studentMask) > 0n
黃金空堂 = ~(groupMask | studentMask) & ((1n<<50n)-1n)
```

## Mock 使用者

| 身份 | userId | 遮罩 | 說明 |
|------|--------|------|------|
| 張小明（學生 A） | 901 | `1048576`（週三第 1 節） | 無衝突，可正常申請 |
| 李小華（學生 B） | 902 | `3`（週一第 1、2 節） | 與初始專案衝突 |
| 王組長 | 801 | `0` | 審核 / 建立專案 |

## 本機開發

```bash
npm install
npm run dev        # http://localhost:5173
npm run build      # 打包到 dist/
npx vercel --prod  # 重新部署
```

## 文件

| 文件 | 說明 |
|------|------|
| [docs/SPEC.md](docs/SPEC.md) | 系統規格說明 |
| [docs/API.md](docs/API.md) | API 介面文件 |
| [docs/schema.sql](docs/schema.sql) | 資料庫 Schema |

## 專案結構

```
src/
├── store/
│   └── globalState.ts     # 全局狀態與 Actions（唯一資料源）
├── utils/
│   └── scheduleAlgo.ts    # 50-bit 遮罩演算法（純函數）
├── components/
│   ├── StudentView.vue    # 學生端
│   └── LeaderView.vue     # 組長端
├── App.vue                # Navbar + 身份路由
└── main.ts                # 入口（BigInt polyfill）
```
