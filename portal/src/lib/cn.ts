/**
 * Minimal className combiner — joins truthy string arguments.
 * (Deliberately dependency-free; the portal keeps its bundle lean.)
 */
export function cn(
  ...parts: Array<string | false | null | undefined>
): string {
  return parts.filter(Boolean).join(" ");
}
