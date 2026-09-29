import {
  ALL_INQUIRY_TYPES,
  categoryPath,
  countByInquiryType,
  filterCategories,
  slaParts,
} from '../caseCategoryHelper';

const categories = [
  { id: 1, inquiry_type: 'info', c1: 'ทั่วไป', c2: 'ทักทาย', c3: 'Greeting' },
  {
    id: 2,
    inquiry_type: 'problem',
    c1: 'Booking',
    c2: 'Overbooking',
    c3: 'Same room',
  },
  {
    id: 3,
    inquiry_type: 'request',
    c1: 'บัญชีลูกค้า',
    c2: '',
    c3: 'ลืมรหัสผ่าน',
  },
];

describe('caseCategoryHelper', () => {
  describe('categoryPath', () => {
    it('joins the levels and leaves out an empty Category 2', () => {
      expect(categoryPath(categories[1])).toBe(
        'Booking › Overbooking › Same room'
      );
      expect(categoryPath(categories[2])).toBe('บัญชีลูกค้า › ลืมรหัสผ่าน');
    });
  });

  describe('filterCategories', () => {
    it('returns everything for All and no search', () => {
      expect(filterCategories(categories)).toEqual(categories);
      expect(
        filterCategories(categories, { inquiryType: ALL_INQUIRY_TYPES })
      ).toHaveLength(3);
    });

    it('filters by inquiry type', () => {
      expect(
        filterCategories(categories, { inquiryType: 'problem' }).map(c => c.id)
      ).toEqual([2]);
    });

    it('searches every level, ignoring case and surrounding spaces', () => {
      const ids = query =>
        filterCategories(categories, { query }).map(c => c.id);
      expect(ids(' booking ')).toEqual([2]);
      expect(ids('ROOM')).toEqual([2]);
      expect(ids('ทักทาย')).toEqual([1]);
      expect(ids('รหัส')).toEqual([3]);
      expect(ids('nothing')).toEqual([]);
    });

    it('combines the inquiry type and the search', () => {
      expect(
        filterCategories(categories, { inquiryType: 'info', query: 'booking' })
      ).toEqual([]);
    });
  });

  describe('countByInquiryType', () => {
    it('counts all and each inquiry type', () => {
      expect(countByInquiryType(categories)).toEqual({
        all: 3,
        info: 1,
        request: 1,
        problem: 1,
      });
    });
  });

  describe('slaParts', () => {
    it('uses the largest unit that divides the minutes evenly', () => {
      expect(slaParts(1440)).toEqual({ unit: 'days', count: 1 });
      expect(slaParts(2880)).toEqual({ unit: 'days', count: 2 });
      expect(slaParts(240)).toEqual({ unit: 'hours', count: 4 });
      expect(slaParts(90)).toEqual({ unit: 'minutes', count: 90 });
      expect(slaParts(15)).toEqual({ unit: 'minutes', count: 15 });
    });

    it('is nothing without an SLA', () => {
      expect(slaParts(null)).toBeNull();
      expect(slaParts(undefined)).toBeNull();
    });
  });
});
