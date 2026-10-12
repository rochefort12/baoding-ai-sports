import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import {
  assistantFileAccept,
  assistantFileTypesLabel,
  formatAssistantFileSize,
  useAssistantFileDrop,
  validateAssistantFiles
} from './useAssistantFileDrop';

const lifecycle = vi.hoisted(() => ({ mounted: [] as Array<() => void>, unmounted: [] as Array<() => void> }));
vi.mock('vue', async (importOriginal) => {
  const original = await importOriginal<typeof import('vue')>();
  return {
    ...original,
    onMounted: (callback: () => void) => lifecycle.mounted.push(callback),
    onUnmounted: (callback: () => void) => lifecycle.unmounted.push(callback)
  };
});

const limits = { maxFiles: 3, maxFileBytes: 8, maxTotalBytes: 12 };
const file = (name = '规程.pdf', size = 4) => new File([new Uint8Array(size)], name);
function dragEvent(files: File[] = [], types = ['Files'], items: unknown[] = []) {
  return {
    dataTransfer: { types, files, items, dropEffect: 'none' },
    preventDefault: vi.fn(),
    stopPropagation: vi.fn()
  } as unknown as DragEvent;
}
function options(blocked = '') {
  return { blockedReason: vi.fn(() => blocked), addFiles: vi.fn(), feedback: vi.fn() };
}

beforeEach(() => {
  lifecycle.mounted.length = 0;
  lifecycle.unmounted.length = 0;
});
afterEach(() => {
  lifecycle.unmounted.forEach((callback) => callback());
  vi.unstubAllGlobals();
});

describe('助手附件选择和拖入共用校验', () => {
  it('提供一致的可选格式和易读大小', () => {
    expect(assistantFileAccept).toBe('.docx,.xlsx,.pdf,.jpg,.jpeg,.png,.webp');
    expect(assistantFileTypesLabel).toBe('DOCX、XLSX、PDF、JPG、PNG、WebP');
    expect(formatAssistantFileSize(0)).toBe('0 B');
    expect(formatAssistantFileSize(1536)).toBe('1.5 KB');
    expect(formatAssistantFileSize(15 * 1024 * 1024)).toBe('15 MB');
  });

  it('大小写和 JPEG 均可添加，保留原附件且不修改原数组', () => {
    const first = file('原资料.docx');
    const current = [first];
    const incoming = [file('规程.PDF'), file('场地.JPEG')];
    const result = validateAssistantFiles(current, incoming, limits);
    expect(result.error).toBeUndefined();
    expect(result.files).toEqual([first, ...incoming]);
    expect(current).toEqual([first]);
  });

  it('一批中有非法格式时，合法文件也不会先加入', () => {
    const current = [file()];
    const result = validateAssistantFiles(current, [file('合规.xlsx'), file('脚本.exe')], limits);
    expect(result.error).toContain('格式不支持');
    expect(result.files).toBe(current);
    expect(current).toHaveLength(1);
  });

  it('旧 DOC、空文件和没有选择均给出可处理原因', () => {
    expect(validateAssistantFiles([], [file('旧规程.DOC')], limits).error).toContain('另存为 DOCX');
    expect(validateAssistantFiles([], [file('规程.pdf', 0)], limits).error).toContain('空文件');
    expect(validateAssistantFiles([], [], limits).error).toContain('没有选到文件');
    expect(validateAssistantFiles([], [file('https://example.com/规程.pdf')], limits).error).toContain('链接不能作为附件');
  });

  it('数量、单份和合计分别检查，边界值允许添加', () => {
    const current = [file()];
    expect(validateAssistantFiles(current, [file(), file(), file()], limits).error).toContain('最多可添加 3');
    expect(validateAssistantFiles(current, [file('大规程.pdf', 9)], limits).error).toContain('单份 8 B');
    expect(validateAssistantFiles([file('旧资料.pdf', 8)], [file('新资料.pdf', 5)], limits).error).toContain('合计不能超过 12 B');
    expect(validateAssistantFiles(current, [file('新资料.pdf', 8)], limits).error).toBeUndefined();
  });
});

