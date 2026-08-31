#!/usr/bin/env node
// MCP server for the WEGO formations prototype.
//
// Owns no game rules. Every tool forwards to the Godot bridge over
// newline-delimited JSON and returns whatever the engine says, so order
// rejections arrive with the same message the UI shows.

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import net from "node:net";

const HOST = process.env.STRATEGO_HOST ?? "127.0.0.1";
const PORT = Number(process.env.STRATEGO_PORT ?? 8791);

let socket = null;
let buffer = "";
let nextId = 1;
const pending = new Map();

function connect() {
  if (socket && !socket.destroyed) return Promise.resolve(socket);
  return new Promise((resolve, reject) => {
    const client = net.createConnection({ host: HOST, port: PORT }, () => {
      socket = client;
      resolve(client);
    });
    client.setEncoding("utf8");
    client.on("data", (chunk) => {
      buffer += chunk;
      let index;
      while ((index = buffer.indexOf("\n")) >= 0) {
        const line = buffer.slice(0, index).trim();
        buffer = buffer.slice(index + 1);
        if (!line) continue;
        let message;
        try {
          message = JSON.parse(line);
        } catch {
          continue;
        }
        const waiter = pending.get(message.id);
        if (waiter) {
          pending.delete(message.id);
          waiter.resolve(message);
        }
      }
    });
    const fail = (error) => {
      socket = null;
      for (const waiter of pending.values()) waiter.reject(error);
      pending.clear();
      reject(error);
    };
    client.on("error", fail);
    client.on("close", () => {
      socket = null;
    });
  });
}

async function call(command, args = {}) {
  const client = await connect();
  const id = nextId++;
  return new Promise((resolve, reject) => {
    pending.set(id, { resolve, reject });
    const timer = setTimeout(() => {
      pending.delete(id);
      reject(new Error(`Timed out waiting for "${command}".`));
    }, 30000);
    const settle = (fn) => (value) => {
      clearTimeout(timer);
      fn(value);
    };
    pending.set(id, { resolve: settle(resolve), reject: settle(reject) });
    client.write(JSON.stringify({ id, command, args }) + "\n");
  });
}

function text(value) {
  const body = typeof value === "string" ? value : JSON.stringify(value, null, 2);
  return { content: [{ type: "text", text: body }] };
}

async function forward(command, args) {
  try {
    const response = await call(command, args);
    return text(response);
  } catch (error) {
    return text(
      `Bridge error: ${error.message}\n` +
        `Is the Godot host running on ${HOST}:${PORT}?`,
    );
  }
}

const server = new McpServer({ name: "stratego", version: "1.0.0" });

server.tool(
  "get_state",
  "Full board state: formations, terrain, phase, objective progress. Omniscient (no fog).",
  {},
  () => forward("get_state", {}),
);

server.tool(
  "new_game",
  "Start a fresh game. bridge: cross the river with 20 strength. meeting: symmetric back-rank deployment, win by holding the centre square for 3 consecutive rounds. four_player: fog battle with Flags. crossroads: 2v2 team battle (Red+Green vs Blue+Yellow), same centre-hold win condition as meeting, opens on a deployment phase - call auto_deploy to skip it.",
  { seed: z.number().int().optional(), scenario: z.enum(["bridge", "four_player", "meeting", "crossroads"]).optional() },
  (args) => forward("new_game", args),
);

server.tool(
  "auto_deploy",
  "Only valid during crossroads' deployment phase. Resets your formations to the recommended positions (undoing anything already placed) and locks every unready player in, yourself included, then resolves deployment into the first round. The lazy path when you don't want to place formations by hand.",
  {},
  () => forward("auto_deploy", {}),
);

server.tool(
  "legal_steps",
  "On-board passable cells one step from a formation. Occupied cells are included, since entering one is how you attack.",
  { piece_id: z.number().int() },
  (args) => forward("legal_steps", args),
);

server.tool(
  "set_order",
  "Give one formation its orders. path is a list of [x,y] steps, each adjacent to the last. For an Archer, ranged_target is the square to aim at; add ranged_target_id to aim at that formation so the shot follows it, or omit the id to suppress the square and hit whoever stands there. Aiming costs 1 movement point whether or not the shot lands. In the leftover phase, pass leftover only. Returns the engine's rejection message when illegal.",
  {
    piece_id: z.number().int(),
    path: z.array(z.array(z.number().int()).length(2)).optional(),
    ranged_target: z.array(z.number().int()).length(2).optional(),
    ranged_target_id: z.number().int().optional(),
    leftover: z.array(z.number().int()).length(2).optional(),
  },
  (args) => forward("set_order", args),
);

server.tool(
  "clear_orders",
  "Clear one formation's orders, or all of yours when piece_id is omitted.",
  { piece_id: z.number().int().optional() },
  (args) => forward("clear_orders", args),
);

server.tool(
  "commit",
  "Lock in your orders and wait, without resolving. Use this when a human is " +
  "commanding the other army in the running app: it marks only your side ready " +
  "and lets the app resolve once they end their own planning, so the battle " +
  "plays out there with its animation, battle cards and log. end_planning would " +
  "instead have the bot plan for anyone not yet ready and resolve inside the " +
  "bridge, which both overrides the human and skips the app's presentation.",
  {},
  () => forward("commit", {}),
);

server.tool(
  "end_planning",
  "Submit your orders, let the bot PLAN FOR EVERY OTHER SIDE, and resolve inside the bridge. " +
  "Only for solo play against the bot. If a human is commanding another army, use commit " +
  "instead: this would play their turn for them and skip the app's own resolution.",
  {},
  () => forward("end_planning", {}),
);

server.tool(
  "get_events",
  "Event log from the most recent resolution.",
  {},
  () => forward("get_events", {}),
);

server.tool(
  "get_history",
  "Whole-match combat record: damage dealt and taken, kills, and battle count per formation. Set combats=false to drop the raw battle list, events=true to include every movement event tagged by round.",
  { combats: z.boolean().optional(), events: z.boolean().optional() },
  (args) => forward("get_history", args),
);

server.tool(
  "save_replay",
  "Write the deterministic replay document to a file. Only valid between rounds or after the game ends.",
  { path: z.string().optional() },
  (args) => forward("save_replay", args),
);

await server.connect(new StdioServerTransport());
