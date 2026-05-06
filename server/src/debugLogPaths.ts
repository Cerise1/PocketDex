import os from "node:os";
import path from "node:path";

const BUNDLED_RUNTIME_SEGMENT = `${path.sep}.app${path.sep}Contents${path.sep}Resources${path.sep}runtime`;

function normalizeForComparison(targetPath: string): string {
  return path.resolve(targetPath);
}

export function isBundledRuntimeWorkspace(workspaceDir: string): boolean {
  const normalizedWorkspace = normalizeForComparison(workspaceDir);
  if (normalizedWorkspace.includes(BUNDLED_RUNTIME_SEGMENT)) {
    return true;
  }

  const processWithResourcesPath = process as NodeJS.Process & { resourcesPath?: string };
  const resourcesPath =
    typeof processWithResourcesPath.resourcesPath === "string" && processWithResourcesPath.resourcesPath.trim()
      ? normalizeForComparison(processWithResourcesPath.resourcesPath)
      : null;
  if (!resourcesPath) {
    return false;
  }

  return normalizedWorkspace === path.join(resourcesPath, "runtime");
}

export function resolveDefaultDebugLogDir(workspaceDir: string): string {
  if (isBundledRuntimeWorkspace(workspaceDir)) {
    return path.join(os.homedir(), "Library", "Logs", "PocketDex", "debug");
  }
  return path.join(workspaceDir, ".tmp", "logs");
}
