export type AgentRole = 'pm' | 'analyst' | 'developer' | 'tech-lead' | 'qa' | 'admin';

const RESTRICTED_PATHS = [
  'config/',
  '.env',
  'secrets/',
  'storage/',
  'database/seeds/',
];

const ANALYST_ALLOWED_EXTENSIONS = [
  '.php', '.ts', '.js', '.py', '.md', '.txt',
  '.json', '.yaml', '.yml', '.sql',
];

export function getRole(): AgentRole {
  const role = (process.env.AGENT_ROLE ?? 'developer') as AgentRole;
  const valid: AgentRole[] = ['pm', 'analyst', 'developer', 'tech-lead', 'qa', 'admin'];
  return valid.includes(role) ? role : 'developer';
}

export function canReadPath(filePath: string, role: AgentRole): boolean {
  if (role === 'tech-lead' || role === 'admin') return true;

  for (const restricted of RESTRICTED_PATHS) {
    if (filePath.includes(restricted)) return false;
  }

  if (role === 'analyst' || role === 'pm') {
    const hasAllowedExt = ANALYST_ALLOWED_EXTENSIONS.some((ext) => filePath.endsWith(ext));
    if (!hasAllowedExt) return false;
  }

  return true;
}

export function canSearch(_role: AgentRole): boolean {
  return true;
}
