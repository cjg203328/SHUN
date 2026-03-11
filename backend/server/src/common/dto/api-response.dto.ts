export interface ApiSuccess<T> {
  success: true;
  data: T;
}

export function ok<T>(data: T): ApiSuccess<T> {
  return { success: true, data };
}

