# 智慧組隊媒合系統 — 開發規格文件
> 給 AI coding 助手 / 開發者快速上手的完整參考，涵蓋商業邏輯、資料模型、衝突檢核演算法。

---

## 1. 系統概覽

| 項目 | 說明 |
|------|------|
| 系統名稱 | 智慧組隊媒合系統 (Smart Team Matching System) |
| 目標用戶 | 在校學生（通識課、期末報告、畢業專題、跨系專案） |
| 架構 | 3-Tier：React/Vue → RESTful API (Node.js/FastAPI) → MySQL |
| 核心價值 | 依專長 + 課表 + 課程代碼自動化配對，並在申請前執行三道防衝突檢核 |

---

## 2. 核心功能模組

### 2.1 個人專長管理
- 學生可對自己的 `skills` 紀錄執行 **CRUD**
- 每筆 skill 有 `skill_name`（如 `Python`、`UI設計`）與 `category`（`程式` / `設計` / `軟技能`）
- 一位學生可擁有多筆 skill（一對多）

### 2.2 組隊需求發布
- 學生可建立 `projects`，綁定 `course_code`（課程代碼）
- `max_members`：小組人數上限，**最大值 = 5**
- `current_members`：目前已錄取人數，**預設 = 1**（組長本人已佔一席）
- 當 `current_members >= max_members` 時，`is_open` 自動設為 `FALSE`，前端隱藏申請按鈕
- `deadline`：超過截止日後禁止新申請

### 2.3 加入數量管制
- `students.max_projects`：該學生最多可同時加入幾個專案（由管理員或系統預設）
- 檢核方式（**擇一實作，推薦 B**）：
  - **A（即時查詢）**：`SELECT COUNT(*) FROM applications WHERE student_id = ? AND status = 'accepted'`
  - **B（快取欄位）**：`students.current_projects_count INT DEFAULT 0`，每次錄取 `+1`，退出或拒絕 `-1`

### 2.4 三道衝突檢核（AND 邏輯，任一失敗即阻擋）

> **觸發時機**：學生按下「申請加入」後，後端在寫入 `applications` 前同步執行。

#### 檢核① 人數上限
```
IF projects.current_members >= projects.max_members → BLOCK
  error_code: TEAM_FULL
```

#### 檢核② 身份重複
```
IF EXISTS (
  SELECT 1 FROM applications a
  JOIN projects p ON a.project_id = p.project_id
  WHERE a.student_id = :student_id
    AND p.course_code = :target_course_code
    AND a.status = 'accepted'
) → BLOCK
  error_code: DUPLICATE_ENROLLMENT
```

#### 檢核③ 時間衝突
```
# course_schedule 格式（布林矩陣 5×10）：
# schedule[weekday][period]，weekday: 0=Mon..4=Fri，period: 0..9
# 1 = 有課（忙碌），0 = 空堂（可用）

# 衝突判斷：申請者課表 AND 任一現有組員課表有重疊
FOR each existing_member IN project.members:
  IF applicant.schedule AND member.schedule has overlap → WARN + suggest golden slots

# 黃金共同空堂（推薦開會時段）：
all_members_schedule = [s for s in all members including applicant]
golden_slots = ~(OR of all schedules)  # 所有人都空堂的時段
```

**回傳格式（衝突時）**：
```json
{
  "passed": false,
  "error_code": "TIME_CONFLICT",
  "conflicts": [{"weekday": 1, "period": 3, "member": "B11234567"}],
  "golden_slots": [{"weekday": 2, "period": 6}, {"weekday": 4, "period": 1}]
}
```

**回傳格式（通過時）**：
```json
{
  "passed": true,
  "golden_slots": [{"weekday": 2, "period": 6}, {"weekday": 4, "period": 1}]
}
```

### 2.5 申請審核流程

