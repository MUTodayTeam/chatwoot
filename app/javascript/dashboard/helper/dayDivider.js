import { format, fromUnixTime, isSameDay, isThisYear, isToday } from 'date-fns';

// "Today" for today, then the date, with the year only once it is not this one.
export const dayLabel = (time, todayLabel) => {
  const date = fromUnixTime(time);
  if (isToday(date)) return todayLabel;
  return format(date, isThisYear(date) ? 'MMM d' : 'MMM d, yyyy');
};

// Spec §5: "Today / date · project · channel". Parts that are not known are left out.
export const dayDividerLabel = (time, todayLabel, parts = []) =>
  [dayLabel(time, todayLabel), ...parts].filter(Boolean).join(' · ');

// A message opens a new day when it is the first one or the one before it is from another day.
export const startsNewDay = (message, previousMessage) =>
  !previousMessage ||
  !isSameDay(
    fromUnixTime(message.createdAt),
    fromUnixTime(previousMessage.createdAt)
  );
