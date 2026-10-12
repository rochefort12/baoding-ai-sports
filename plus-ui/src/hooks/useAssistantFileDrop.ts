import { onMounted, onUnmounted, ref } from 'vue';

export const assistantFileAccept = '.docx,.xlsx,.pdf,.jpg,.jpeg,.png,.webp';
export const assistantFileTypesLabel = 'DOCX、XLSX、PDF、JPG、PNG、WebP';

export interface AssistantFileLimits {
  maxFiles: number;
  maxFileBytes: number;
  maxTotalBytes: number;
}

export interface AssistantFileValidationResult {
  files: File[];
  error?: string;
}

export function formatAssistantFileSize(size: number): string {
  if (!Number.isFinite(size) || size <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  const index = Math.max(0, Math.min(Math.floor(Math.log(size) / Math.log(1024)), units.length - 1));
  const amount = size / 1024 ** index;
  return `${index ? Number(amount.toFixed(1)) : Math.round(amount)} ${units[index]}`;
}

// Picker and drop use the same atomic check: a rejected batch never changes the existing attachments.
export function validateAssistantFiles(current: File[], incoming: File[], limits: AssistantFileLimits): AssistantFileValidationResult {
  const reject = (error: string): AssistantFileValidationResult => ({ files: current, error });
  if (!incoming.length) return reject('没有选到文件，请重新选择。');
  if (current.length + incoming.length > limits.maxFiles) return reject(`最多可添加 ${limits.maxFiles} 份资料，请先移除部分附件。`);
  for (const file of incoming) {
    if (/^(?:https?|ftp|file|data|blob):/i.test(file.name)) return reject('链接不能作为附件，请添加本地文件。');
    if (/\.doc$/i.test(file.name)) return reject(`“${file.name}”是旧版 DOC 文件，请另存为 DOCX 后添加。`);
    if (!/^.+\.(docx|xlsx|pdf|jpe?g|png|webp)$/i.test(file.name)) {
      return reject(`“${file.name}”格式不支持，请添加 ${assistantFileTypesLabel} 文件。`);
    }
    if (!Number.isFinite(file.size) || file.size <= 0) return reject(`“${file.name}”是空文件，请检查后重新添加。`);
    if (file.size > limits.maxFileBytes) return reject(`“${file.name}”超过单份 ${formatAssistantFileSize(limits.maxFileBytes)} 的限制。`);
  }
  const files = [...current, ...incoming];
  if (files.reduce((total, file) => total + file.size, 0) > limits.maxTotalBytes) {
    return reject(`资料合计不能超过 ${formatAssistantFileSize(limits.maxTotalBytes)}，请先移除部分附件。`);
  }
  return { files };
}

export interface AssistantFileDropOptions {
  blockedReason: () => string;
  addFiles: (files: File[]) => void;
  feedback: (message: string) => void;
}

export interface AssistantFileDropHandlers {
  onDragenter: (event: DragEvent) => void;
  onDragover: (event: DragEvent) => void;
  onDragleave: (event: DragEvent) => void;
  onDrop: (event: DragEvent) => void;
}

function hasFileTransfer(event: DragEvent): boolean {
  return !!event.dataTransfer && Array.from(event.dataTransfer.types).includes('Files');
}

function intercept(event: DragEvent) {
  event.preventDefault();
  event.stopPropagation();
}

export function useAssistantFileDrop(options: AssistantFileDropOptions) {
  const dragging = ref(false);
  let depth = 0;
  let keyboardTarget: Window | undefined;

  const reset = () => {
    depth = 0;
    dragging.value = false;
  };
  const setDropEffect = (event: DragEvent) => {
    // Keep receiving a blocked drop so it can show the reason and reset the overlay without browser navigation.
    if (event.dataTransfer) event.dataTransfer.dropEffect = 'copy';
  };
  const handlers: AssistantFileDropHandlers = {
    onDragenter(event) {
      if (!hasFileTransfer(event)) return;
      intercept(event);
      depth += 1;
      dragging.value = true;
      setDropEffect(event);
    },
    onDragover(event) {
      if (!hasFileTransfer(event)) return;
      intercept(event);
      depth = Math.max(1, depth);
      dragging.value = true;
      setDropEffect(event);
    },
    onDragleave(event) {
      if (!hasFileTransfer(event)) return;
      intercept(event);
      depth = Math.max(0, depth - 1);
      if (!depth) dragging.value = false;
    },
    onDrop(event) {
      if (!hasFileTransfer(event)) {
        reset();
        return;
      }
      intercept(event);
      try {
        const reason = options.blockedReason();
        if (reason) {
          options.feedback(reason);
          return;
        }
        const transfer = event.dataTransfer!;
        // Directories can resemble zero-byte files. Identify them before handing files to the shared validator.
        for (const item of Array.from(transfer.items || [])) {
          if (item.kind !== 'file' || typeof item.webkitGetAsEntry !== 'function') continue;
          let entry: FileSystemEntry | null;
          try {
            entry = item.webkitGetAsEntry();
          } catch {
            options.feedback('无法读取拖入的文件，请用“添加资料”重新选择文件。');
            return;
          }
          if (!entry) {
            // Files made from real bytes have no filesystem entry (for example a browser-created File).
            let droppedFile: File | null = null;
            try {
              droppedFile = item.getAsFile?.() ?? null;
            } catch {
              // A failed fallback uses the same visible read error below.
            }
            if (droppedFile && Number.isFinite(droppedFile.size) && droppedFile.size > 0) continue;
            options.feedback('无法读取拖入的文件，请用“添加资料”重新选择文件。');
            return;
          }
          if (entry.isDirectory) {
            options.feedback('暂不支持拖入文件夹，请打开文件夹后选择其中的文件。');
            return;
          }
          if (!entry.isFile) {
            options.feedback('无法读取拖入的文件，请用“添加资料”重新选择文件。');
            return;
          }
        }
        const files = Array.from(transfer.files || []);
        if (!files.length) {
          options.feedback('没有读取到可添加的文件，请用“添加资料”重新选择文件。');
          return;
        }
        options.addFiles(files);
      } finally {
        reset();
      }
    }
  };

  const onKeydown = (event: KeyboardEvent) => {
    if (event.key === 'Escape') reset();
  };
  onMounted(() => {
    if (typeof window === 'undefined') return;
    keyboardTarget = window;
    keyboardTarget.addEventListener('keydown', onKeydown);
  });
  onUnmounted(() => {
    keyboardTarget?.removeEventListener('keydown', onKeydown);
    keyboardTarget = undefined;
    reset();
  });

  return { dragging, handlers, reset };
}
