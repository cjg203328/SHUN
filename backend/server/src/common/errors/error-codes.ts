export enum ErrorCode {
  AuthOtpInvalid = 'AUTH_OTP_INVALID',
  AuthOtpExpired = 'AUTH_OTP_EXPIRED',
  AuthTokenInvalid = 'AUTH_TOKEN_INVALID',
  UserNotFound = 'USER_NOT_FOUND',
  UidNotFound = 'UID_NOT_FOUND',
  FriendRequestNotFound = 'FRIEND_REQUEST_NOT_FOUND',
  FriendRequestDuplicate = 'FRIEND_REQUEST_DUPLICATE',
  FriendAlreadyExists = 'FRIEND_ALREADY_EXISTS',
  BlockedRelation = 'BLOCKED_RELATION',
  MatchQuotaExceeded = 'MATCH_QUOTA_EXCEEDED',
  ThreadNotFound = 'THREAD_NOT_FOUND',
  MessageNotFound = 'MESSAGE_NOT_FOUND',
  MessageRecallExpired = 'MESSAGE_RECALL_EXPIRED',
  InvalidInput = 'INVALID_INPUT',
  InternalError = 'INTERNAL_ERROR',
}

export class BusinessError extends Error {
  constructor(
    public readonly code: ErrorCode,
    public readonly status: number,
    message: string,
    public readonly detail?: string,
  ) {
    super(message);
  }
}
