import React from 'react';

import { CSVLink } from 'react-csv';

interface CSVDownloadLinkProps {
  columns: Array<object>
  table: object
}

/**
 * @param {CSVDownloadLinkProps} props
 * @return { JSX.Element }
 */
function CSVDownloadLink(props: CSVDownloadLinkProps) {
  const csvColumnIds = props.columns.filter((column) => {
    return column.meta.includeInCSV;
  }).map((column) => {
    return column.id;
  });

  const csvData = () => {
    return props.table.getRowModel().rows.map((row) => {
      return csvColumnIds.map((columnId) => {
        const value = row.getValue(columnId);

        const column = props.table.getColumn(columnId);
        const csvFormatter = column.columnDef.meta.formatForCsv;

        if (csvFormatter) {
          return csvFormatter(value);
        } else {
          return value;
        }
      });
    });
  };

  return (
    <button className='csv-export-link-wrapper'>
      <CSVLink
        headers={csvColumnIds}
        filename='Pulse Insights Text Responses Report.csv'
        data={csvData()} // TODO: Compile data on demand, not on render
        className='csv-export-link'
      >
        Export Data
      </CSVLink>
    </button>
  );
}

export default CSVDownloadLink;
