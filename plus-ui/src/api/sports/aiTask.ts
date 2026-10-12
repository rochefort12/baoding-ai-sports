import request from '@/utils/request';

export interface SourceRef {
  fileIndex: number;
  kind: string;
  label: string;
  quote: string;
}

export interface ProposalField {
  value: string;
  status: 'missing' | 'filled' | 'conflict' | 'suggestion' | string;
  sources: SourceRef[];
  alternatives: string[];
}

export interface AiFileCard {
  fileId: string;
  sortOrder: number;
  mediaKind: string;
  originalName: string;
  pageCount: number | null;
}

export interface AiTaskCard {
  id: string;
  status: string;
  errorCode: string | null;
  errorMessage: string | null;
  proposal: string | null;
  extraction: string | null;
  resultObjectId: string | null;
  files: AiFileCard[];
  version?: number;
  published?: boolean;
  eventStatus?: string | null;
  draftEditable?: boolean;
  eventVersion?: number | null;
}

export const uploadAiTask = (files: File[], bailianConsent: boolean) => {
  const data = new FormData();
  files.forEach((file) => data.append('files', file));
  return request({
    url: '/sports/b/ai/tasks',
    method: 'post',
    params: { bailianConsent },
    data,
    timeout: 300000,
    headers: { repeatSubmit: false }
  });
};

export const getAiTask = (id: string) => request({ url: '/sports/b/ai/tasks/' + id, method: 'get' });
export const appendAiTaskMaterials = (task: AiTaskCard, files: File[]) => { const data=new FormData();files.forEach(file=>data.append('files',file));return request<AiTaskCard>({url:`/sports/b/ai/tasks/${task.id}/materials`,method:'post',params:{consent:true,expectedVersion:task.version},data,timeout:120000,headers:{repeatSubmit:false}}); };

export const startTextAiTask = (consent: boolean, text: string) =>
  request<AiTaskCard>({
    url: '/sports/b/ai/tasks/text',
    method: 'post',
    data: { consent, text },
    timeout: 300000,
    headers: { repeatSubmit: false }
  });
export const askOperationsAssistant = (
  message: string,
  eventId: string | undefined,
  consent: boolean,
  page: string,
  history: { user: boolean; text: string }[],
  sessionId: string
) =>
  request<{ reply: string; refreshedAt: string; sessionId?: string; expiresAt?: string; retained?: boolean }>({
    url: '/sports/b/ai/assistant',
    method: 'post',
    data: { message, eventId, consent, page, history, sessionId },
    timeout: 75000,
    headers: { repeatSubmit: false }
  });

export const listOpsChats = () =>
  request<{ limit: number; sessions: { sessionId: string; preview: string; expiresAt: string }[] } | { sessionId: string; preview: string; expiresAt: string }[]>({
    url: '/sports/b/ai/assistant/sessions',
    method: 'get',
    headers: { repeatSubmit: false }
  });

export const readOpsChat = (sessionId: string) =>
  request<{ sessionId: string; expiresAt: string; turns: { user: boolean; text: string }[] }>({
    url: '/sports/b/ai/assistant/sessions/' + sessionId,
    method: 'get',
    headers: { repeatSubmit: false }
  });

export const deleteOpsChat = (sessionId: string) =>
  request({
    url: '/sports/b/ai/assistant/sessions/' + sessionId,
    method: 'delete',
    headers: { repeatSubmit: false }
  });

export const retryAiTask = (id: string) =>
  request({ url: '/sports/b/ai/tasks/' + id + '/retry', method: 'post', timeout: 300000, headers: { repeatSubmit: false } });

export const abandonAiTask = (id: string) =>
  request({ url: '/sports/b/ai/tasks/' + id + '/abandon', method: 'post', headers: { repeatSubmit: false } });

export const confirmAiTask = (id: string, data: Record<string, unknown>) =>
  request({ url: '/sports/b/ai/tasks/' + id + '/confirm', method: 'post', data, headers: { repeatSubmit: false } });

export const talkAiTask = (id: string, message: string, expectedVersion?: number, declarationAckRequired?: boolean) =>
  request({ url: '/sports/b/ai/tasks/' + id + '/talk', method: 'post', data: { message, expectedVersion, declarationAckRequired }, timeout: 100000, headers: { repeatSubmit: false } });

export const aiTaskFileBlob = (taskId: string, fileId: string) =>
  request({ url: `/sports/b/ai/tasks/${taskId}/files/${fileId}`, method: 'get', responseType: 'blob' });

export interface AiSourceVisual { index: number; location: string; sha256: string; kind: string; role?: string; caption?: string; text?: string; recognitionStatus?: string }
export interface AiSourceFile { fileId: string; originalName: string; blocks: { label: string; text: string }[]; visuals: AiSourceVisual[] }
export const getAiSourceElements = (taskId: string) => request<{ files: AiSourceFile[] }>({ url: `/sports/b/ai/tasks/${taskId}/sources`, method: 'get' });
export const aiTaskVisualBlob = (taskId: string, fileId: string, index: number) => request<Blob>({ url: `/sports/b/ai/tasks/${taskId}/files/${fileId}/visuals/${index}`, method: 'get', responseType: 'blob' });
export const editAiCandidate = (taskId: string, data: { expectedVersion: number; event: Record<string, string>; units: Record<string,string>[]; cover: { fileId: string; index?: number }; declarationAckRequired?: boolean }) => request<AiTaskCard>({ url: `/sports/b/ai/tasks/${taskId}/candidate`, method: 'put', data, headers: { repeatSubmit: false } });

// 只返回对话意图；最终对象归属、状态与写入授权仍由原业务接口重新验证。
export const resolveAssistantIntent = (message: string, eventId: string | undefined, taskId: string | undefined, history: { user: boolean; text: string }[]) =>
  request<{ intent: 'operations' | 'draft' | 'new' | 'clarify' }>({ url: '/sports/b/ai/assistant/route', method: 'post', data: { message, eventId, taskId, history, consent: true }, timeout: 75000, headers: { repeatSubmit: false } });
