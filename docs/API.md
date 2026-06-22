# 智慧組隊媒合系統 — API 參考文件
> Base URL: `https://api.team-matching.edu.tw/v1`
> Auth: Bearer Token（學校 SSO，每個請求帶 `Authorization: Bearer <token>`）
> 回應格式：全部為 `application/json`

---

## 錯誤代碼速查

| error_code | HTTP | 說明 |
|------------|------|------|
| `TEAM_FULL` | 409 | 專案人數已達上限 |
| `DUPLICATE_ENROLLMENT` | 409 | 同課程已有錄取紀錄 |
| `TIME_CONFLICT` | 409 | 課表時間衝突 |
| `QUOTA_EXCEEDED` | 409 | 個人加入專案數達上限 |
| `PROJECT_CLOSED` | 403 | 專案已關閉或超過截止日 |
| `NOT_OWNER` | 403 | 非組長，無審核權限 |
| `NOT_FOUND` | 404 | 資源不存在 |
| `VALIDATION_ERROR` | 422 | 欄位格式錯誤 |

---

## 學生 /students

### GET /students/:student_id
取得學生資料（含技能列表）

**Response 200**
```json
{
  "student_id": "B11234567",
  "name": "王小明",
  "email": "b11234567@mail.edu.tw",
  "max_projects": 3,
  "current_projects_count": 1,
  "course_schedule": {
    "schedule": [
      [0,0,1,1,0,0,0,0,0,0],
      [0,0,0,0,1,0,0,0,0,0],
      [0,1,1,0,0,0,0,0,0,0],
      [0,0,0,0,0,0,1,0,0,0],
      [0,0,0,0,0,0,0,0,0,0]
    ]
  },
  "skills": [
    {"skill_id": 1, "skill_name": "Python", "category": "programming"},
    {"skill_id": 2, "skill_name": "FastAPI", "category": "programming"}
  ]
}
```

### PATCH /students/:student_id/schedule
更新學生課表

**Request Body**
```json
{
  "schedule": [
    [0,0,1,1,0,0,0,0,0,0],
    [0,0,0,0,1,0,0,0,0,0],
    [0,1,1,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,1,0,0,0],
    [0,0,0,0,0,0,0,0,0,0]
  ]
}
```
**Validation**：必須是 5×10 的二維陣列，值只能是 0 或 1

**Response 200**
```json
{ "updated": true }
```

---

## 技能 /students/:student_id/skills

### GET /students/:student_id/skills
列出該學生所有技能標籤

**Response 200**
```json
{
  "skills": [
    {"skill_id": 1, "skill_name": "Python", "category": "programming"},
    {"skill_id": 3, "skill_name": "PPT製作", "category": "soft_skill"}
  ]
}
```

### POST /students/:student_id/skills
新增技能標籤

**Request Body**
```json
{
  "skill_name": "React",
  "category": "programming"
}
```

**Response 201**
```json
{
  "skill_id": 4,
  "skill_name": "React",
  "category": "programming"
}
```

**Error（重複）409**
```json
{ "error_code": "VALIDATION_ERROR", "message": "技能「React」已存在" }
```

### DELETE /students/:student_id/skills/:skill_id
刪除技能標籤

**Response 200**
```json
{ "deleted": true }
```

---

## 專案 /projects

### GET /projects
探索頁：取得開放中的專案列表

**Query Params**
| 參數 | 型別 | 說明 |
|------|------|------|
| `course_code` | string | 篩選課程代碼 |
| `skill` | string | 篩選需求技能（模糊比對） |
| `page` | int | 頁碼（預設 1） |
| `limit` | int | 每頁筆數（預設 20，最大 50） |

**Response 200**
```json
{
  "total": 42,
  "page": 1,
  "data": [
    {
      "project_id": 1,
      "course_code": "CS301",
      "title": "校園智慧組隊系統",
      "description": "期末專題，需要前端+後端各一人",
      "owner_name": "王小明",
      "max_members": 4,
      "current_members": 2,
      "slots_remaining": 2,
      "deadline": "2026-06-30",
      "is_open": true
    }
  ]
}
```

### POST /projects
建立新組隊需求（目前登入學生自動成為組長）

**Request Body**
```json
{
  "course_code": "CS301",
  "title": "校園智慧組隊系統",
  "description": "期末專題，需要前端+後端各一人",
  "max_members": 4,
  "deadline": "2026-06-30"
}
```

**Validation**
- `max_members`：2 ~ 5
- `course_code`：必填，不可空白

**Response 201**
```json
{
  "project_id": 1,
  "course_code": "CS301",
  "title": "校園智慧組隊系統",
  "max_members": 4,
  "current_members": 1,
  "is_open": true
}
```

### GET /projects/:project_id
取得專案詳情（含成員列表與技能）

**Response 200**
```json
{
  "project_id": 1,
  "course_code": "CS301",
  "title": "校園智慧組隊系統",
  "description": "期末專題，需要前端+後端各一人",
  "max_members": 4,
  "current_members": 2,
  "is_open": true,
  "deadline": "2026-06-30",
  "owner": {
    "student_id": "B11234567",
    "name": "王小明"
  },
  "members": [
    {
      "student_id": "B11234567",
      "name": "王小明",
      "skills": ["Python", "FastAPI"],
      "role": "owner"
    },
    {
      "student_id": "B11234568",
      "name": "李小花",
      "skills": ["React", "UI設計"],
      "role": "member"
    }
  ]
}
```