```
學生送出申請
  → 三道衝突檢核（全通過）
  → INSERT applications (status = 'pending')
  → 通知組長

組長審核
  → status = 'accepted'：projects.current_members +1，students.current_projects_count +1
  → status = 'rejected'：通知申請人原因

當 projects.current_members >= projects.max_members
  → projects.is_open = FALSE（自動關閉）
```

---

## 3. 資料模型摘要

### students
| 欄位 | 型別 | 說明 |
|------|------|------|
| student_id | VARCHAR(10) PK | 學號 |
| name | VARCHAR(50) | 姓名 |
| email | VARCHAR(100) | 信箱（通知用） |
| course_schedule | JSON | 5×10 布林矩陣，見 §2.4 |
| max_projects | TINYINT | 可同時加入上限（預設 3） |
| current_projects_count | TINYINT | 目前已加入數（快取欄位） |

### projects
| 欄位 | 型別 | 說明 |
|------|------|------|
| project_id | INT PK AUTO | 專案 ID |
| course_code | VARCHAR(20) | 課程代碼（身份重複檢核依據） |
| title | VARCHAR(100) | 專案名稱 |
| owner_id | FK → students | 組長學號 |
| max_members | TINYINT | 人數上限（最大 5） |
| current_members | TINYINT | 已錄取人數（預設 1） |
| is_open | BOOLEAN | 是否開放申請 |
| deadline | DATE | 申請截止日 |
| description | TEXT | 專案說明 |

### skills
| 欄位 | 型別 | 說明 |
|------|------|------|
| skill_id | INT PK AUTO | 標籤 ID |
| student_id | FK → students | 所屬學生 |
| skill_name | VARCHAR(50) | 技能名稱 |
| category | ENUM | `programming` / `design` / `soft_skill` / `other` |

### applications
| 欄位 | 型別 | 說明 |
|------|------|------|
| app_id | INT PK AUTO | 申請 ID |
| student_id | FK → students | 申請人 |
| project_id | FK → projects | 目標專案 |
| status | ENUM | `pending` / `accepted` / `rejected` |
| message | TEXT | 申請附言 |
| reject_reason | TEXT | 拒絕原因（組長填寫） |
| applied_at | DATETIME | 申請時間 |
| reviewed_at | DATETIME | 審核時間 |

---

## 4. 業務規則速查

| 規則 | 實作位置 | 說明 |
|------|----------|------|
| 最多 5 人/組 | DB CHECK + API | `max_members <= 5` |
| 組長佔 1 席 | DB DEFAULT | `current_members DEFAULT 1` |
| 同課程禁止重複加隊 | API 檢核② | `course_code + student_id` 聯合查詢 |
| 申請前即時衝突警示 | API 檢核③ | 不寫 DB，只回傳 JSON |
| 錄取後人數 +1 | API PATCH | 事務內同步更新 `current_members` |
| 人數滿自動關閉 | DB TRIGGER / API | `current_members >= max_members → is_open = FALSE` |
| 截止後禁止申請 | API middleware | `deadline < NOW() → 403` |

---

## 5. 課表 JSON 格式規範

```json
// course_schedule 範例：週二第4節、週四第2、3節有課
{
  "schedule": [
    [0,0,0,0,0,0,0,0,0,0],  // 週一 (period 1~10)
    [0,0,0,1,0,0,0,0,0,0],  // 週二 ← 第4節有課
    [0,0,0,0,0,0,0,0,0,0],  // 週三
    [0,1,1,0,0,0,0,0,0,0],  // 週四 ← 第2、3節有課
    [0,0,0,0,0,0,0,0,0,0]   // 週五
  ]
}
```

**黃金共同空堂演算法（Python 虛擬碼）**：
```python
def find_golden_slots(schedules: list[list[list[int]]]) -> list[dict]:
    """
    schedules: 所有組員（含申請者）的 5x10 矩陣清單
    回傳所有人都空堂的時段
    """
    golden = []
    for day in range(5):
        for period in range(10):
            if all(s[day][period] == 0 for s in schedules):
                golden.append({"weekday": day, "period": period + 1})
    return golden
```
