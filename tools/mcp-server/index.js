#!/usr/bin/env node

/**
 * Photis Nadi MCP Server
 *
 * Exposes Photis Nadi task/project/ritual CRUD as MCP tools,
 * backed by Supabase. Register this server in SecureYeoman via:
 *
 *   POST /api/v1/mcp/servers
 *   {
 *     "name": "Photis Nadi",
 *     "transport": "stdio",
 *     "command": "node",
 *     "args": ["tools/mcp-server/index.js"],
 *     "env": {
 *       "SUPABASE_URL": "...",
 *       "SUPABASE_SERVICE_KEY": "...",
 *       "PHOTIS_USER_ID": "..."
 *     }
 *   }
 */

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { createClient } from "@supabase/supabase-js";

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY;
const PHOTIS_USER_ID = process.env.PHOTIS_USER_ID;

if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY || !PHOTIS_USER_ID) {
  console.error(
    "Required env vars: SUPABASE_URL, SUPABASE_SERVICE_KEY, PHOTIS_USER_ID"
  );
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

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

// ── Tool Handlers ──

async function handleListTasks(args) {
  let query = supabase
    .from("tasks")
    .select("*")
    .eq("user_id", PHOTIS_USER_ID);

  if (args.project_id) query = query.eq("project_id", args.project_id);
  if (args.status) query = query.eq("status", args.status);
  if (args.priority) query = query.eq("priority", args.priority);
  query = query.limit(args.limit || 50).order("modified_at", { ascending: false });

  const { data, error } = await query;
  if (error) throw new Error(`Supabase error: ${error.message}`);
  return data;
}

async function handleCreateTask(args) {
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

async function handleUpdateTask(args) {
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

async function handleListProjects(args) {
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

async function handleListRituals(args) {
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

async function handleTaskAnalytics() {
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

// ── MCP Server Setup ──

const server = new Server(
  { name: "photis-nadi", version: "1.0.0" },
  { capabilities: { tools: {} } }
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: TOOLS,
}));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    let result;
    switch (name) {
      case "photis_list_tasks":
        result = await handleListTasks(args || {});
        break;
      case "photis_create_task":
        result = await handleCreateTask(args || {});
        break;
      case "photis_update_task":
        result = await handleUpdateTask(args || {});
        break;
      case "photis_list_projects":
        result = await handleListProjects(args || {});
        break;
      case "photis_list_rituals":
        result = await handleListRituals(args || {});
        break;
      case "photis_task_analytics":
        result = await handleTaskAnalytics();
        break;
      default:
        return {
          content: [{ type: "text", text: `Unknown tool: ${name}` }],
          isError: true,
        };
    }

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
