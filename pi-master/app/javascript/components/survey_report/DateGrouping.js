import {
  isEqual, endOfQuarter, startOfMonth, startOfWeek, startOfYear, add,
  startOfDay, sub,
} from 'date-fns';

export const DATE_GROUP_DAY = 'day';
export const DATE_GROUP_WEEK = 'week';
export const DATE_GROUP_MONTH = 'month';
export const DATE_GROUP_QUARTER = 'quarter';
export const DATE_GROUP_YEAR = 'year';

/**
 * Groups answer data by predefined time ranges
 *
 * @param {string} dateGroup - the time range to group on
 * (day, month, week, quarter, year)
 * @param {array} initialData - the initial data series to group
 *
 * [{name: 'b', data: [epoch timestamp integer, responseCount], color: }, ...]
 * @return {array} a new data series, grouped by dateGroup
 **/
export function dataGroupedBy(dateGroup, initialData) {
  const newSeries = initialData.map((possibleAnswer) => {
    const newData = [];
    let lastTimeGroup = null;
    let numAnswersForGroup = 0;

    // dataTuple: [
    //   epoch timestamp representing a date,
    //   numAnswers for that date
    // ]
    possibleAnswer.data.forEach((dataTuple, tupleIndex) => {
      const timestamp = dataTuple[0];
      const numAnswers = dataTuple[1];

      const groupKey = () => {
        const curTime = new Date(timestamp);
        // date-fns uses a Date object, which uses local time by default
        // We want results in UTC regardless of the user's time zone, so we
        // need to shift the timestamp by the local time zone to make it equal
        // the time in UTC.
        curTime.setMinutes(curTime.getTimezoneOffset());

        let visualOffset = 0;

        switch (dateGroup) {
          case DATE_GROUP_DAY:
            return curTime;
          case DATE_GROUP_WEEK:
            // straddle the x-axis tick nicely
            // the time manipulation is strictly for visual purposes
            visualOffset = 16;
            return add(startOfWeek(curTime), {hours: visualOffset});
          case DATE_GROUP_MONTH:
            return startOfMonth(curTime);
          case DATE_GROUP_QUARTER:
            return endOfQuarter(curTime);
          case DATE_GROUP_YEAR:
            return startOfYear(curTime);
          default:
            console.debug('Unrecognized date group', dateGroup);
        };
      };

      const groupKeyEquals = (other) => {
        return isEqual(groupKey(), other);
      };

      if (lastTimeGroup === null) {
        lastTimeGroup = groupKey();
      }

      if (!groupKeyEquals(lastTimeGroup)) {
        newData.push([lastTimeGroup.valueOf(), numAnswersForGroup]);

        lastTimeGroup = groupKey();
        numAnswersForGroup = 0;
      }

      numAnswersForGroup += numAnswers;
      if (tupleIndex === possibleAnswer.data.length - 1) {
        newData.push([groupKey().valueOf(), numAnswersForGroup]);
      }
    });

    return {
      ...possibleAnswer,
      data: newData,
    };
  });

  return newSeries;
}
