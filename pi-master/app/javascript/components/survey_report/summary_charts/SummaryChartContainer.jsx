import React from 'react';
import PropTypes from 'prop-types';

import SummaryChart from './SummaryChart';
import CalendarIcon from '../../../images/calendar.svg';

// Contains and provides data for header charts
// NOTE: Don't use SummaryChart without this
const SummaryChartContainer = (props) => {
  const [
    asyncChartData,
    setAsyncChartData,
  ] = React.useState({
    impressions: [],
    submissions: [],
    submissionRate: [],
  });

  const [
    asyncChartSummaries,
    setAsyncChartSummaries,
  ] = React.useState({
    impressions: 'calculating...',
    submissions: 'calculating...',
    submissionRate: 'calculating...',
  });

  const [
    chartSummariesLoadingState,
    setChartSummariesLoadingState,
  ] = React.useState(true);

  // Asynchronously load data for charts
  const loadSummaryChartData = () => {
    $.ajax({
      url: props.asyncDataUrl,
    }).done(function(responseData) {
      const newData = {
        impressions: responseData.impression_sum,
        submissions: responseData.submission_sum,
        submissionRate: responseData.rate,
      };

      setAsyncChartData(newData);
    }).fail(function(jqXHR, textStatus, errorThrown) {
      console.debug('failed to get data', jqXHR, textStatus, errorThrown);
    });
  };

  // Asynchronously load summary line for charts
  const loadSummaryChartSummaries = () => {
    $.ajax({
      url: props.asyncSummariesUrl,
    }).done(function(responseData) {
      const newChartSummaries= {
        impressions: responseData.impression_count,
        submissions: responseData.submission_count,
        submissionRate: responseData.submission_rate,
      };

      setAsyncChartSummaries(newChartSummaries);
      setChartSummariesLoadingState(false);
    }).fail(function(jqXHR, textStatus, errorThrown) {
      console.debug('failed to get data', jqXHR, textStatus, errorThrown);
    });
  };

  React.useEffect(() => {
    // TODO: Use React for the entire reporting page so that we
    // don't have to shuffle things around like this
    $('.summary-charts-container').insertBefore('#summary-charts-anchor');

    loadSummaryChartData();
    loadSummaryChartSummaries();
  }, []);

  // Data set by the props after page load takes precedence over async data
  const currentChartData = props.newChartData ?
    props.newChartData : asyncChartData;
  const currentChartSummaries = props.newChartSummaries ?
    props.newChartSummaries : asyncChartSummaries;

  return (
    <div className='summary-charts-container'>
      <SummaryChart
        data={currentChartData.impressions}
        header={'Impressions'}
        summary={currentChartSummaries.impressions}
        loading={chartSummariesLoadingState}
      />
      <SummaryChart
        data={currentChartData.submissions}
        header={'Submissions'}
        summary={currentChartSummaries.submissions}
        loading={chartSummariesLoadingState}
      />
      <SummaryChart
        data={currentChartData.submissionRate}
        header={'Submission Rate'}
        summary={currentChartSummaries.submissionRate}
        loading={chartSummariesLoadingState}
        tooltipBody={
          (chartObject) => {
            let dataForDate = currentChartData.submissionRate.find((datum) => {
              return datum[0] === (chartObject.x);
            })[1];

            dataForDate = new Intl.NumberFormat().format(dataForDate);
            dataForDate = `${Number.parseInt(dataForDate * 100)}%`;

            return `<p>${dataForDate} submission rate.<br>`;
          }
        }
      />
      <div className='summary-chart dates-active'>
        <h1 className='highcharts-title'>
          {props.numDaysActive}
        </h1>
        <h2 className='highcharts-subtitle'>
          Days Active
        </h2>
        <span
          className="background-icon"
          style={{
            maskImage: `url(${CalendarIcon})`,
            WebkitMaskImage: `url(${CalendarIcon})`,
          }}
        >
        </span>
      </div>
    </div>
  );
};

SummaryChartContainer.propTypes = {
  numDaysActive: PropTypes.number.isRequired,
  newChartData: PropTypes.object,
  newChartSummaries: PropTypes.object,
  asyncDataUrl: PropTypes.string.isRequired,
  asyncSummariesUrl: PropTypes.string.isRequired,
};

export default SummaryChartContainer;