---

## 衝突檢核 /projects/:project_id/check

### POST /projects/:project_id/check
**申請前預檢（不寫入 DB）**，前端在送出申請前主動呼叫

**Request Body**
```json
{
  "student_id": "B11234569"
}
```

**Response 200（全部通過）**
```json
{
  "passed": true,
  "golden_slots": [
    {"weekday": 2, "period": 6, "label": "週三 第6節"},
    {"weekday": 4, "period": 1, "label": "週五 第1節"}
  ]
}
```

**Response 409（任一不通過，立即回傳，不繼續後面的檢核）**
```json
{
  "passed": false,
  "error_code": "TIME_CONFLICT",
  "message": "您的課表與組員課表有衝突",
  "conflicts": [
    {
      "weekday": 1,
      "period": 4,
      "label": "週二 第4節",
      "conflicting_member": "B11234568"
    }
  ],
  "golden_slots": [
    {"weekday": 2, "period": 6, "label": "週三 第6節"}
  ]
}
```

**error_code 可能值**（按檢核順序）：
1. `TEAM_FULL`
2. `DUPLICATE_ENROLLMENT`
3. `TIME_CONFLICT`
4. `QUOTA_EXCEEDED`

---

## 申請 /applications

### POST /applications
送出加入申請（後端再次執行完整三道檢核）

**Request Body**
```json
{
  "project_id": 1,
  "message": "我擅長 React 開發，希望能參與前端部分"
}
```

**Response 201（申請成功）**
```json
{
  "app_id": 7,
  "project_id": 1,
  "status": "pending",
  "applied_at": "2026-06-22T14:30:00Z"
}
```

**Response 409（衝突阻擋，同 /check 格式）**
```json
{
  "passed": false,
  "error_code": "DUPLICATE_ENROLLMENT",
  "message": "您已在同課程（CS301）的其他小組中"
}
```

### GET /applications?student_id=:id
取得個人申請紀錄

**Response 200**
```json
{
  "data": [
    {
      "app_id": 7,
      "project_id": 1,
      "project_title": "校園智慧組隊系統",
      "course_code": "CS301",
      "status": "pending",
      "applied_at": "2026-06-22T14:30:00Z",
      "reviewed_at": null,
      "reject_reason": null
    }
  ]
}
```

---

## 組長審核 /projects/:project_id/applications

### GET /projects/:project_id/applications
組長查看該專案的所有申請（僅組長可呼叫）

**Response 200**
```json
{
  "data": [
    {
      "app_id": 7,
      "status": "pending",
      "message": "我擅長 React 開發",
      "applied_at": "2026-06-22T14:30:00Z",
      "applicant": {
        "student_id": "B11234569",
        "name": "陳大偉",
        "skills": ["React", "TypeScript", "UI設計"],
        "free_slots": [
          {"weekday": 2, "period": 6, "label": "週三 第6節"},
          {"weekday": 4, "period": 1, "label": "週五 第1節"}
        ]
      }
    }
  ]
}
```
> `free_slots` 為申請人與現有組員的**共同空堂**，組長審核時可直接看到可開會時段

### PATCH /applications/:app_id
組長錄取或拒絕（僅組長可呼叫）

**Request Body（錄取）**
```json
{
  "status": "accepted"
}
```

**Request Body（拒絕）**
```json
{
  "status": "rejected",
  "reject_reason": "目前前端名額已滿"
}
```

**Response 200**
```json
{
  "app_id": 7,
  "status": "accepted",
  "reviewed_at": "2026-06-22T15:00:00Z"
}
```

> **後端副作用（事務內執行）**：
> - `accepted`：`projects.current_members +1`，`students.current_projects_count +1`，若滿員則 `projects.is_open = FALSE`
> - `rejected`：寄通知信給申請人

---

## 後端衝突檢核實作虛擬碼

```python
def run_conflict_checks(student_id: str, project_id: int) -> CheckResult:
    project = db.get_project(project_id)
    student = db.get_student(student_id)

    # 基本資格
    if not project.is_open or project.deadline < today():
        raise ProjectClosed()

    # 檢核① 人數上限
    if project.current_members >= project.max_members:
        return CheckResult(passed=False, error_code="TEAM_FULL")

    # 檢核② 身份重複（同課程）
    if db.has_accepted_in_course(student_id, project.course_code):
        return CheckResult(passed=False, error_code="DUPLICATE_ENROLLMENT")

    # 檢核③ 時間衝突
    member_schedules = db.get_member_schedules(project_id)  # 含組長
    applicant_schedule = student.course_schedule["schedule"]
    all_schedules = member_schedules + [applicant_schedule]

    conflicts = find_conflicts(applicant_schedule, member_schedules)
    golden_slots = find_golden_slots(all_schedules)

    if conflicts:
        return CheckResult(
            passed=False,
            error_code="TIME_CONFLICT",
            conflicts=conflicts,
            golden_slots=golden_slots
        )

    # 個人配額（加入數量管制）
    if student.current_projects_count >= student.max_projects:
        return CheckResult(passed=False, error_code="QUOTA_EXCEEDED")

    return CheckResult(passed=True, golden_slots=golden_slots)
```
