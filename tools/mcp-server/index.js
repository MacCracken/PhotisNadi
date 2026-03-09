#!/usr/bin/env node

/**
 * Photis Nadi MCP Server
 *
 * Exposes Photis Nadi task/project/ritual CRUD as MCP tools,
 * backed by the Photisnadi REST API (primary) with Supabase fallback.
 *
 * Register this server in SecureYeoman via:
 *
 *   POST /api/v1/mcp/servers
 *   {
 *     "name": "Photis Nadi",
 *     "transport": "stdio",
 *     "command": "node",
 *     "args": ["tools/mcp-server/index.js"],
 *     "env": {
 *       "PHOTISNADI_API_URL": "http://photisnadi:8081",
 *       "PHOTISNADI_API_KEY": "..."
 *     }
 *   }
 *
 * Optional Supabase fallback (used if REST API is unreachable):
 *   "env": {
 *     ...
 *     "SUPABASE_URL": "...",
 *     "SUPABASE_SERVICE_KEY": "...",
 *     "PHOTIS_USER_ID": "..."
 *   }
 */

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";

// ── Configuration ──

const API_URL = process.env.PHOTISNADI_API_URL;
const API_KEY = process.env.PHOTISNADI_API_KEY;

// Optional Supabase fallback
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY;
const PHOTIS_USER_ID = process.env.PHOTIS_USER_ID;

const hasRestApi = API_URL && API_KEY;
const hasSupabase = SUPABASE_URL && SUPABASE_SERVICE_KEY && PHOTIS_USER_ID;

if (!hasRestApi && !hasSupabase) {
  console.error(
    "Required env vars: PHOTISNADI_API_URL + PHOTISNADI_API_KEY, " +
      "or SUPABASE_URL + SUPABASE_SERVICE_KEY + PHOTIS_USER_ID (fallback)"
  );
  process.exit(1);
}

let supabase = null;
if (hasSupabase) {
  const { createClient } = await import("@supabase/supabase-js");
  supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
}

// ── REST API helpers ──

