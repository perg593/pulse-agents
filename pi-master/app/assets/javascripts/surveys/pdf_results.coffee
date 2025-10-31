window.PulseInsightsInclude window.PulseInsights,
  downloadPdfResults: (params) ->
    PulseInsightsObject.pdfDownloadButton().disabled = true

    params['pdf_results'] = true
    baseUrl = PulseInsightsObject.protocol() + '//' + PulseInsightsObject.rackAppDomain()
    requestUrl = new URL("/submissions/#{PulseInsightsObject.submission.udid}/all_answers?", baseUrl)
    requestUrl.search = new URLSearchParams(params).toString()

    fetch requestUrl
      .then (response) ->
        fileName = response.headers.get('File-Name')
        return response.blob().then (pdf) ->
          PulseInsightsObject.triggerPdfDownload(fileName, pdf)
      .catch (error) ->
        PulseInsightsObject.log "Error while downloading PDF: "+error
      .finally () ->
        PulseInsightsObject.pdfDownloadButton().disabled = false

  triggerPdfDownload: (fileName, pdf) ->
    url = window.URL.createObjectURL(pdf)

    downloadTriggerLink = document.createElement('a')
    downloadTriggerLink.href = url
    downloadTriggerLink.download = fileName

    widgetContainer = PulseInsightsObject.survey.widgetContainer
    widgetContainer.appendChild(downloadTriggerLink)
    downloadTriggerLink.click()
    widgetContainer.removeChild(downloadTriggerLink)

    window.URL.revokeObjectURL(url)

  pdfDownloadButton: ->
    PulseInsightsObject.survey.allSubmitButton
