import { ref, reactive } from 'vue'

export type Role = 'STUDENT' | 'LEADER'
export type ApplicationStatus = 'PENDING' | 'ACCEPTED' | 'REJECTED' | 'CANCELED'

export interface MockUser {
  id: number
  name: string
  role: Role
  skills: string[]
}

export interface Project {
  id: number
  courseCode: string
  title: string
  maxMembers: number
  currentMembers: number
  isOpen: boolean
  groupScheduleMask: string
  leaderId: number
}

export interface Application {
  id: number
  projectId: number
  studentId: number
  status: ApplicationStatus
  rejectReason?: string
  createdAt: string
}

// ── Base user definitions (immutable source) ──────────────────────────
const baseUsers: Record<string, MockUser> = {
  studentA: { id: 901, name: '張小明', role: 'STUDENT', skills: ['Vue3', 'Python', 'Docker'] },
  studentB: { id: 902, name: '李小華', role: 'STUDENT', skills: ['React', 'Node.js', 'MySQL'] },
  leader:   { id: 801, name: '王組長', role: 'LEADER',  skills: [] },
}

// ── Per-user schedule masks (persists across user switches) ───────────
// Spec values: Student A = "1048576" (bit 20, Wed P1 → no conflict)
//              Student B = "3"       (bits 0,1, Mon P1+P2 → conflicts)
export const userSchedules = reactive<Record<number, string>>({
  901: '1048576',
  902: '3',
  801: '0',
})

// ── Reactive global state ─────────────────────────────────────────────
export const currentActiveUser = ref<MockUser>({ ...baseUsers.studentA })

export const projectsArray = reactive<Project[]>([
  {
    id: 1,
    courseCode: 'CS-101-A',
    title: 'AI 雲端影像辨識專案',
    maxMembers: 5,
    currentMembers: 3,
    isOpen: true,
    groupScheduleMask: '1125899906842627', // Mon P1, P2 busy (bits 0,1)
    leaderId: 801,
  },
])

export const applicationsArray = reactive<Application[]>([])

let nextAppId = 1
let nextProjectId = 2

// ── Actions ───────────────────────────────────────────────────────────
export function switchUser(key: string) {
  currentActiveUser.value = { ...baseUsers[key] }
}

export function getStudentById(id: number): (MockUser & { courseScheduleMask: string }) | undefined {
  const user = Object.values(baseUsers).find(u => u.id === id)
  if (!user) return undefined
  return { ...user, courseScheduleMask: userSchedules[id] ?? '0' }
}

export function submitApplication(projectId: number, studentId: number): Application {
  const existing = applicationsArray.find(
    a => a.projectId === projectId && a.studentId === studentId && a.status !== 'CANCELED',
  )
  if (existing) throw new Error('DUPLICATE_APPLICATION')

  const app: Application = {
    id: nextAppId++,
    projectId,
    studentId,
    status: 'PENDING',
    createdAt: new Date().toISOString(),
  }
  applicationsArray.push(app)
  return app
}

export function withdrawApplication(appId: number) {
  const app = applicationsArray.find(a => a.id === appId)
  if (app) app.status = 'CANCELED'
}

export function acceptApplication(appId: number) {
  const app = applicationsArray.find(a => a.id === appId)
  if (!app || app.status !== 'PENDING') return

  const project = projectsArray.find(p => p.id === app.projectId)
  if (!project) return

  const studentMask = userSchedules[app.studentId] ?? '0'

  app.status = 'ACCEPTED'
  project.groupScheduleMask = (BigInt(project.groupScheduleMask) | BigInt(studentMask)).toString()
  project.currentMembers += 1
  if (project.currentMembers >= project.maxMembers) project.isOpen = false

  // Auto-cancel sibling PENDING apps in same courseCode
  const sameCourseIds = projectsArray.filter(p => p.courseCode === project.courseCode).map(p => p.id)
  applicationsArray.forEach(a => {
    if (a.studentId === app.studentId && a.status === 'PENDING' && a.id !== appId && sameCourseIds.includes(a.projectId)) {
      a.status = 'CANCELED'
    }
  })
}

export function rejectApplication(appId: number, reason: string) {
  const app = applicationsArray.find(a => a.id === appId)
  if (app) { app.status = 'REJECTED'; app.rejectReason = reason }
}

export function createProject(courseCode: string, title: string, maxMembers: number, initialMask = '0'): Project {
  const project: Project = {
    id: nextProjectId++,
    courseCode,
    title,
    maxMembers,
    currentMembers: 1,
    isOpen: true,
    groupScheduleMask: initialMask,
    leaderId: currentActiveUser.value.id,
  }
  projectsArray.push(project)
  return project
}

export function toggleProjectOpen(projectId: number) {
  const p = projectsArray.find(p => p.id === projectId)
  if (p) p.isOpen = !p.isOpen
}
