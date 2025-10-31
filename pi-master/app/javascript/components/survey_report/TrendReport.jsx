import React from 'react';
import PropTypes from 'prop-types';

import HighchartsReact from 'highcharts-react-official';
import Highcharts from 'highcharts';
import exporting from 'highcharts/modules/exporting';

import {
  add, format, getWeek, getQuarter, milliseconds,
  eachWeekendOfInterval, startOfDay, endOfDay, sub,
} from 'date-fns';

import 'react-contexify/ReactContexify.css';

import * as DateGrouping from './DateGrouping';
import RadioControl from './RadioControl';

import SettingsIcon from './SettingsIcon';

import ScaledBarsIcon from '../../images/scaled_bars.svg';
import AbsoluteBarsIcon from '../../images/absolute_bars.svg';
import AreaChartIcon from '../../images/area_chart.svg';

import {numberToPercentage} from './Common';

exporting(Highcharts);

const ChartControls = (props) => {
  return (
    <div className='settings-container'>
      <ul className='settings-group'>
        <li
          className='settings-option'
          title='Absolute'
        >
          <RadioControl
            id={`${props.chartId}-stacked-bar-absolute`}
            value='stacked-bar-absolute'
            onChange={(e) => {
              props.updateChart({
                chart: {
                  type: 'column',
                },
                plotOptions: {
                  column: {
                    stacking: 'normal',
                    dataLabels: {
                      enabled: true,
                      formatter: function() {
                        return absoluteBarLabels(this);
                      },
                    },
                  },
                },
              });
            }}
            selected={props.defaultChartType === 'absolute'}
            groupName={`${props.chartId}-chart-type`}
          >
            <SettingsIcon icon={AbsoluteBarsIcon} />
          </RadioControl>
        </li>
        <li
          className='settings-option'
          title='Scaled'
        >
          <RadioControl
            id={`${props.chartId}-stacked-bar-scaled`}
            value='stacked-bar-scaled'
            onChange={(e) => {
              props.updateChart({
                chart: {
                  type: 'column',
                },
                plotOptions: {
                  column: {
                    stacking: 'percent',
                    dataLabels: {
                      enabled: true,
                      formatter: function() {
                        return scaledBarLabels(this);
                      },
                    },
                  },
                },
              });
            }}
            selected={props.defaultChartType === 'scaled'}
            groupName={`${props.chartId}-chart-type`}
          >
            <SettingsIcon icon={ScaledBarsIcon} />
          </RadioControl>
        </li>
        <li
          className='settings-option'
          title='Area chart'
        >
          <RadioControl
            id={`${props.chartId}-stacked-area-chart`}
            value='stacked-area-chart'
            onChange={(e) => {
              props.updateChart({
                chart: {
                  type: 'area',
                },
              });
            }}
            selected={props.defaultChartType === 'area'}
            groupName={`${props.chartId}-chart-type`}
          >
            <SettingsIcon icon={AreaChartIcon} />
          </RadioControl>
        </li>
      </ul>
      <ul className='settings-group'>
        {
          [
            {label: 'DAY', value: DateGrouping.DATE_GROUP_DAY},
            {label: 'WEEK', value: DateGrouping.DATE_GROUP_WEEK},
            {label: 'MONTH', value: DateGrouping.DATE_GROUP_MONTH},
            {label: 'QUARTER', value: DateGrouping.DATE_GROUP_QUARTER},
            {label: 'YEAR', value: DateGrouping.DATE_GROUP_YEAR},
          ].map((buttonSettings) => {
            const name = props.chartId.toString();
            const label = buttonSettings.label;
            const value = buttonSettings.value;

            return (
              <li
                className='settings-option'
                key={buttonSettings.value}
                title={`Group by ${label}`}
              >
                <RadioControl
                  id={`date-group-${name}-${value}`}
                  groupName={`date-group-${name}`}
                  value={value}
                  onChange={(e) => {
                    props.setDateGroup(e.target.value);
                  }}
                  selected={buttonSettings.value === props.defaultDateGroup}
                  label={label}
                />
              </li>
            );
          })
        }
      </ul>
    </div>
  );
};

ChartControls.propTypes = {
  chartId: PropTypes.number.isRequired,
  defaultDateGroup: PropTypes.string.isRequired,
  defaultChartType: PropTypes.string.isRequired,
  updateChart: PropTypes.func.isRequired,
  setDateGroup: PropTypes.func.isRequired,
};

