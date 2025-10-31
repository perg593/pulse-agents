import React from 'react';
import PropTypes from 'prop-types';

import PiModal from '../modal_dialog/PiModal';

import Spinner from '../Spinner.jsx';
import DownloadIcon from '../../images/file_download.svg';

ReportJob.propTypes = {
  reportJob: PropTypes.object.isRequired,
  /*
   * TODO: Come up with a way of codifying this.
   * Typescript?
   * Spec from backend?
   *
   * createdAt {number} only for admins
   * updatedAt {number} only for admins
   * status {string} ['created', 'in_progress', 'done']
   * downloadUrl {string} a link to the report on S3
   * emailAddress {string}
   */
};

/**
 * Render a single Report Job
 * @param {object} props - see propTypes
 * @return {JSX.Element}
*/
function ReportJob(props) {
  /**
   * Prints a formatted date cell
   * @param {string} field - the report time field to print
   * @return {JSX.Element}
  */
  function printTimeField(field) {
    if (props.reportJob[field]) {
      return (<td>{formatDatetimeString(props.reportJob[field])}</td>);
    } else {
      return null;
    }
  }

  /**
   * Formats a datetime string
   * @param {string} datetime
   * @return {string}
  */
  function formatDatetimeString(datetime) {
    const date = new Date(datetime);
    const format = {dateStyle: 'long', timeStyle: 'long'};

    return Intl.DateTimeFormat([], format).format(date);
  }

  if (props.reportJob.status === 'created') {
    return (
      <tr>
        <td className='spinner-cell'>
          <Spinner className='report-job-spinner' />
          <span>Queued</span>
        </td>
        { printTimeField(['createdAt']) }
        <td>The report will be processed shortly.</td>
      </tr>
    );
  } else if (props.reportJob.status === 'in_progress') {
    return (
      <tr>
        <td className='spinner-cell'>
          <Spinner className='report-job-spinner' />
          <span>In Progress</span>
        </td>
        { printTimeField(['updatedAt']) }
        <td>
          An e-mail notification will be sent to {props.reportJob.emailAddress}
        </td>
      </tr>
    );
  } else if (props.reportJob.status === 'done') {
    return (
      <tr>
        <td>Done!</td>
        { printTimeField(['updatedAt']) }
        <td>
          <a href={props.reportJob.downloadUrl}>Download the report</a> (copy sent to {props.reportJob.emailAddress})
        </td>
      </tr>
    );
  }
}

ExportPopup.propTypes = {
  reportJobs: PropTypes.array.isRequired,
  createReport: PropTypes.func.isRequired,
  errorMessage: PropTypes.string,
};

/**
 * Render a report job popup
 * @param {object} props - see propTypes
 * @return {JSX.Element}
 */
function ExportPopup(props) {
  const ErrorMessage = ({errorMessage}) => {
    if (errorMessage) {
      return (
        <p className='error-message'>
          { errorMessage }
        </p>
      );
    } else {
      return null;
    }
  };

  const reportJobTable = () => {
    return (
      <>
        <h2>Your last 5 exports:</h2>
        <h3>(Reports are available for 7 days)</h3>
        <table>
          <thead>
            <tr>
              <th>Status</th>
              {
                props.reportJobs[0]?.updatedAt ?
                  <th>Requested/Updated At</th> : null
              }
              <th></th>
            </tr>
          </thead>
          <tbody>
            {
              props.reportJobs.map((reportJob) => {
                return (
                  <ReportJob key={reportJob.id} reportJob={reportJob} />
                );
              })
            }
          </tbody>
        </table>
      </>
    );
  };

  const dialogRef = React.useRef(null);

  const openDialog = () => {
    if (dialogRef.current) {
      dialogRef.current.showModal();
    }
  };

  return (
    <>
      <button
        className='export-button'
        onClick={() => {
          if (props.reportJobs.length === 0) {
            props.createReport();
          }

          openDialog();
        }}
      >
        <div className='labeled-icon-container'>
          <span
            className='button-icon'
            style={{
              maskImage: `url(${DownloadIcon})`,
              WebkitMaskImage: `url(${DownloadIcon})`,
            }}
          >
          </span>
          <span>Export Results</span>
        </div>
      </button>

      <PiModal
        ref={dialogRef}
        modalClassName='export-modal'
      >
        <PiModal.Header title='Export Status' titleClassName='modal-title' />

        <PiModal.Body>
          <ErrorMessage errorMessage={props.errorMessage} />
          { props.reportJobs.length > 0 ? reportJobTable() : null }
        </PiModal.Body>

        <PiModal.Footer>
          <button
            className='generate-report-button'
            onClick={() => props.createReport()}
            disabled={props.errorMessage}
          >
            Request New Report
          </button>
        </PiModal.Footer>
      </PiModal>
    </>
  );
}

const ReportFooter = (props) => {
  const [errorMessage, setErrorMessage] = React.useState('');
  const [reportJobs, setReportJobs] = React.useState(props.reportJobs);
  const [pollingIntervalId, setPollingIntervalId] = React.useState(null);

  /**
   * Poll the backend for report job updates
  */
  function pollForUpdates() {
    const unfinishedReports = reportJobs.filter((reportJob) => {
      return reportJob.status !== 'done';
    });

    unfinishedReports.forEach((reportJob) => {
      const reportStatusUrl = `/report_jobs/${reportJob.id}/status`;

      $.ajax({
        url: reportStatusUrl,
      }).done(function(responseData) {
        const changed = reportJob.status != responseData.status ||
          reportJob.downloadUrl != responseData.url;

        if (changed) {
          const newReportJobs = [...reportJobs];

          const reportJobIndex = newReportJobs.findIndex((job) => {
            return job.id === reportJob.id;
          });

          newReportJobs[reportJobIndex] = {
            ...reportJob,
            status: responseData.status,
            downloadUrl: responseData.url,
          };

          setReportJobs(newReportJobs);
        }
      }).fail(function(jqXHR, textStatus, errorThrown) {
        console.debug('error!', jqXHR, textStatus, errorThrown);
      });
    });
  }

  /**
   * Starts a timer to poll report job status at regular intervals
  */
  function startPolling() {
    const pollingInterval = 3000;

    if (pollingIntervalId) {
      clearInterval(pollingIntervalId);
    }

    const interval = setInterval((() => {
      if (reportJobs.some((reportJob) => reportJob.status !== 'done')) {
        pollForUpdates();
      } else {
        clearInterval(interval);
      }
    }), pollingInterval);

    setPollingIntervalId(interval);
  };

  /**
   * Create a report job via AJAX
  */
  function createReport() {
    const filterParams = new URLSearchParams(window.location.search);

    $.ajax({
      url: props.reportCreationPath,
      data: filterParams.toString(),
      method: 'POST',
    }).done(function(responseData) {
      setReportJobs([responseData.reportJob, ...reportJobs]);
    }).fail(function(jqXHR, textStatus, errorThrown) {
      setErrorMessage(jqXHR.responseJSON.error);
    });
  }

  // We want this to run:
  // 1 - When we first load the page
  // 2 - Whenever reportJobs changes
  React.useEffect(startPolling, [reportJobs]);

  return (
    <div className='report-footer'>
      <ExportPopup
        createReport={createReport}
        reportJobs={reportJobs}
        errorMessage={errorMessage}
      />
    </div>
  );
};

ReportFooter.propTypes = {
  reportCreationPath: PropTypes.string.isRequired,
  reportJobs: PropTypes.array.isRequired,
};

export default ReportFooter;
