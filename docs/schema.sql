-- ============================================================
-- 智慧組隊媒合系統 — Database Schema
-- Engine: MySQL 8.0+ / MariaDB 10.6+
-- Charset: utf8mb4
-- ============================================================

CREATE DATABASE IF NOT EXISTS team_matching
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE team_matching;

-- ============================================================
-- TABLE 1: students
-- 學生基本資料 + 課表（布林矩陣 JSON）+ 加入數量管制
-- ============================================================
CREATE TABLE students (
  student_id            VARCHAR(10)   NOT NULL COMMENT '學號，例如 B11234567',
  name                  VARCHAR(50)   NOT NULL COMMENT '姓名',
  email                 VARCHAR(100)  NOT NULL UNIQUE COMMENT '校園信箱，用於通知',
  course_schedule       JSON          NOT NULL COMMENT '5x10 布林矩陣：schedule[weekday][period]，1=有課 0=空堂',
  max_projects          TINYINT       NOT NULL DEFAULT 3 COMMENT '同時可加入的專案上限',
  current_projects_count TINYINT     NOT NULL DEFAULT 0 COMMENT '目前已錄取加入的專案數（快取欄位）',
  created_at            DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at            DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (student_id),
  CONSTRAINT chk_max_projects CHECK (max_projects BETWEEN 1 AND 10),
  CONSTRAINT chk_current_projects CHECK (current_projects_count >= 0)
) ENGINE=InnoDB COMMENT='學生表';

-- ============================================================
-- TABLE 2: projects
-- 組隊需求；組長建立後開放申請
-- ============================================================
CREATE TABLE projects (
  project_id      INT           NOT NULL AUTO_INCREMENT COMMENT '專案流水號',
  course_code     VARCHAR(20)   NOT NULL COMMENT '課程代碼，身份重複檢核的依據',
  title           VARCHAR(100)  NOT NULL COMMENT '專案名稱',
  description     TEXT                   COMMENT '專案說明、需求描述',
  owner_id        VARCHAR(10)   NOT NULL COMMENT '組長學號',
  max_members     TINYINT       NOT NULL DEFAULT 5 COMMENT '人數上限（含組長，最大 5）',
  current_members TINYINT       NOT NULL DEFAULT 1 COMMENT '已錄取人數（預設 1，因組長已佔一席）',
  is_open         BOOLEAN       NOT NULL DEFAULT TRUE COMMENT '是否開放申請；滿員或截止後自動 FALSE',
  deadline        DATE                   COMMENT '申請截止日，NULL 表示不限',
  created_at      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (project_id),
  FOREIGN KEY (owner_id) REFERENCES students(student_id) ON DELETE RESTRICT,
  CONSTRAINT chk_max_members  CHECK (max_members BETWEEN 2 AND 5),
  CONSTRAINT chk_cur_members  CHECK (current_members >= 1),
  CONSTRAINT chk_members_cap  CHECK (current_members <= max_members),
  INDEX idx_course_code (course_code),
  INDEX idx_is_open (is_open),
  INDEX idx_owner (owner_id)
) ENGINE=InnoDB COMMENT='組隊需求（專案）表';

-- ============================================================
-- TABLE 3: skills
-- 學生專長標籤，多對一關聯 students
-- ============================================================
CREATE TABLE skills (
  skill_id    INT          NOT NULL AUTO_INCREMENT,
  student_id  VARCHAR(10)  NOT NULL COMMENT '所屬學生',
  skill_name  VARCHAR(50)  NOT NULL COMMENT '技能名稱，例如 Python、UI設計',
  category    ENUM(
    'programming',  -- 程式開發
    'design',       -- 設計（UI/UX/平面）
    'soft_skill',   -- 軟技能（簡報、溝通）
    'media',        -- 影音剪輯、攝影
    'other'
  ) NOT NULL DEFAULT 'other',
  created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (skill_id),
  FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE,
  UNIQUE KEY uq_student_skill (student_id, skill_name),  -- 同一學生不能重複新增同名技能
  INDEX idx_skill_name (skill_name),
  INDEX idx_category (category)
) ENGINE=InnoDB COMMENT='學生專長標籤表';

-- ============================================================
-- TABLE 4: applications  ← 系統核心樞紐
-- 申請紀錄；status 欄位驅動整個狀態機
-- ============================================================
CREATE TABLE applications (
  app_id          INT          NOT NULL AUTO_INCREMENT,
  student_id      VARCHAR(10)  NOT NULL COMMENT '申請人學號',
  project_id      INT          NOT NULL COMMENT '目標專案',
  status          ENUM(
    'pending',    -- 待審核（剛送出）
    'accepted',   -- 已錄取
    'rejected'    -- 已拒絕
  ) NOT NULL DEFAULT 'pending',
  message         TEXT                  COMMENT '申請人附言',
  reject_reason   TEXT                  COMMENT '拒絕原因（組長填寫）',
  applied_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  reviewed_at     DATETIME              COMMENT '組長審核時間',

  PRIMARY KEY (app_id),
  FOREIGN KEY (student_id) REFERENCES students(student_id) ON DELETE CASCADE,
  FOREIGN KEY (project_id) REFERENCES projects(project_id) ON DELETE CASCADE,

  -- 同一學生不能對同一專案重複申請（避免重送）
  UNIQUE KEY uq_student_project (student_id, project_id),

  INDEX idx_status (status),
  INDEX idx_project_status (project_id, status),
  INDEX idx_student_status (student_id, status)
) ENGINE=InnoDB COMMENT='申請紀錄表（系統狀態機樞紐）';

