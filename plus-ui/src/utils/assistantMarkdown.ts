import MarkdownIt from 'markdown-it';
import DOMPurify from 'dompurify';

// 模型内容仅作为正文；不载入远程图片、HTML或可执行元素。来源另由业务组件显示。
const markdown = new MarkdownIt({ html: false, breaks: true, linkify: false });
markdown.disable('image');
// 表格独立滚动，长列不挤宽整个文稿；包装来自渲染器而非材料中的 HTML。
markdown.renderer.rules.table_open = () => '<div class="markdown-table-scroll" role="region" aria-label="表格，可横向滚动" tabindex="0"><table>\n';
markdown.renderer.rules.table_close = () => '</table></div>\n';
export function renderAssistantMarkdown(text: string): string {
  return DOMPurify.sanitize(markdown.render(text), {
    ALLOWED_TAGS: ['div', 'p', 'br', 'strong', 'em', 's', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'ul', 'ol', 'li', 'blockquote', 'pre', 'code', 'table', 'thead', 'tbody', 'tr', 'th', 'td', 'hr', 'a'],
    ALLOWED_ATTR: ['class', 'role', 'aria-label', 'tabindex', 'href', 'title', 'start'],
    ALLOW_DATA_ATTR: false
  });
}
