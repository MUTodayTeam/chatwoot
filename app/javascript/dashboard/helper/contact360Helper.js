import format from 'date-fns/format';
import fromUnixTime from 'date-fns/fromUnixTime';

// Contact custom attributes created by `rake cdp:seed_contact_attributes`
export const CONTACT_TYPE_KEY = 'contact_type';
export const PARTNER_ID_KEY = 'partner_id';

// Spec 13: first contact is shown as dd/mm/yy
export const SHORT_DATE_FORMAT = 'dd/MM/yy';

export const HANDLER_TYPES = Object.freeze({
  AGENT: 'agent',
  BOT: 'bot',
  MISSED: 'missed',
  NONE: 'none',
});

export const formatShortDate = timestamp =>
  timestamp ? format(fromUnixTime(timestamp), SHORT_DATE_FORMAT) : '';

// Type and Partner ID, or empty when the contact has none
export const contactProfile = (contact = {}) => {
  const attributes =
    contact.custom_attributes || contact.customAttributes || {};
  return {
    type: attributes[CONTACT_TYPE_KEY] || '',
    partnerId: attributes[PARTNER_ID_KEY] || '',
  };
};

// Who handled a past chat: a bot that kept it, a chat nobody took in time, else the agent
export const historyHandler = ({ agent, bot, missed } = {}) => {
  if (bot && !agent) return { type: HANDLER_TYPES.BOT };
  if (missed) return { type: HANDLER_TYPES.MISSED };
  if (agent) return { type: HANDLER_TYPES.AGENT, name: agent.name };
  return { type: HANDLER_TYPES.NONE };
};