describe('助手文件拖入边界', () => {
  it('文本和网页链接的拖动保持浏览器原有行为', () => {
    const callbacks = options();
    const drop = useAssistantFileDrop(callbacks);
    const event = dragEvent([], ['text/plain', 'text/uri-list']);
    drop.handlers.onDragenter(event);
    drop.handlers.onDragover(event);
    drop.handlers.onDragleave(event);
    drop.handlers.onDrop(event);
    expect(event.preventDefault).not.toHaveBeenCalled();
    expect(event.stopPropagation).not.toHaveBeenCalled();
    expect(callbacks.addFiles).not.toHaveBeenCalled();
    expect(callbacks.feedback).not.toHaveBeenCalled();
    expect(drop.dragging.value).toBe(false);
  });

  it('跨过聊天框子元素时保持拖入层，真正离开后才收起', () => {
    const drop = useAssistantFileDrop(options());
    const event = dragEvent();
    drop.handlers.onDragenter(event);
    drop.handlers.onDragenter(event);
    drop.handlers.onDragleave(event);
    expect(drop.dragging.value).toBe(true);
    drop.handlers.onDragleave(event);
    expect(drop.dragging.value).toBe(false);
    drop.handlers.onDragleave(event);
    drop.handlers.onDragenter(event);
    expect(drop.dragging.value).toBe(true);
  });

  it('可接收文件时使用复制提示，只把文件交给统一添加入口', () => {
    const callbacks = options();
    const drop = useAssistantFileDrop(callbacks);
    const files = [file()];
    const event = dragEvent(files);
    drop.handlers.onDragover(event);
    expect(event.dataTransfer?.dropEffect).toBe('copy');
    expect(drop.dragging.value).toBe(true);
    drop.handlers.onDrop(event);
    expect(callbacks.addFiles).toHaveBeenCalledOnce();
    expect(callbacks.addFiles).toHaveBeenCalledWith(files);
    expect(event.preventDefault).toHaveBeenCalledTimes(2);
    expect(event.stopPropagation).toHaveBeenCalledTimes(2);
    expect(drop.dragging.value).toBe(false);
  });

  it('不能接收时拖入层仍可展示原因，放下后提示且不丢进附件', () => {
    const callbacks = options('当前任务处理中，请稍后添加资料。');
    const drop = useAssistantFileDrop(callbacks);
    const event = dragEvent([file()]);
    drop.handlers.onDragover(event);
    expect(event.dataTransfer?.dropEffect).toBe('copy');
    expect(drop.dragging.value).toBe(true);
    drop.handlers.onDrop(event);
    expect(callbacks.feedback).toHaveBeenCalledWith('当前任务处理中，请稍后添加资料。');
    expect(callbacks.addFiles).not.toHaveBeenCalled();
    expect(drop.dragging.value).toBe(false);
  });

  it('混入文件夹时整批拒绝，不误称为空文件', () => {
    const callbacks = options();
    const drop = useAssistantFileDrop(callbacks);
    const event = dragEvent(
      [file(), file('资料.pdf', 0)],
      ['Files'],
      [
        { kind: 'file', webkitGetAsEntry: () => ({ isDirectory: false, isFile: true }) },
        { kind: 'file', webkitGetAsEntry: () => ({ isDirectory: true, isFile: false }) }
      ]
    );
    drop.handlers.onDragenter(event);
    drop.handlers.onDrop(event);
    expect(callbacks.feedback).toHaveBeenCalledWith(expect.stringContaining('文件夹'));
    expect(callbacks.addFiles).not.toHaveBeenCalled();
    expect(drop.dragging.value).toBe(false);
  });

  it.each(['null', 'throw'])('读取 entry 失败（%s）明确提示重新选择', (failure) => {
    const callbacks = options();
    const drop = useAssistantFileDrop(callbacks);
    const event = dragEvent(
      [file()],
      ['Files'],
      [
        {
          kind: 'file',
          webkitGetAsEntry: () => {
            if (failure === 'throw') throw new Error('read failed');
            return null;
          }
        }
      ]
    );
    drop.handlers.onDrop(event);
    expect(callbacks.feedback).toHaveBeenCalledWith(expect.stringContaining('无法读取'));
    expect(callbacks.addFiles).not.toHaveBeenCalled();
    expect(drop.dragging.value).toBe(false);
  });

  it('无 filesystem entry 的真实非空 File 可以拖入，空回退不被当作正常文件', () => {
    const callbacks = options();
    const drop = useAssistantFileDrop(callbacks);
    const uploaded = file('浏览器创建的规程.pdf');
    drop.handlers.onDrop(dragEvent([uploaded], ['Files'], [{ kind: 'file', webkitGetAsEntry: () => null, getAsFile: () => uploaded }]));
    expect(callbacks.addFiles).toHaveBeenCalledWith([uploaded]);
    expect(callbacks.feedback).not.toHaveBeenCalled();
    callbacks.addFiles.mockClear();
    const empty = file('可能是文件夹.pdf', 0);
    drop.handlers.onDrop(dragEvent([empty], ['Files'], [{ kind: 'file', webkitGetAsEntry: () => null, getAsFile: () => empty }]));
    expect(callbacks.addFiles).not.toHaveBeenCalled();
    expect(callbacks.feedback).toHaveBeenCalledWith(expect.stringContaining('无法读取'));
  });

  it('空文件列表提示重新选择，浏览器无 entry API 时仍可拖入真实文件', () => {
    const callbacks = options();
    const drop = useAssistantFileDrop(callbacks);
    drop.handlers.onDrop(dragEvent());
    expect(callbacks.feedback).toHaveBeenCalledWith(expect.stringContaining('没有读取到'));
    drop.handlers.onDrop(dragEvent([file()], ['Files'], [{ kind: 'file' }]));
    expect(callbacks.addFiles).toHaveBeenCalledOnce();
  });

  it('Esc 和组件移除都会清理状态及监听，文本 drop 也不会留下拖入层', () => {
    const target = new EventTarget();
    const remove = vi.spyOn(target, 'removeEventListener');
    vi.stubGlobal('window', target);
    const drop = useAssistantFileDrop(options());
    lifecycle.mounted.forEach((callback) => callback());
    drop.handlers.onDragenter(dragEvent());
    target.dispatchEvent(Object.assign(new Event('keydown'), { key: 'Escape' }));
    expect(drop.dragging.value).toBe(false);
    drop.handlers.onDragenter(dragEvent());
    drop.handlers.onDrop(dragEvent([], ['text/plain']));
    expect(drop.dragging.value).toBe(false);
    drop.handlers.onDragenter(dragEvent());
    lifecycle.unmounted.forEach((callback) => callback());
    expect(drop.dragging.value).toBe(false);
    expect(remove).toHaveBeenCalledWith('keydown', expect.any(Function));
  });

  it('统一添加入口拒绝这一批时也收起拖入层', () => {
    const callbacks = options();
    callbacks.addFiles.mockImplementation(() => {
      throw new Error('validation feedback');
    });
    const drop = useAssistantFileDrop(callbacks);
    drop.handlers.onDragenter(dragEvent());
    expect(() => drop.handlers.onDrop(dragEvent([file()]))).toThrow('validation feedback');
    expect(drop.dragging.value).toBe(false);
  });
});
