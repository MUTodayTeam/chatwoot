import { getAssigneeName, getHeaderTags } from '../conversationHeader';

describe('conversationHeader', () => {
  describe('getHeaderTags', () => {
    it('lists the channel then the project', () => {
      expect(
        getHeaderTags({
          inbox: { name: 'LINE OA' },
          project: { name: 'Checkin+' },
        })
      ).toEqual([
        { key: 'channel', label: 'LINE OA' },
        { key: 'project', label: 'Checkin+' },
      ]);
    });

    it('leaves out a channel outside any project', () => {
      expect(
        getHeaderTags({ inbox: { name: 'Website' }, project: null })
      ).toEqual([{ key: 'channel', label: 'Website' }]);
    });

    it('is empty before the inbox loads', () => {
      expect(getHeaderTags({ inbox: {}, project: null })).toEqual([]);
    });
  });

  describe('getAssigneeName', () => {
    it('prefers the display name', () => {
      expect(getAssigneeName({ name: 'Poy Suda', available_name: 'Poy' })).toBe(
        'Poy'
      );
      expect(getAssigneeName({ name: 'Poy Suda' })).toBe('Poy Suda');
    });

    it('is empty without an assignee', () => {
      expect(getAssigneeName(null)).toBe('');
    });
  });
});