async function apiFetch(path, options = {}) {
  const url = `${API_URL}${path}`;
  const res = await fetch(url, {
    ...options,
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${API_KEY}`,
      ...options.headers,
    },
  });
  if (res.status === 204) return null;
  const body = await res.json();
  if (!res.ok) throw new Error(body.error || `API error ${res.status}`);
  return body;
}

function buildQuery(params) {
  const entries = Object.entries(params).filter(
    ([, v]) => v !== undefined && v !== null
  );
  if (entries.length === 0) return "";
  return "?" + new URLSearchParams(entries).toString();
}

// ── Tool Definitions ──

const TOOLS = [
  {
    name: "photis_list_tasks",
    description:
      "List tasks from Photis Nadi with optional filtering by project, status, or priority.",
    inputSchema: {
      type: "object",
      properties: {
        project_id: { type: "string", description: "Filter by project ID" },
        status: {
          type: "string",
          enum: ["todo", "inProgress", "inReview", "blocked", "done"],
        },
        priority: { type: "string", enum: ["low", "medium", "high"] },
        limit: {
          type: "number",
          description: "Max results (default 50)",
          default: 50,
        },
      },
    },
  },
  {
    name: "photis_create_task",
    description: "Create a new task in Photis Nadi.",
    inputSchema: {
      type: "object",
      properties: {
        title: { type: "string", description: "Task title" },
        description: { type: "string", description: "Task description" },
        project_id: { type: "string", description: "Project ID" },
        priority: {
          type: "string",
          enum: ["low", "medium", "high"],
          default: "medium",
        },
        status: {
          type: "string",
          enum: ["todo", "inProgress", "inReview", "blocked", "done"],
          default: "todo",
        },
        due_date: {
          type: "string",
          format: "date-time",
          description: "Due date (ISO 8601)",
        },
        tags: { type: "array", items: { type: "string" } },
      },
      required: ["title"],
    },
  },
  {
    name: "photis_update_task",
    description: "Update an existing task in Photis Nadi.",
    inputSchema: {
      type: "object",
      properties: {
        task_id: { type: "string", description: "Task ID to update" },
        title: { type: "string" },
        description: { type: "string" },
        status: {
          type: "string",
          enum: ["todo", "inProgress", "inReview", "blocked", "done"],
        },
        priority: { type: "string", enum: ["low", "medium", "high"] },
        due_date: { type: "string", format: "date-time" },
        tags: { type: "array", items: { type: "string" } },
      },
      required: ["task_id"],
    },
  },
  {
    name: "photis_list_projects",
    description: "List projects from Photis Nadi.",
    inputSchema: {
      type: "object",
      properties: {
        include_archived: {
          type: "boolean",
          description: "Include archived projects",
          default: false,
        },
      },
    },
  },
  {
    name: "photis_list_rituals",
    description:
      "List rituals with completion status and streak data from Photis Nadi.",
    inputSchema: {
      type: "object",
      properties: {
        frequency: {
          type: "string",
          enum: ["daily", "weekly", "monthly"],
          description: "Filter by frequency",
        },
      },
    },
  },
  {
    name: "photis_task_analytics",
    description:
      "Get task analytics: status distribution, priority breakdown, overdue count, blocked tasks, and productivity insights.",
    inputSchema: {
      type: "object",
      properties: {},
    },
  },
];

// ── REST API Handlers ──

async function restListTasks(args) {
  const query = buildQuery({
    project_id: args.project_id,
    status: args.status,
    priority: args.priority,
    limit: args.limit,
  });
  return apiFetch(`/api/v1/tasks${query}`);
}

async function restCreateTask(args) {
  return apiFetch("/api/v1/tasks", {
    method: "POST",
    body: JSON.stringify({
      title: args.title,
      description: args.description,
      project_id: args.project_id,
      priority: args.priority || "medium",
      status: args.status || "todo",
      due_date: args.due_date,
      tags: args.tags,
    }),
  });
}

async function restUpdateTask(args) {
  const updates = {};
  if (args.title !== undefined) updates.title = args.title;
  if (args.description !== undefined) updates.description = args.description;
  if (args.status !== undefined) updates.status = args.status;
  if (args.priority !== undefined) updates.priority = args.priority;
  if (args.due_date !== undefined) updates.due_date = args.due_date;
  if (args.tags !== undefined) updates.tags = args.tags;

  return apiFetch(`/api/v1/tasks/${args.task_id}`, {
    method: "PATCH",
    body: JSON.stringify(updates),
  });
}

async function restListProjects(args) {
  const query = buildQuery({
    include_archived: args.include_archived ? "true" : undefined,
  });
  return apiFetch(`/api/v1/projects${query}`);
}

async function restListRituals(args) {
  const query = buildQuery({ frequency: args.frequency });
  return apiFetch(`/api/v1/rituals${query}`);
}

async function restAnalytics() {
  return apiFetch("/api/v1/analytics");
}

// ── Supabase Fallback Handlers ──

async function sbListTasks(args) {
  let query = supabase
    .from("tasks")
    .select("*")
    .eq("user_id", PHOTIS_USER_ID);

  if (args.project_id) query = query.eq("project_id", args.project_id);
  if (args.status) query = query.eq("status", args.status);
  if (args.priority) query = query.eq("priority", args.priority);
  query = query
    .limit(args.limit || 50)
    .order("modified_at", { ascending: false });

  const { data, error } = await query;
  if (error) throw new Error(`Supabase error: ${error.message}`);
  return data;
}

async function sbCreateTask(args) {
  const now = new Date().toISOString();
  const id = crypto.randomUUID();

  const task = {
    id,
    user_id: PHOTIS_USER_ID,
    title: args.title,
    description: args.description || null,
    status: args.status || "todo",
    priority: args.priority || "medium",
    project_id: args.project_id || null,
    due_date: args.due_date || null,
    tags: args.tags || [],
    depends_on: [],
    created_at: now,
    modified_at: now,
  };

  const { data, error } = await supabase.from("tasks").insert(task).select();
  if (error) throw new Error(`Supabase error: ${error.message}`);
  return data[0];
}

async function sbUpdateTask(args) {
  const updates = { modified_at: new Date().toISOString() };
  if (args.title !== undefined) updates.title = args.title;
  if (args.description !== undefined) updates.description = args.description;
  if (args.status !== undefined) updates.status = args.status;
  if (args.priority !== undefined) updates.priority = args.priority;
  if (args.due_date !== undefined) updates.due_date = args.due_date;
  if (args.tags !== undefined) updates.tags = args.tags;

  const { data, error } = await supabase
    .from("tasks")
    .update(updates)
    .eq("id", args.task_id)
    .eq("user_id", PHOTIS_USER_ID)
    .select();

  if (error) throw new Error(`Supabase error: ${error.message}`);
  if (!data || data.length === 0) throw new Error("Task not found");
  return data[0];
}

async function sbListProjects(args) {
  let query = supabase
    .from("projects")
    .select("*")
    .eq("user_id", PHOTIS_USER_ID);

  if (!args.include_archived) {
    query = query.eq("is_archived", false);
  }

  const { data, error } = await query.order("name");
  if (error) throw new Error(`Supabase error: ${error.message}`);
  return data;
}

async function sbListRituals(args) {
  let query = supabase
    .from("rituals")
    .select("*")
    .eq("user_id", PHOTIS_USER_ID);

  if (args.frequency) {
    query = query.eq("frequency", args.frequency);
  }

  const { data, error } = await query.order("title");
  if (error) throw new Error(`Supabase error: ${error.message}`);
  return data;
}

async function sbAnalytics() {
  const { data: tasks, error } = await supabase
    .from("tasks")
    .select("status, priority, due_date, depends_on, created_at, modified_at")
    .eq("user_id", PHOTIS_USER_ID);

  if (error) throw new Error(`Supabase error: ${error.message}`);

  const now = new Date();
  const byStatus = {};
  const byPriority = {};
  let overdue = 0;
  let dueToday = 0;
  let blocked = 0;
  let completedThisWeek = 0;

  const weekAgo = new Date(now);
  weekAgo.setDate(weekAgo.getDate() - 7);

  for (const task of tasks) {
    byStatus[task.status] = (byStatus[task.status] || 0) + 1;
    byPriority[task.priority] = (byPriority[task.priority] || 0) + 1;

    if (task.due_date && task.status !== "done") {
      const due = new Date(task.due_date);
      if (due < now) overdue++;
      if (due.toDateString() === now.toDateString()) dueToday++;
    }

    if (task.depends_on?.length > 0 && task.status !== "done") {
      blocked++;
    }

    if (
      task.status === "done" &&
      task.modified_at &&
      new Date(task.modified_at) > weekAgo
    ) {
      completedThisWeek++;
    }
  }

  return {
    total: tasks.length,
    by_status: byStatus,
    by_priority: byPriority,
    overdue,
    due_today: dueToday,
    blocked,
    completed_this_week: completedThisWeek,
  };
}

// ── Dispatch with fallback ──

const REST_HANDLERS = {
  photis_list_tasks: restListTasks,
  photis_create_task: restCreateTask,
  photis_update_task: restUpdateTask,
  photis_list_projects: restListProjects,
  photis_list_rituals: restListRituals,
  photis_task_analytics: restAnalytics,
};

const SUPABASE_HANDLERS = {
  photis_list_tasks: sbListTasks,
  photis_create_task: sbCreateTask,
  photis_update_task: sbUpdateTask,
  photis_list_projects: sbListProjects,
  photis_list_rituals: sbListRituals,
  photis_task_analytics: sbAnalytics,
};

async function dispatch(name, args) {
  if (hasRestApi) {
    try {
      return await REST_HANDLERS[name](args);
    } catch (err) {
      if (hasSupabase) {
        console.error(`REST API failed (${err.message}), falling back to Supabase`);
        return await SUPABASE_HANDLERS[name](args);
      }
      throw err;
    }
  }
  // No REST API configured — use Supabase directly
  return await SUPABASE_HANDLERS[name](args);
}

// ── MCP Server Setup ──

const server = new Server(
  { name: "photis-nadi", version: "2.0.0" },
  { capabilities: { tools: {} } }
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: TOOLS,
}));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  if (!REST_HANDLERS[name]) {
    return {
      content: [{ type: "text", text: `Unknown tool: ${name}` }],
      isError: true,
    };
  }

  try {
    const result = await dispatch(name, args || {});
    return {
      content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
    };
  } catch (error) {
    return {
      content: [{ type: "text", text: `Error: ${error.message}` }],
      isError: true,
    };
  }
});

const transport = new StdioServerTransport();
await server.connect(transport);