/**
 * @param { Object } pointLabelObject - see Highcharts
 *   https://api.highcharts.com/class-reference/Highcharts.PointLabelObject
 * @return { string } formatted number of responses
 */
function numResponses(pointLabelObject) {
  return new Intl.NumberFormat().format(pointLabelObject.y);
}

/**
 * @param { Object } pointLabelObject - see Highcharts
 *   https://api.highcharts.com/class-reference/Highcharts.PointLabelObject
 * @return { string } formatted percentage of responses
 */
function percentOfResponses(pointLabelObject) {
  return Math.round(numberToPercentage(pointLabelObject.y, pointLabelObject.total));
}

const customTooltipBody = (pointLabelObject) => {
  const possibleAnswerContent = pointLabelObject.series.name;
  const totalResponses = new Intl.NumberFormat().format(pointLabelObject.total);

  return `${possibleAnswerContent} ${numResponses(pointLabelObject)} (${percentOfResponses(pointLabelObject)}%)<br><br>Total: ${totalResponses}`;
};

const absoluteBarLabels = (pointLabelObject) => {
  if (document.fullscreenElement || document.webkitCurrentFullScreenElement) {
    return `${numResponses(pointLabelObject)} (${percentOfResponses(pointLabelObject)}%)`;
  } else {
    return null;
  }
};

const scaledBarLabels = (pointLabelObject) => {
  return `${percentOfResponses(pointLabelObject)}% (${numResponses(pointLabelObject)})`;
};

/**
 * A trend report graph
 *
 * NOTE: This must not use hooks because Highcharts doesn't support them well.
 * Its event handlers lose hook state :(
 *
 * @param { Object } props
 * @return { JSX.Element } the graph
*/
class TrendChart extends React.Component {
  /**
   * Returns the data grouped by the specified ...group
   *
   * @param {string} dateGroup - the date group to group on
   * @return {array} the cached data series, or a new one if it does not exist
   */
  dataForGroup(dateGroup) {
    if (!this.cachedData[dateGroup]) {
      this.cachedData[dateGroup] = DateGrouping.dataGroupedBy(
          dateGroup, this.initialData,
      );
    }

    return this.cachedData[dateGroup];
  }

  /**
   * Produce a set of plot bands covering all weekends.
   * Returns bands for all potential weekends.
   * TODO: Only use filtered date range
   *
   * @return {array} an array of plot bands for Highcharts
   */
  getWeekendPlotBands() {
    const startYear = new Date(2014, 0, 1); // PI origins
    const endYear = new Date();

    const weekends = eachWeekendOfInterval({start: startYear, end: endYear});

    const plotBands = weekends.map((date) => {
      let startTime = startOfDay(date);
      let endTime = endOfDay(date);

      // straddles the data points nicely
      startTime = sub(startTime, {hours: 20});
      endTime = sub(endTime, {hours: 20});

      return {
        color: '#e3e7ea',
        from: startTime,
        to: endTime,
      };
    });

    return plotBands;
  }

