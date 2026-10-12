#!/usr/bin/env node
import { randomUUID } from "node:crypto";
import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { createMcpExpressApp } from "@modelcontextprotocol/sdk/server/express.js";
import { z } from "zod";

const dataDirectory = join(homedir(), "Library", "Application Support", "ProgressTracker");
const tasksFile = process.env.PROGRESS_TRACKER_TASKS_FILE || join(dataDirectory, "tasks.json");
const eventsFile = process.env.PROGRESS_TRACKER_EVENTS_FILE || join(dataDirectory, "events.json");
const focusFile = process.env.PROGRESS_TRACKER_FOCUS_FILE || join(dataDirectory, "focus.json");
const swiftEpochOffset = 978307200;

function toSwiftDate(date) {
  return date.getTime() / 1000 - swiftEpochOffset;
}

function fromSwiftDate(value) {
  return new Date((value + swiftEpochOffset) * 1000);
}

function dayKey(date) {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`;
}

function eventOccursOn(event, requestedDate) {
  const start = fromSwiftDate(event.startDate);
  const requested = new Date(`${requestedDate}T12:00:00`);
  const startDay = new Date(start.getFullYear(), start.getMonth(), start.getDate());
  const requestedDay = new Date(requested.getFullYear(), requested.getMonth(), requested.getDate());
  if (requestedDay < startDay) return false;

  switch (event.recurrence || "none") {
    case "weekly": {
      const weekdays = event.recurrenceWeekdays?.length ? event.recurrenceWeekdays : [start.getDay() + 1];
      return weekdays.includes(requested.getDay() + 1);
    }
    case "monthly":
      return requested.getDate() === start.getDate();
    case "yearly":
      return requested.getMonth() === start.getMonth() && requested.getDate() === start.getDate();
    default:
      return dayKey(start) === requestedDate;
  }
}

async function readTasks() {
  try {
    const value = JSON.parse(await readFile(tasksFile, "utf8"));
    if (!Array.isArray(value)) throw new Error("Task data is not an array");
    return value.map((task) => ({
      ...task,
      project: task.project || "Inbox",
      priority: ["Low", "Medium", "High"].includes(task.priority) ? task.priority : "Medium",
      dueDate: task.dueDate ?? task.createdAt,
    }));
  } catch (error) {
    if (error?.code === "ENOENT") return [];
    throw error;
  }
}

async function readEvents() {
  try {
    const value = JSON.parse(await readFile(eventsFile, "utf8"));
    if (!Array.isArray(value)) throw new Error("Event data is not an array");
    return value.map((event) => ({
      ...event,
      recurrence: event.recurrence || "none",
      recurrenceWeekdays: event.recurrenceWeekdays || [],
    }));
  } catch (error) {
    if (error?.code === "ENOENT") return [];
    throw error;
  }
}

async function saveEvents(events) {
  await mkdir(dirname(eventsFile), { recursive: true });
  const temporaryFile = `${eventsFile}.${process.pid}.tmp`;
  await writeFile(temporaryFile, JSON.stringify(events), "utf8");
  await rename(temporaryFile, eventsFile);
}

async function readFocus() {
  let focus;
  try {
    focus = JSON.parse(await readFile(focusFile, "utf8"));
  } catch (error) {
    if (error?.code !== "ENOENT") throw error;
    focus = {
      selectedMinutes: 25,
      remainingSeconds: 1500,
      isRunning: false,
      endDate: null,
      hasStarted: false,
      isFinished: false,
      completedSessions: 0,
    };
  }

  if (focus.isRunning && focus.endDate != null) {
    focus.remainingSeconds = Math.max(0, Math.ceil((fromSwiftDate(focus.endDate).getTime() - Date.now()) / 1000));
    if (focus.remainingSeconds === 0) {
      focus.isRunning = false;
      focus.endDate = null;
      focus.isFinished = true;
      focus.completedSessions = (focus.completedSessions || 0) + 1;
      await saveFocus(focus);
    }
  }
  return focus;
}

async function saveFocus(focus) {
  await mkdir(dirname(focusFile), { recursive: true });
  const temporaryFile = `${focusFile}.${process.pid}.tmp`;
  await writeFile(temporaryFile, JSON.stringify(focus), "utf8");
  await rename(temporaryFile, focusFile);
}

function focusResult(focus) {
  const totalSeconds = focus.selectedMinutes * 60;
  return {
    ...focus,
    progressPercent: totalSeconds === 0 ? 0 : Math.round((1 - focus.remainingSeconds / totalSeconds) * 100),
    endAt: focus.endDate == null ? null : fromSwiftDate(focus.endDate).toISOString(),
  };
}

async function saveTasks(tasks) {
  await mkdir(dirname(tasksFile), { recursive: true });
  const temporaryFile = `${tasksFile}.${process.pid}.tmp`;
  await writeFile(temporaryFile, JSON.stringify(tasks), "utf8");
  await rename(temporaryFile, tasksFile);
}

function summary(tasks) {
  const completed = tasks.filter((task) => task.isCompleted).length;
  return {
    total: tasks.length,
    completed,
    remaining: tasks.length - completed,
    percent: tasks.length === 0 ? 0 : Math.round((completed / tasks.length) * 100),
  };
}

function result(value) {
  return {
    content: [{ type: "text", text: JSON.stringify(value, null, 2) }],
    structuredContent: value,
  };
}

function errorResult(message) {
  return { content: [{ type: "text", text: message }], isError: true };
}

async function updateTask(taskId, completed) {
  const tasks = await readTasks();
  const task = tasks.find((item) => item.id === taskId);
  if (!task) return null;
  task.isCompleted = completed;
  await saveTasks(tasks);
  return { task, progress: summary(tasks) };
}

function createServer() {
const server = new McpServer({ name: "progress-tracker", version: "1.0.0" });

server.registerTool(
  "list_tasks",
  {
    title: "List Progress Tracker tasks",
    description: "List to-do tasks stored by the Progress Tracker macOS app.",
    inputSchema: {
      status: z.enum(["all", "open", "completed"]).default("all").describe("Filter tasks by completion state"),
      project: z.string().optional().describe("Only return tasks in this project"),
      priority: z.enum(["Low", "Medium", "High"]).optional().describe("Only return tasks with this priority"),
    },
    annotations: { readOnlyHint: true, openWorldHint: false },
  },
  async ({ status, project, priority }) => {
    const tasks = await readTasks();
    const filtered = tasks.filter((task) =>
      (status === "all" || (status === "completed" ? task.isCompleted : !task.isCompleted)) &&
      (!project || task.project === project) &&
      (!priority || task.priority === priority),
    );
    return result({ tasks: filtered, progress: summary(tasks) });
  },
);

server.registerTool(
  "get_progress",
  {
    title: "Get task progress",
    description: "Get total, completed, remaining, and completion percentage.",
    inputSchema: {},
    annotations: { readOnlyHint: true, openWorldHint: false },
  },
  async () => result(summary(await readTasks())),
);

server.registerTool(
  "add_task",
  {
    title: "Add a task",
    description: "Add a new open task to the Progress Tracker app.",
    inputSchema: {
      title: z.string().trim().min(1).max(500).describe("The task text"),
      project: z.string().trim().min(1).max(100).default("Inbox").describe("Project name"),
      priority: z.enum(["Low", "Medium", "High"]).default("Medium").describe("Task priority"),
      due_date: z.string().optional().describe("Due date in YYYY-MM-DD format; defaults to today"),
    },
    annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: false },
  },
  async ({ title, project, priority, due_date }) => {
    const tasks = await readTasks();
    const task = {
      id: randomUUID().toUpperCase(),
      title: title.trim(),
      isCompleted: false,
      project,
      priority,
      dueDate: toSwiftDate(due_date ? new Date(`${due_date}T12:00:00`) : new Date()),
      // Swift's default Codable Date uses seconds since 2001-01-01.
      createdAt: toSwiftDate(new Date()),
    };
    tasks.unshift(task);
    await saveTasks(tasks);
    return result({ task, progress: summary(tasks) });
  },
);

server.registerTool(
  "complete_task",
  {
    title: "Complete a task",
    description: "Mark a Progress Tracker task as completed. Use list_tasks to obtain its ID.",
    inputSchema: { task_id: z.string().uuid().describe("Task UUID from list_tasks") },
    annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: true, openWorldHint: false },
  },
  async ({ task_id }) => {
    const updated = await updateTask(task_id, true);
    return updated ? result(updated) : errorResult(`Task not found: ${task_id}`);
  },
);

server.registerTool(
  "reopen_task",
  {
    title: "Reopen a task",
    description: "Mark a completed Progress Tracker task as open.",
    inputSchema: { task_id: z.string().uuid().describe("Task UUID from list_tasks") },
    annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: true, openWorldHint: false },
  },
  async ({ task_id }) => {
    const updated = await updateTask(task_id, false);
    return updated ? result(updated) : errorResult(`Task not found: ${task_id}`);
  },
);

server.registerTool(
  "organize_task",
  {
    title: "Set task project and priority",
    description: "Change the project and/or priority of a Progress Tracker task.",
    inputSchema: {
      task_id: z.string().uuid().describe("Task UUID from list_tasks"),
      project: z.string().trim().min(1).max(100).optional().describe("New project name"),
      priority: z.enum(["Low", "Medium", "High"]).optional().describe("New priority"),
      due_date: z.string().optional().describe("New due date in YYYY-MM-DD format"),
    },
    annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: true, openWorldHint: false },
  },
  async ({ task_id, project, priority, due_date }) => {
    if (!project && !priority && !due_date) return errorResult("Provide project, priority, due_date, or a combination.");
    const tasks = await readTasks();
    const task = tasks.find((item) => item.id === task_id);
    if (!task) return errorResult(`Task not found: ${task_id}`);
    if (project) task.project = project;
    if (priority) task.priority = priority;
    if (due_date) task.dueDate = toSwiftDate(new Date(`${due_date}T12:00:00`));
    await saveTasks(tasks);
    return result({ task, progress: summary(tasks) });
  },
);

server.registerTool(
  "get_calendar_day",
  {
    title: "Get a calendar day",
    description: "Get calendar events and to-do tasks separately for one day.",
    inputSchema: { date: z.string().describe("Date in YYYY-MM-DD format") },
    annotations: { readOnlyHint: true, openWorldHint: false },
  },
  async ({ date }) => {
    const tasks = await readTasks();
    const events = await readEvents();
    const dayTasks = tasks.filter((task) => dayKey(fromSwiftDate(task.dueDate)) === date);
    const dayEvents = events
      .filter((event) => eventOccursOn(event, date))
      .map((event) => ({ ...event, startsAt: fromSwiftDate(event.startDate).toISOString() }));
    return result({ date, events: dayEvents, tasks: dayTasks });
  },
);

server.registerTool(
  "add_event",
  {
    title: "Add calendar event",
    description: "Add an event to the Progress Tracker calendar.",
    inputSchema: {
      title: z.string().trim().min(1).max(500).describe("Event title"),
      starts_at: z.string().describe("First event start date and time as ISO 8601"),
      recurrence: z.enum(["none", "weekly", "monthly", "yearly"]).default("none").describe("Recurrence frequency"),
      weekdays: z.array(z.number().int().min(1).max(7)).optional().describe("For weekly events: weekdays where 1 is Sunday and 7 is Saturday"),
    },
    annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: false },
  },
  async ({ title, starts_at, recurrence, weekdays }) => {
    const start = new Date(starts_at);
    if (Number.isNaN(start.getTime())) return errorResult("starts_at must be a valid ISO 8601 date and time.");
    const events = await readEvents();
    const recurrenceWeekdays = recurrence === "weekly"
      ? ([...new Set(weekdays?.length ? weekdays : [start.getDay() + 1])].sort())
      : [];
    const event = {
      id: randomUUID().toUpperCase(),
      title: title.trim(),
      startDate: toSwiftDate(start),
      recurrence,
      recurrenceWeekdays,
    };
    events.push(event);
    events.sort((a, b) => a.startDate - b.startDate);
    await saveEvents(events);
    return result({ ...event, startsAt: start.toISOString() });
  },
);

server.registerTool(
  "delete_event",
  {
    title: "Delete calendar event",
    description: "Permanently delete an event or its entire recurring series from the Progress Tracker calendar.",
    inputSchema: { event_id: z.string().uuid().describe("Event UUID from get_calendar_day") },
    annotations: { readOnlyHint: false, destructiveHint: true, idempotentHint: true, openWorldHint: false },
  },
  async ({ event_id }) => {
    const events = await readEvents();
    const index = events.findIndex((event) => event.id === event_id);
    if (index === -1) return errorResult(`Event not found: ${event_id}`);
    const [deleted] = events.splice(index, 1);
    await saveEvents(events);
    return result({ deleted });
  },
);

server.registerTool(
  "get_focus_status",
  {
    title: "Get focus timer status",
    description: "Get the Focus mode timer, tree growth, and completed session count.",
    inputSchema: {},
    annotations: { readOnlyHint: true, openWorldHint: false },
  },
  async () => result(focusResult(await readFocus())),
);

server.registerTool(
  "start_focus",
  {
    title: "Start focus session",
    description: "Start a new Focus mode session and begin growing a tree.",
    inputSchema: {
      minutes: z.enum(["15", "25", "45"]).default("25").describe("Focus duration in minutes"),
    },
    annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: false },
  },
  async ({ minutes }) => {
    const focus = await readFocus();
    const duration = Number(minutes);
    focus.selectedMinutes = duration;
    focus.remainingSeconds = duration * 60;
    focus.isRunning = true;
    focus.endDate = toSwiftDate(new Date(Date.now() + duration * 60 * 1000));
    focus.hasStarted = true;
    focus.isFinished = false;
    await saveFocus(focus);
    return result(focusResult(focus));
  },
);

server.registerTool(
  "pause_focus",
  {
    title: "Pause focus session",
    description: "Manually pause the currently running Focus mode timer.",
    inputSchema: {},
    annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: true, openWorldHint: false },
  },
  async () => {
    const focus = await readFocus();
    if (!focus.isRunning) return result(focusResult(focus));
    focus.isRunning = false;
    focus.endDate = null;
    await saveFocus(focus);
    return result(focusResult(focus));
  },
);

server.registerTool(
  "resume_focus",
  {
    title: "Resume focus session",
    description: "Resume a manually paused Focus mode timer.",
    inputSchema: {},
    annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: true, openWorldHint: false },
  },
  async () => {
    const focus = await readFocus();
    if (!focus.hasStarted || focus.isFinished || focus.remainingSeconds <= 0) {
      return errorResult("There is no paused focus session to resume.");
    }
    focus.isRunning = true;
    focus.endDate = toSwiftDate(new Date(Date.now() + focus.remainingSeconds * 1000));
    await saveFocus(focus);
    return result(focusResult(focus));
  },
);

server.registerTool(
  "reset_focus",
  {
    title: "Reset focus session",
    description: "Stop and reset Focus mode without adding a completed tree.",
    inputSchema: {},
    annotations: { readOnlyHint: false, destructiveHint: true, idempotentHint: true, openWorldHint: false },
  },
  async () => {
    const focus = await readFocus();
    focus.remainingSeconds = focus.selectedMinutes * 60;
    focus.isRunning = false;
    focus.endDate = null;
    focus.hasStarted = false;
    focus.isFinished = false;
    await saveFocus(focus);
    return result(focusResult(focus));
  },
);

server.registerTool(
  "set_focus_duration",
  {
    title: "Set focus duration",
    description: "Set the duration for the next Focus mode session without starting it.",
    inputSchema: {
      minutes: z.enum(["15", "25", "45"]).describe("Focus duration in minutes"),
    },
    annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: true, openWorldHint: false },
  },
  async ({ minutes }) => {
    const focus = await readFocus();
    if (focus.isRunning) return errorResult("Pause or reset the running session before changing its duration.");
    const duration = Number(minutes);
    focus.selectedMinutes = duration;
    focus.remainingSeconds = duration * 60;
    focus.endDate = null;
    focus.hasStarted = false;
    focus.isFinished = false;
    await saveFocus(focus);
    return result(focusResult(focus));
  },
);

server.registerTool(
  "delete_task",
  {
    title: "Delete a task",
    description: "Permanently delete one task from Progress Tracker.",
    inputSchema: { task_id: z.string().uuid().describe("Task UUID from list_tasks") },
    annotations: { readOnlyHint: false, destructiveHint: true, idempotentHint: true, openWorldHint: false },
  },
  async ({ task_id }) => {
    const tasks = await readTasks();
    const index = tasks.findIndex((task) => task.id === task_id);
    if (index === -1) return errorResult(`Task not found: ${task_id}`);
    const [deleted] = tasks.splice(index, 1);
    await saveTasks(tasks);
    return result({ deleted, progress: summary(tasks) });
  },
);

server.registerTool(
  "clear_completed",
  {
    title: "Clear completed tasks",
    description: "Permanently delete all completed tasks from Progress Tracker.",
    inputSchema: {},
    annotations: { readOnlyHint: false, destructiveHint: true, idempotentHint: true, openWorldHint: false },
  },
  async () => {
    const tasks = await readTasks();
    const remaining = tasks.filter((task) => !task.isCompleted);
    const deletedCount = tasks.length - remaining.length;
    await saveTasks(remaining);
    return result({ deletedCount, progress: summary(remaining) });
  },
);

return server;
}

if (process.env.MCP_TRANSPORT === "http") {
  const port = Number(process.env.PORT || 3000);
  const apiKey = process.env.MCP_API_KEY;
  if (!apiKey) {
    console.error("MCP_API_KEY is required when using HTTP transport.");
    process.exit(1);
  }

  const app = createMcpExpressApp({ host: "0.0.0.0" });
  app.get("/health", (_req, res) => res.json({ status: "ok", service: "progress-tracker-mcp" }));
  app.use("/mcp", (req, res, next) => {
    if (req.headers.authorization !== `Bearer ${apiKey}`) {
      return res.status(401).json({
        jsonrpc: "2.0",
        error: { code: -32001, message: "Unauthorized" },
        id: null,
      });
    }
    next();
  });

  app.post("/mcp", async (req, res) => {
    const server = createServer();
    const transport = new StreamableHTTPServerTransport({ sessionIdGenerator: undefined });
    res.on("close", () => {
      transport.close();
      server.close();
    });
    try {
      await server.connect(transport);
      await transport.handleRequest(req, res, req.body);
    } catch (error) {
      console.error("MCP request failed:", error);
      if (!res.headersSent) {
        res.status(500).json({ jsonrpc: "2.0", error: { code: -32603, message: "Internal error" }, id: null });
      }
    }
  });
  app.get("/mcp", (_req, res) => res.status(405).json({ error: "Method not allowed" }));
  app.delete("/mcp", (_req, res) => res.status(405).json({ error: "Method not allowed" }));

  app.listen(port, "127.0.0.1", () => {
    console.log(`Progress Tracker MCP listening at http://127.0.0.1:${port}/mcp`);
  });
} else {
  const server = createServer();
  const transport = new StdioServerTransport();
  await server.connect(transport);
}