-- ============================================================
-- TRIGGER: 錄取後自動維護計數欄位 & 關閉滿員專案
-- ============================================================

DELIMITER $$

-- 當 application.status 更新為 accepted → 同步更新計數
CREATE TRIGGER trg_application_accepted
AFTER UPDATE ON applications
FOR EACH ROW
BEGIN
  -- 從 pending → accepted：人數 +1
  IF OLD.status != 'accepted' AND NEW.status = 'accepted' THEN
    UPDATE projects
    SET
      current_members = current_members + 1,
      is_open = (current_members + 1 < max_members)  -- 更新後若滿員則關閉
    WHERE project_id = NEW.project_id;

    UPDATE students
    SET current_projects_count = current_projects_count + 1
    WHERE student_id = NEW.student_id;
  END IF;

  -- 從 accepted 撤銷（→ rejected 或 pending）：人數 -1
  IF OLD.status = 'accepted' AND NEW.status != 'accepted' THEN
    UPDATE projects
    SET
      current_members = GREATEST(current_members - 1, 1),
      is_open = TRUE
    WHERE project_id = NEW.project_id;

    UPDATE students
    SET current_projects_count = GREATEST(current_projects_count - 1, 0)
    WHERE student_id = NEW.student_id;
  END IF;
END$$

DELIMITER ;

-- ============================================================
-- VIEW: 方便 API 查詢的常用視圖
-- ============================================================

-- 開放中的專案（含組長姓名、已錄取人數）
CREATE VIEW v_open_projects AS
SELECT
  p.project_id,
  p.course_code,
  p.title,
  p.description,
  p.max_members,
  p.current_members,
  p.max_members - p.current_members AS slots_remaining,
  p.deadline,
  s.student_id  AS owner_id,
  s.name        AS owner_name
FROM projects p
JOIN students s ON p.owner_id = s.student_id
WHERE p.is_open = TRUE
  AND (p.deadline IS NULL OR p.deadline >= CURDATE());

-- 申請紀錄（含申請人姓名、專案標題）
CREATE VIEW v_applications_detail AS
SELECT
  a.app_id,
  a.status,
  a.applied_at,
  a.reviewed_at,
  a.message,
  a.reject_reason,
  s.student_id,
  s.name        AS applicant_name,
  s.email       AS applicant_email,
  p.project_id,
  p.title       AS project_title,
  p.course_code,
  p.owner_id
FROM applications a
JOIN students s ON a.student_id = s.student_id
JOIN projects p ON a.project_id = p.project_id;

-- ============================================================
-- USEFUL QUERIES（給後端開發者的常用查詢範例）
-- ============================================================

-- [檢核①] 確認專案未滿員
-- SELECT current_members < max_members AS can_join
-- FROM projects WHERE project_id = :pid AND is_open = TRUE;

-- [檢核②] 身份重複：同課程是否已有錄取紀錄
-- SELECT COUNT(*) AS duplicate_count
-- FROM applications a
-- JOIN projects p ON a.project_id = p.project_id
-- WHERE a.student_id = :sid
--   AND p.course_code = :course_code
--   AND a.status = 'accepted';

-- [檢核③ 前置] 取得同專案所有錄取組員課表（含組長）
-- SELECT s.student_id, s.course_schedule
-- FROM applications a
-- JOIN students s ON a.student_id = s.student_id
-- WHERE a.project_id = :pid AND a.status = 'accepted'
-- UNION
-- SELECT s.student_id, s.course_schedule
-- FROM projects p JOIN students s ON p.owner_id = s.student_id
-- WHERE p.project_id = :pid;

-- [加入數量管制] 即時查詢版（替代 current_projects_count）
-- SELECT COUNT(*) AS active_count
-- FROM applications
-- WHERE student_id = :sid AND status = 'accepted';

-- ============================================================
-- SEED DATA（測試用）
-- ============================================================

INSERT INTO students (student_id, name, email, course_schedule, max_projects) VALUES
(
  'B11234567', '王小明', 'b11234567@mail.edu.tw',
  '{"schedule":[[0,0,1,1,0,0,0,0,0,0],[0,0,0,0,1,0,0,0,0,0],[0,1,1,0,0,0,0,0,0,0],[0,0,0,0,0,0,1,0,0,0],[0,0,0,0,0,0,0,0,0,0]]}',
  3
),
(
  'B11234568', '李小花', 'b11234568@mail.edu.tw',
  '{"schedule":[[0,0,0,0,0,0,0,0,0,0],[0,0,0,1,1,0,0,0,0,0],[0,0,1,1,0,0,0,0,0,0],[0,0,0,0,0,0,0,0,0,0],[0,1,0,0,0,0,0,0,0,0]]}',
  3
);

INSERT INTO projects (course_code, title, description, owner_id, max_members) VALUES
('CS301', '校園智慧組隊系統', '期末專題，需要前端+後端各一人', 'B11234567', 4);

INSERT INTO skills (student_id, skill_name, category) VALUES
('B11234567', 'Python',     'programming'),
('B11234567', 'FastAPI',    'programming'),
('B11234567', 'PPT製作',    'soft_skill'),
('B11234568', 'React',      'programming'),
('B11234568', 'UI設計',     'design'),
('B11234568', '影音剪輯',   'media');