  /**
   * Returns HighCharts chart options for a date group
   *
   * @param {string} dateGroup to get chart options for
   * @return {object} chartOptions for HighCharts
   */
  chartOptionsForDateGroup(dateGroup) {
    const chartOptions = {
      series: this.dataForGroup(dateGroup),
    };

    // e.g. Q1 '19
    const quarterLabel = (date) => {
      return `Q${getQuarter(date)} - '${date.getFullYear() % 100}`;
    };

    switch (dateGroup) {
      case DateGrouping.DATE_GROUP_DAY:
        chartOptions.xAxis = {
          tickInterval: milliseconds({days: 1}),
          labels: {
            format: '{value: %m/%d}',
            formatter: null,
          },
          plotBands: this.getWeekendPlotBands(),
        };
        chartOptions.tooltip = {
          // e.g. Sunday, Nov 10, 2019
          xDateFormat: '%A, %b %d, %Y',
          formatter: null,
        };
        break;
      case DateGrouping.DATE_GROUP_WEEK:
        chartOptions.xAxis = {
          tickInterval: milliseconds({weeks: 1}),
          labels: {
            formatter: function() {
              const date = new Date(this.value);

              return `W${getWeek(date)} - '${date.getFullYear() % 100}`;
            },
          },
          plotBands: [],
        };
        chartOptions.tooltip = {
          formatter: function(tooltip) {
            const date = new Date(this.x);

            // e.g. Sunday, Nov 10,2019 - Saturday, Nov 17, 2019
            const weekDateFormat = 'cccc, MMM d, y';
            const endDate = add(date, {weeks: 1});
            const header = `${format(date, weekDateFormat)} - ${format(endDate, weekDateFormat)}`;

            const body = customTooltipBody(this);

            return `${header}<br><br>${body}`;
          },
        };
        break;
      case DateGrouping.DATE_GROUP_MONTH:
        chartOptions.xAxis = {
          tickInterval: milliseconds({months: 1}),
          labels: {
            format: '{value:%b \'%y}',
            formatter: null,
          },
          plotBands: [],
        };
        chartOptions.tooltip = {
          // e.g. Nov 2019
          xDateFormat: '%b %Y',
          formatter: null,
        };
        break;
      case DateGrouping.DATE_GROUP_QUARTER:
        chartOptions.xAxis = {
          tickInterval: milliseconds({months: 3}),
          labels: {
            formatter: function() {
              return quarterLabel(new Date(this.value));
            },
          },
          plotBands: [],
        };
        chartOptions.tooltip = {
          formatter: function(tooltip) {
            const date = new Date(this.x);
            const header = quarterLabel(date);

            const body = customTooltipBody(this);

            return `${header}<br><br>${body}`;
          },
        };
        break;
      case DateGrouping.DATE_GROUP_YEAR:
        chartOptions.xAxis = {
          tickInterval: milliseconds({years: 1}),
          labels: {
            format: '{value:%Y}',
            formatter: null,
          },
          plotBands: [],
        };
        chartOptions.tooltip = {
          // e.g. 2019
          xDateFormat: '%Y',
          formatter: null,
        };
        break;
      default:
        console.debug('unexpected group value', dateGroup);
    }

    return chartOptions;
  }

  /**
   * Calculates the default date group based on the date range covered
   * by the data. A wide date range will use a larger group, e.g. year
   * @return { string } date group
   */
  calculateDefaultDateGroup() {
    const numDaysWithData = this.initialData.reduce((runningTotal, possibleAnswer) => {
      return Math.max(runningTotal, possibleAnswer.data.length);
    }, 0);

    // Thresholds were decided in ticket #2007
    if (numDaysWithData < 32) {
      return DateGrouping.DATE_GROUP_DAY;
    } else if (numDaysWithData < 91) {
      return DateGrouping.DATE_GROUP_WEEK;
    } else if (numDaysWithData < 731) {
      return DateGrouping.DATE_GROUP_MONTH;
    } else {
      return DateGrouping.DATE_GROUP_YEAR;
    }
  }

  /**
   * Calculates the default date group based on the date range covered
   * by the data. A wide date range will use a larger group, e.g. year
   * @return {object} foo
   */
  generateDefaultChartOptions() {
    return {
      chart: {
        type: 'column',
        height: 200,
      },
      title: {
        // We'll provide our own title outside of Highcharts,
        text: '',
      },
      xAxis: {
        type: 'datetime',
        tickInterval: milliseconds({days: 1}),
        labels: {
          formatter: function() {
            return Date(this.value);
          },
        },
        plotBands: [],
      },
      yAxis: {
        min: 0,
        title: {
          text: '',
        },
        stackLabels: {
          enabled: true,
          style: {
            fontWeight: 'bold',
            color: 'gray',
          },
          formatter: function() {
            return new Intl.NumberFormat().format(this.total);
          },
        },
      },
      legend: {
        align: 'center',
        verticalAlign: 'top',
        backgroundColor: '#fff',
        shadow: false,
      },
      tooltip: {
        xDateFormat: 'e.g. %Y-%m-%d',
        headerFormat: '<h3>{point.key}</h3><br><br>',
        pointFormatter: function() {
          return customTooltipBody(this);
        },
        formatter: null,
      },
      plotOptions: {
        column: {
          stacking: 'normal',
          dataLabels: {
            enabled: true,
            formatter: function() {
              return absoluteBarLabels(this);
            },
          },
        },
      },
      exporting: {
        enabled: false,
      },
      series: this.chartOptionsForDateGroup(this.defaultDateGroup),
      credits: {
        enabled: false,
      },
    };
  }

