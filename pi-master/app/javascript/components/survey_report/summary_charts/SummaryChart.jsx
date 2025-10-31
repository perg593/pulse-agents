import React from 'react';
import PropTypes from 'prop-types';

import Highcharts from 'highcharts';
import HighchartsReact from 'highcharts-react-official';

import Spinner from '../../Spinner';

// A single header chart
// NOTE: Don't use this without a SummaryChartContainer
const SummaryChart = (props) => {
  const customTooltipBody = (chartObject) => {
    if (props.tooltipBody) {
      return props.tooltipBody(chartObject);
    } else {
      let value = chartObject.y;
      value = new Intl.NumberFormat().format(value);

      let dataForDate = props.data.find((datum) => {
        return datum[0] === (chartObject.x);
      })[1];

      dataForDate = new Intl.NumberFormat().format(dataForDate);

      return `<p>${dataForDate} ${props.header}.<br>${value} ${props.header} to date.</p>`;
    }
  };

  const runningTotals = () => {
    let runningTotal = 0;

    return props.data.map((datum) => {
      runningTotal += datum[1];
      return [datum[0], runningTotal];
    });
  };

  const options = {
    chart: {
      type: 'area',
      lineWidth: 1,
      styledMode: true,
    },
    title: {
      text: props.summary,
      align: 'left',
    },
    subtitle: {
      text: props.header,
      y: 40,
      align: 'left',
    },
    yAxis: {
      title: {
        text: '',
      },
      labels: {
        enabled: false,
      },
      visible: false,
    },
    xAxis: {
      type: 'datetime',
      labels: {
        enabled: false,
      },
      title: {
        text: '',
      },
      visible: false,
    },
    legend: {
      enabled: false,
    },
    series: [{
      data: runningTotals(),
      marker: {
        enabled: false,
      },
    }],
    tooltip: {
      xDateFormat: '%b %d, %Y',
      headerFormat: '<h3>{point.key}</h3><br><br>',
      pointFormatter: function() {
        return customTooltipBody(this);
      },
      formatter: null,
    },
    exporting: {
      enabled: false,
    },
    credits: {
      enabled: false,
    },
  };

  return (
    <div className='summary-chart'>
      <HighchartsReact
        highcharts={Highcharts}
        options={options}
        containerProps={{style: {height: '100%'}}}
      />
      { props.loading ? <Spinner className='summary-chart-spinner' /> : null }
    </div>
  );
};

SummaryChart.propTypes = {
  data: PropTypes.array,
  header: PropTypes.string.isRequired,
  loading: PropTypes.bool,
  summary: PropTypes.oneOfType([
    PropTypes.string.isRequired,
    PropTypes.number.isRequired,
  ]),
  tooltipBody: PropTypes.func,
};

export default SummaryChart;
