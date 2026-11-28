import http from "node:http";
import { WebSocketServer } from "ws";

const PORT = Number(process.env.PORT || 8080);
const TABLE_MS = 12 * 60 * 1000;

const tables = new Map();
const openQueue = [];
const names = new Map();
const seats = new Map();

function now() {
  return Date.now();
}

function cleanName(value) {
  return String(value || "")
    .trim()
    .replace(/\s+/g, " ")
    .slice(0, 16);
}

function nameKey(value) {
  return cleanName(value).toLowerCase();
}

function validName(value) {
  const ident = cleanName(value);
  return ident.length >= 2 && /^[A-Za-z0-9][A-Za-z0-9 .'\-]*$/.test(ident);
}

function makeCode(prefix) {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let out = prefix || "";
  while (out.length < 5) {
    out += alphabet[Math.floor(Math.random() * alphabet.length)];
  }
  return out.slice(0, 6);
}

function prune() {
  const t = now();
  for (const [code, table] of tables) {
    if (t - table.touched > TABLE_MS) {
      for (const seat of [table.host, table.guest]) {
        if (seat?.ws?.readyState === 1) {
          seat.ws.close(4000, "table expired");
        }
      }
      tables.delete(code);
    }
  }
  while (openQueue.length && now() - openQueue[0].since > TABLE_MS) {
    const stale = openQueue.shift();
    if (stale?.ws?.readyState === 1) {
      stale.ws.close(4000, "search expired");
    }
  }
}

function send(ws, msg) {
  if (ws?.readyState === 1) {
    ws.send(JSON.stringify(msg));
  }
}

function relay(from, table, msg) {
  const other = table.host?.ws === from ? table.guest : table.host;
  if (other?.ws) {
    send(other.ws, msg);
  }
}

function seatOf(ws) {
  for (const [code, table] of tables) {
    if (table.host?.ws === ws) {
      return { code, table, role: "host" };
    }
    if (table.guest?.ws === ws) {
      return { code, table, role: "guest" };
    }
  }
  const q = openQueue.findIndex((s) => s.ws === ws);
  if (q >= 0) {
    return { queue: q };
  }
  return null;
}

function playerOf(ws) {
  return seats.get(ws) || null;
}

function onlineOf(record) {
  return Boolean(record?.ws && record.ws.readyState === 1);
}

function hello(ws, name) {
  if (!validName(name)) {
    send(ws, { type: "error", error: "bad_name" });
    return;
  }
  const display = cleanName(name);
  const key = nameKey(display);
  const taken = names.get(key);
  if (taken && taken.ws && taken.ws !== ws && taken.ws.readyState === 1) {
    send(ws, { type: "name_taken", name: taken.name });
    return;
  }
  const previous = seats.get(ws);
  if (previous && previous.key !== key) {
    const old = names.get(previous.key);
    if (old?.ws === ws) {
      old.ws = null;
      old.seen = now();
    }
  }
  names.set(key, { name: display, ws, seen: now() });
  seats.set(ws, { name: display, key });
  send(ws, { type: "hello_ok", name: display });
}

function findPlayer(ws, name) {
  const query = nameKey(name);
  if (query.length < 2) {
    send(ws, { type: "error", error: "short_name" });
    return;
  }
  const exact = names.get(query);
  if (exact) {
    send(ws, {
      type: "found",
      name: exact.name,
      online: onlineOf(exact),
    });
    return;
  }
  const matches = [];
  for (const record of names.values()) {
    if (nameKey(record.name).startsWith(query)) {
      matches.push({ name: record.name, online: onlineOf(record) });
    }
    if (matches.length >= 6) {
      break;
    }
  }
  if (matches.length === 1) {
    send(ws, { type: "found", name: matches[0].name, online: matches[0].online });
    return;
  }
  if (matches.length > 1) {
    send(ws, { type: "found_list", matches });
    return;
  }
  send(ws, { type: "not_found", name: cleanName(name) });
}

function cleanOptions(raw) {
  const src = raw && typeof raw === "object" ? raw : {};
  return {
    guide: Number(src.guide) || 0,
    ditch: Boolean(src.ditch),
    race: Number(src.race) || 2,
    points: Number(src.points) || 7,
    ends: Number(src.ends) || 0,
  };
}

function hostTable(ws, code, name) {
  const key = String(code || "").trim().toUpperCase();
  if (!/^[A-Z0-9]{4,8}$/.test(key)) {
    send(ws, { type: "error", error: "bad_code" });
    return null;
  }
  const who = cleanName(name) || playerOf(ws)?.name || "Flicker";
  let table = tables.get(key);
  if (!table) {
    table = { host: null, guest: null, touched: now(), options: {} };
    tables.set(key, table);
  }
  table.touched = now();
  table.host = { ws, name: who };
  send(ws, { type: "hosted", code: key, name: who });
  if (table.guest) {
    send(ws, { type: "matched", code: key, role: "host", peer: table.guest.name });
    send(table.guest.ws, { type: "matched", code: key, role: "guest", peer: who });
  }
  return table;
}

function joinTable(ws, code, name) {
  const key = String(code || "").trim().toUpperCase();
  const who = cleanName(name) || playerOf(ws)?.name || "Friend";
  const table = tables.get(key);
  if (!table || !table.host) {
    send(ws, { type: "error", error: "no_table" });
    return;
  }
  table.touched = now();
  table.guest = { ws, name: who };
  send(ws, { type: "matched", code: key, role: "guest", peer: table.host.name, options: table.options || {} });
  send(table.host.ws, { type: "matched", code: key, role: "host", peer: who, options: table.options || {} });
}

function openSearch(ws, name) {
  const who = cleanName(name) || playerOf(ws)?.name || "Flicker";
  const waiting = openQueue.shift();
  if (waiting?.ws?.readyState === 1) {
    const code = `LIVE${Math.floor(Math.random() * 900 + 100)}`;
    const table = {
      host: { ws: waiting.ws, name: waiting.name },
      guest: { ws, name: who },
      touched: now(),
      options: waiting.options || {},
    };
    tables.set(code, table);
    send(waiting.ws, { type: "matched", code, role: "host", peer: who, options: table.options });
    send(ws, { type: "matched", code, role: "guest", peer: waiting.name, options: table.options });
    return;
  }
  openQueue.push({ ws, name: who, since: now(), options: {} });
  send(ws, { type: "searching" });
}

function invitePlayer(ws, to, options) {
  const from = playerOf(ws);
  if (!from) {
    send(ws, { type: "error", error: "no_hello" });
    return;
  }
  const target = names.get(nameKey(to));
  if (!target || !onlineOf(target)) {
    send(ws, { type: "invite_failed", error: "offline", name: cleanName(to) });
    return;
  }
  if (target.ws === ws) {
    send(ws, { type: "invite_failed", error: "self" });
    return;
  }
  const code = makeCode("I");
  const cleaned = cleanOptions(options);
  leaveTable(ws);
  const table = hostTable(ws, code, from.name);
  if (!table) {
    return;
  }
  table.options = cleaned;
  send(target.ws, {
    type: "invite",
    from: from.name,
    code,
    options: cleaned,
  });
  send(ws, { type: "invite_sent", to: target.name, code, options: cleaned });
}

function leaveTable(ws) {
  const found = seatOf(ws);
  if (found?.queue >= 0) {
    openQueue.splice(found.queue, 1);
    return;
  }
  if (!found?.table) {
    return;
  }
  const { table, role, code } = found;
  table.touched = now();
  if (role === "host") {
    if (table.guest?.ws) {
      send(table.guest.ws, { type: "peer_left" });
    }
    table.host = null;
  } else {
    if (table.host?.ws) {
      send(table.host.ws, { type: "peer_left" });
    }
    table.guest = null;
  }
  if (!table.host && !table.guest) {
    tables.delete(code);
  }
}

function drop(ws) {
  leaveTable(ws);
  const seat = seats.get(ws);
  if (seat) {
    const rec = names.get(seat.key);
    if (rec?.ws === ws) {
      rec.ws = null;
      rec.seen = now();
    }
    seats.delete(ws);
  }
}

const server = http.createServer((req, res) => {
  if (req.url === "/health" || req.url === "/") {
    res.writeHead(200, { "content-type": "application/json" });
    res.end(
      JSON.stringify({
        ok: true,
        club: "bowl-roll",
        tables: tables.size,
        searching: openQueue.length,
        names: names.size,
      })
    );
    return;
  }
  res.writeHead(404);
  res.end("not found");
});

const wss = new WebSocketServer({ server, path: "/ws" });
wss.on("connection", (ws) => {
  ws.on("message", (raw) => {
    let msg;
    try {
      msg = JSON.parse(String(raw));
    } catch {
      send(ws, { type: "error", error: "bad_json" });
      return;
    }
    const type = String(msg.type || "");
    prune();
    if (type === "hello") {
      hello(ws, msg.name);
    } else if (type === "find") {
      findPlayer(ws, msg.name);
    } else if (type === "invite") {
      invitePlayer(ws, msg.to, msg.options);
    } else if (type === "leave") {
      leaveTable(ws);
    } else if (type === "host") {
      hostTable(ws, msg.code, msg.name);
    } else if (type === "join") {
      joinTable(ws, msg.code, msg.name);
    } else if (type === "search") {
      openSearch(ws, msg.name);
    } else if (type === "relay") {
      const found = seatOf(ws);
      if (found?.table) {
        found.table.touched = now();
        relay(ws, found.table, { type: "relay", from: found.role, payload: msg.payload });
      }
    } else {
      send(ws, { type: "error", error: "unknown_type" });
    }
  });
  ws.on("close", () => drop(ws));
  ws.on("error", () => drop(ws));
});

setInterval(prune, 30_000).unref();

server.listen(PORT, "0.0.0.0", () => {
  console.log(`bowl-roll club on 0.0.0.0:${PORT}`);
});