  /**
   * (Re)Initializes TrendChart
   */
  initialize() {
    this.initialData = this.props.seriesData;
    this.cachedData = {};

    this.defaultDateGroup = this.calculateDefaultDateGroup();
    this.defaultChartType = 'absolute';

    this.defaultChartOptions = this.generateDefaultChartOptions();

    this.dataLastUpdatedAt = Date.now();
  }

  /**
   * Initializes TrendChart
   * @param { Object } props - see PropTypes
   */
  constructor(props) {
    super(props);

    this.initialize();

    this.state = {
      dateGroup: this.defaultDateGroup,
      ...this.mergeChartOptions(this.defaultChartOptions, this.chartOptionsForDateGroup(this.defaultDateGroup)),
    };
  }

  /**
   * Updates the chartOptions used by HighCharts.
   * @param {object} newOptions - the new chart options
   */
  updateChartOptions(newOptions) {
    this.setState({
      ...this.mergeChartOptions(this.state.chartOptions, newOptions),
    });
  }

  /**
   * Merge two sets of chartOptions for HighCharts.
   * Sort of a deep PATCH.
   *
   * @param {object} oldOptions - chart options to override
   * @param {object} newOptions - overrides any existing options in oldOptions
   * @return {object} an object containing a new set of chart options
   */
  mergeChartOptions(oldOptions, newOptions) {
    return {
      chartOptions: {
        ...oldOptions,
        ...newOptions,
        xAxis: {
          ...oldOptions.xAxis,
          ...newOptions.xAxis,
        },
        tooltip: {
          ...oldOptions.tooltip,
          ...newOptions.tooltip,
        },
      },
    };
  }

  /**
   * Store a reference to the highchart object after its initial creation
   * @param {object} chart - highchart reference
   */
  afterChartCreated(chart) {
    this.props.setInternalChart(chart);
  }

  /**
   * Sets the date group (e.g. month, day, week)
   * @param {string} newDateGroup - the new date group
   */
  setDateGroup(newDateGroup) {
    this.setState({
      dateGroup: newDateGroup,
    });
    this.updateChartOptions(this.chartOptionsForDateGroup(newDateGroup));
  }

  /**
   * Decides whether the new props warrant an update of
   * this component's derived state.
   * @param {object} nextProps - the new props
   */
  componentDidUpdate(nextProps) {
    if (nextProps.dataLastUpdatedAt > this.dataLastUpdatedAt) {
      this.updateSeries();
    } else {
      // series data props not changed -- skipping update
    }
  }

  /**
   * Use this to force reinitialization of the component
   * Basically for when state derived from props changes, e.g. series data
   */
  updateSeries() {
    this.initialize();

    this.setState({
      dateGroup: this.defaultDateGroup,
      ...this.mergeChartOptions(
          this.defaultChartOptions,
          this.chartOptionsForDateGroup(this.defaultDateGroup),
      ),
    });
  }

  /**
   * Renders the Trend Report
   * @return {JSX.Element}
   */
  render() {
    return (
      <div className='chart-container'>
        <ChartControls
          chartId={this.props.chartId}
          defaultDateGroup={this.defaultDateGroup}
          defaultChartType={this.defaultChartType}
          updateChart={(newOptions) => {
            this.updateChartOptions(newOptions);
          }}
          setDateGroup={(newDateGroup) => {
            this.setDateGroup(newDateGroup);
          }}
        />
        <HighchartsReact
          highcharts={Highcharts}
          callback={(chart) => {
            this.afterChartCreated(chart);
          }}
          options={
            {
              ...this.state.chartOptions,
              series: this.state.chartOptions.series.map((series) => {
                return ({
                  ...series,
                  data: [...series.data], // Crucial. Highcharts will mess with the original data in unexpected ways
                  color: this.props.newColors[series.id],
                });
              }),
            }
          }
        />
      </div>
    );
  }
}

TrendChart.propTypes = {
  seriesData: PropTypes.array.isRequired,
  newColors: PropTypes.object.isRequired,
  chartId: PropTypes.number.isRequired,
  setInternalChart: PropTypes.func.isRequired,
  dataLastUpdatedAt: PropTypes.number,
};

export default TrendChart;
