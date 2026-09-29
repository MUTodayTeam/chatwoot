import {
  contactProfile,
  formatShortDate,
  historyHandler,
  HANDLER_TYPES,
} from '../contact360Helper';

describe('contact360Helper', () => {
  describe('formatShortDate', () => {
    it('formats a unix timestamp as dd/mm/yy', () => {
      const timestamp = new Date(2026, 8, 5, 10, 30).getTime() / 1000;

      expect(formatShortDate(timestamp)).toBe('05/09/26');
    });

    it('returns nothing for a contact that never wrote', () => {
      expect(formatShortDate(null)).toBe('');
    });
  });

  describe('contactProfile', () => {
    it('reads Type and Partner ID from the custom attributes', () => {
      const contact = {
        custom_attributes: {
          contact_type: 'Partner โรงแรม',
          partner_id: 'H-1024',
          city: 'Bangkok',
        },
      };

      expect(contactProfile(contact)).toEqual({
        type: 'Partner โรงแรม',
        partnerId: 'H-1024',
      });
    });

    it('reads a camelcased contact from the store too', () => {
      const contact = { customAttributes: { contact_type: 'MUToday member' } };

      expect(contactProfile(contact)).toEqual({
        type: 'MUToday member',
        partnerId: '',
      });
    });

    it('is empty without attributes', () => {
      expect(contactProfile({})).toEqual({ type: '', partnerId: '' });
      expect(contactProfile()).toEqual({ type: '', partnerId: '' });
    });
  });

  describe('historyHandler', () => {
    const agent = { id: 3, name: 'Somchai' };

    it('names the agent', () => {
      expect(historyHandler({ agent, bot: false, missed: false })).toEqual({
        type: HANDLER_TYPES.AGENT,
        name: 'Somchai',
      });
    });

    it('shows Bot when only a bot handled it', () => {
      expect(historyHandler({ agent: null, bot: true, missed: false })).toEqual(
        { type: HANDLER_TYPES.BOT }
      );
    });

    it('shows Missed when nobody took it in time, even if an agent did later', () => {
      expect(historyHandler({ agent, bot: false, missed: true })).toEqual({
        type: HANDLER_TYPES.MISSED,
      });
    });

    it('prefers the agent over a bot that handed over', () => {
      expect(historyHandler({ agent, bot: true, missed: false }).type).toBe(
        HANDLER_TYPES.AGENT
      );
    });

    it('has nobody for an unhandled chat', () => {
      expect(
        historyHandler({ agent: null, bot: false, missed: false })
      ).toEqual({ type: HANDLER_TYPES.NONE });
    });
  });
});
