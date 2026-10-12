/** Only a standalone confirmation phrase consents to the currently visible review. */
export function publicationMessageIntent(text: string): 'confirm' | 'preview' | undefined {
  const value = text.trim().replace(/[。！!]$/, '').replace(/\s+/g, '');
  if (/^(?:请)?(?:确认|同意|核对无误[,，]?确认)发布(?:赛事)?$/.test(value)) return 'confirm';
  if (/^(?:请)?(?:发布赛事|发布这场赛事|发布|直接发布赛事)$/.test(value)) return 'preview';
  return undefined;
}

export function publicationReviewSignature(...values: unknown[]) {
  function ordered(value: unknown): unknown {
    if (Array.isArray(value)) return value.map(ordered);
    if (value && typeof value === 'object') return Object.fromEntries(Object.entries(value).sort(([a], [b]) => a.localeCompare(b)).map(([key, child]) => [key, ordered(child)]));
    return value;
  }
  return JSON.stringify(values.map(ordered));
}

export function createdProposalState(proposal: string | null) {
  try {
    const value = JSON.parse(proposal || '{}');
    return { dirty: value.createdDirty === true, eventVersion: typeof value.createdEventVersion === 'number' ? value.createdEventVersion : undefined };
  } catch { return { dirty: false, eventVersion: undefined }; }
}
