/** 缺项由候选表单展示；只移除末尾的结构化提示，保留正文中的正常对话。 */
export function withoutStructuredNextStep(text: string, nextStep?: string) {
  const spoken = text || '';
  const step = nextStep?.trim();
  if (step && spoken.trim() === step) return '';
  if (step) {
    const position = spoken.lastIndexOf(step);
    if (position > 0 && !spoken.slice(position + step.length).trim() && /\n\s*$/.test(spoken.slice(0, position))) {
      return spoken.slice(0, position).trim();
    }
  }
  // Historical turns retain their own old next-step sentence. Match the labelled
  // suffix even after readiness has changed; do not repeat it beside the form.
  return spoken.replace(/(?:^|\r?\n\s*)(?:还不能保存赛事草稿。\s*)?下一步[:：][^]*$/, '').trimEnd();
}
