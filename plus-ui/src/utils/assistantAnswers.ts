/** Answer buttons edit the user's draft; several answers can be reviewed and sent together. */
export function hasAssistantAnswer(draft: string, answer: string) {
  const value = answer.trim();
  return !!value && draft.split(/\r?\n/).some(line => line.trim() === value);
}

export function toggleAssistantAnswer(draft: string, answer: string) {
  const value = answer.trim();
  if (!value) return draft;
  if (hasAssistantAnswer(draft, value)) {
    return draft.split(/\r?\n/).filter(line => line.trim() !== value).join('\n').trim();
  }
  return draft.trimEnd() ? `${draft.trimEnd()}\n${value}` : value;
}

export function toggleAssistantTopic(topics: string[], topic: string) {
  const value = topic.trim();
  if (!value) return topics;
  return topics.includes(value) ? topics.filter(item => item !== value) : [...topics, value];
}
