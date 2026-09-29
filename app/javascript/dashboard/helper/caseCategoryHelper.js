export const ALL_INQUIRY_TYPES = 'all';
export const INQUIRY_TYPES = Object.freeze(['info', 'request', 'problem']);
// All first, then one tab per inquiry type (spec 7.3)
export const INQUIRY_TYPE_FILTERS = Object.freeze([
  ALL_INQUIRY_TYPES,
  ...INQUIRY_TYPES,
]);

export const CATEGORY_PATH_SEPARATOR = ' › ';

const MINUTES_PER = Object.freeze({ days: 1440, hours: 60, minutes: 1 });

// The category's levels as the dialog shows them; Category 2 may be empty
export const categoryPath = category =>
  [category.c1, category.c2, category.c3]
    .filter(Boolean)
    .join(CATEGORY_PATH_SEPARATOR);

export const filterCategories = (
  categories,
  { inquiryType = ALL_INQUIRY_TYPES, query = '' } = {}
) => {
  const search = query.trim().toLowerCase();
  return categories.filter(
    category =>
      (inquiryType === ALL_INQUIRY_TYPES ||
        category.inquiry_type === inquiryType) &&
      (!search ||
        [category.c1, category.c2, category.c3].some(level =>
          level.toLowerCase().includes(search)
        ))
  );
};

// Counts per inquiry type for the filter tabs
export const countByInquiryType = categories =>
  INQUIRY_TYPE_FILTERS.reduce(
    (counts, type) => ({
      ...counts,
      [type]: filterCategories(categories, { inquiryType: type }).length,
    }),
    {}
  );

// 1440 => { unit: 'days', count: 1 }: the largest unit that divides evenly
export const slaParts = minutes => {
  if (minutes == null) return null;
  const [unit, per] = Object.entries(MINUTES_PER).find(
    ([, perUnit]) => minutes % perUnit === 0
  );
  return { unit, count: minutes / per };
};
