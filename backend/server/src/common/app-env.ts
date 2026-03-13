export type BackendAppEnv =
  | 'demo'
  | 'development'
  | 'test'
  | 'staging'
  | 'production';

export function resolveAppEnv(): BackendAppEnv {
  const raw = (process.env.APP_ENV ?? 'development').trim().toLowerCase();
  switch (raw) {
    case 'demo':
      return 'demo';
    case 'development':
    case 'dev':
      return 'development';
    case 'test':
      return 'test';
    case 'staging':
      return 'staging';
    case 'production':
    case 'prod':
      return 'production';
    default:
      return 'development';
  }
}

export function allowDemoMatchPool(): boolean {
  const appEnv = resolveAppEnv();
  return appEnv === 'demo' || appEnv === 'development' || appEnv === 'test';
}
