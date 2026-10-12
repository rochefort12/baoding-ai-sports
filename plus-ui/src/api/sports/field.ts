import request from '@/utils/request';

export interface OrgFieldCard {
  id: string;
  code: string;
  label: string;
  valueType: string;
  options: string[];
  status: string;
}

export interface EventFieldCard {
  id: string;
  orgFieldId: string;
  label: string;
  valueType: string;
  required: boolean;
  sortOrder: number;
  note: string | null;
}

export interface EntryFieldCard {
  eventFieldId: string;
  label: string;
  valueType: string;
  options: string[];
  required: boolean;
  note: string | null;
  valueText: string;
}

export const listOrgFields = () => request({ url: '/sports/b/fields', method: 'get' });

export const createOrgField = (code: string, label: string, valueType: string, options: string[]) =>
  request({ url: '/sports/b/fields', method: 'post', data: { code, label, valueType, options } });

export const stopOrgField = (fieldId: string) => request({ url: '/sports/b/fields/' + fieldId + '/stop', method: 'post' });

export const listEventFields = (eventId: string) => request({ url: '/sports/b/fields/events/' + eventId, method: 'get' });

export const saveEventFields = (eventId: string, fields: { orgFieldId: string; required: boolean; note: string }[]) =>
  request({ url: '/sports/b/fields/events/' + eventId, method: 'put', data: fields });

export const listEntryFields = (registrationId: string) =>
  request({ url: '/sports/c/registrations/' + registrationId + '/fields', method: 'get' });

export const saveEntryFields = (registrationId: string, fields: { eventFieldId: string; valueText: string }[]) =>
  request({ url: '/sports/c/registrations/' + registrationId + '/fields', method: 'put', data: fields });
