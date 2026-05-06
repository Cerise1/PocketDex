import fs from "node:fs/promises";
import path from "node:path";
import os from "node:os";

type FileChangeItem = {
  type: "fileChange";
  id: string;
  status: string;
  changes: Array<{ path: string; kind: string; diff: string }>;
};

type TurnDiffItem = {
  type: "turnDiff";
  id: string;
  turnId: string;
  diff: string;
};

type StoredTurn = {
  fileChanges: Record<string, FileChangeItem>;
  turnDiff?: TurnDiffItem;
};

type StoreData = {
  threads: Record<string, Record<string, StoredTurn>>;
};

const STORE_FILENAME = "pocketdex-filechanges.json";

function resolveCodexHome(): string {
  return process.env.CODEX_HOME || path.join(os.homedir(), ".codex");
}

function resolveStorePath(): string {
  return path.join(resolveCodexHome(), STORE_FILENAME);
}

let store: StoreData = { threads: {} };
let saveTimer: NodeJS.Timeout | null = null;

function normalizeNonEmptyString(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed ? trimmed : null;
}

export function normalizeFileChangeKind(value: unknown): string {
  const direct = normalizeNonEmptyString(value);
  if (direct) return direct;
  if (!value || typeof value !== "object") return "update";

  const source = value as Record<string, unknown>;
  const type = normalizeNonEmptyString(source.type);
  const movePath = normalizeNonEmptyString(source.move_path ?? source.movePath);

  if (type === "update" && movePath) return "move";
  if (type) return type;
  if (movePath) return "move";
  return "update";
}

function normalizeFileChangeEntry(value: unknown): { path: string; kind: string; diff: string } | null {
  if (!value || typeof value !== "object") return null;
  const source = value as Record<string, unknown>;
  const filePath = normalizeNonEmptyString(source.path);
  const diff = typeof source.diff === "string" ? source.diff : null;
  if (!filePath || diff === null) return null;
  return {
    path: filePath,
    kind: normalizeFileChangeKind(source.kind),
    diff,
  };
}

export function normalizeFileChangeItem(value: unknown): FileChangeItem | null {
  if (!value || typeof value !== "object") return null;
  const source = value as Record<string, unknown>;
  const id = normalizeNonEmptyString(source.id);
  const type = source.type === "fileChange" ? "fileChange" : null;
  if (!id || !type) return null;

  const status = normalizeNonEmptyString(source.status) ?? "";
  const changesSource = Array.isArray(source.changes) ? source.changes : [];
  const changes = changesSource
    .map((entry) => normalizeFileChangeEntry(entry))
    .filter((entry): entry is { path: string; kind: string; diff: string } => entry !== null);

  return { type, id, status, changes };
}

function normalizeStoreData(value: unknown): { data: StoreData; changed: boolean } {
  if (!value || typeof value !== "object") {
    return { data: { threads: {} }, changed: true };
  }

  const sourceThreads =
    "threads" in (value as Record<string, unknown>) && (value as Record<string, unknown>).threads
      ? ((value as Record<string, unknown>).threads as Record<string, unknown>)
      : {};
  const threads: StoreData["threads"] = {};
  let changed = false;

  for (const [threadId, turnsValue] of Object.entries(sourceThreads)) {
    const normalizedThreadId = normalizeNonEmptyString(threadId);
    if (!normalizedThreadId || !turnsValue || typeof turnsValue !== "object") {
      changed = true;
      continue;
    }

    const turnsSource = turnsValue as Record<string, unknown>;
    const turns: Record<string, StoredTurn> = {};
    for (const [turnId, turnValue] of Object.entries(turnsSource)) {
      const normalizedTurnId = normalizeNonEmptyString(turnId);
      if (!normalizedTurnId || !turnValue || typeof turnValue !== "object") {
        changed = true;
        continue;
      }

      const turnSource = turnValue as Record<string, unknown>;
      const fileChangesSource =
        turnSource.fileChanges && typeof turnSource.fileChanges === "object"
          ? (turnSource.fileChanges as Record<string, unknown>)
          : {};
      const fileChanges: StoredTurn["fileChanges"] = {};
      for (const [itemId, itemValue] of Object.entries(fileChangesSource)) {
        const normalized = normalizeFileChangeItem(itemValue);
        if (!normalized) {
          changed = true;
          continue;
        }
        if (JSON.stringify(itemValue) !== JSON.stringify(normalized)) changed = true;
        if (itemId !== normalized.id) changed = true;
        fileChanges[normalized.id] = normalized;
      }

      const storedTurn: StoredTurn = { fileChanges };
      const turnDiffSource =
        turnSource.turnDiff && typeof turnSource.turnDiff === "object"
          ? (turnSource.turnDiff as Record<string, unknown>)
          : null;
      if (typeof turnDiffSource?.diff === "string" && normalizeNonEmptyString(turnDiffSource.id)) {
        storedTurn.turnDiff = {
          type: "turnDiff",
          id: normalizeNonEmptyString(turnDiffSource.id) ?? `turn-diff-${normalizedTurnId}`,
          turnId: normalizedTurnId,
          diff: turnDiffSource.diff,
        };
        if (JSON.stringify(turnSource.turnDiff) !== JSON.stringify(storedTurn.turnDiff)) changed = true;
      } else if (turnSource.turnDiff != null) {
        changed = true;
      }

      turns[normalizedTurnId] = storedTurn;
    }

    threads[normalizedThreadId] = turns;
  }

  return { data: { threads }, changed };
}

async function loadStore(): Promise<void> {
  try {
    const raw = await fs.readFile(resolveStorePath(), "utf8");
    const parsed = JSON.parse(raw);
    const normalized = normalizeStoreData(parsed);
    store = normalized.data;
    if (normalized.changed) {
      scheduleSave();
    }
  } catch {
    // ignore
  }
}

async function saveStore(): Promise<void> {
  try {
    await fs.mkdir(resolveCodexHome(), { recursive: true });
    await fs.writeFile(resolveStorePath(), JSON.stringify(store));
  } catch {
    // ignore
  }
}

function scheduleSave(): void {
  if (saveTimer) return;
  saveTimer = setTimeout(() => {
    saveTimer = null;
    void saveStore();
  }, 750);
}

function ensureTurn(threadId: string, turnId: string): StoredTurn {
  if (!store.threads[threadId]) store.threads[threadId] = {};
  if (!store.threads[threadId][turnId]) {
    store.threads[threadId][turnId] = { fileChanges: {} };
  }
  return store.threads[threadId][turnId];
}

export async function initFileChangeStore(): Promise<void> {
  await loadStore();
}

export function recordFileChange(threadId: string, turnId: string, item: FileChangeItem): void {
  const normalizedItem = normalizeFileChangeItem(item);
  if (!threadId || !turnId || !normalizedItem?.id) return;
  const turn = ensureTurn(threadId, turnId);
  turn.fileChanges[normalizedItem.id] = normalizedItem;
  scheduleSave();
}

export function recordTurnDiff(threadId: string, turnId: string, diff: string): void {
  if (!threadId || !turnId || !diff) return;
  const turn = ensureTurn(threadId, turnId);
  turn.turnDiff = { type: "turnDiff", id: `turn-diff-${turnId}`, turnId, diff };
  scheduleSave();
}

export function getThreadExtras(threadId: string): Record<string, StoredTurn> {
  return store.threads[threadId] ?? {};
}
