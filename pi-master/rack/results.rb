# frozen_string_literal: true

module Rack
  module Results
    include Common

    def results
      required_params = %w(identifier submission_udid)

      error = verify_required_params(required_params)
      return error if error

      error = verify_account(@params["identifier"], @params["callback"])
      return error if error.any?

      error_message = verify_ip_address
      return jsonp_response(@params["callback"], error_message) if error_message

      if @params["accept"] == "application/json"
        json_results
      else
        html_results
      end
    end

    private

    def html_results
      @identifier = @params['identifier']
      @submission_udid = @params['submission_udid']
      @headers = {}
      @headers['Content-Type'] = 'text/html; charset=utf-8'
      log_time

      [200, @headers, [raw_html]]
    end

    def json_results
      @headers = {}
      @headers["Content-Type"] = "application/json"

      survey_id = get_survey_id_by_submission_udid(@params["submission_udid"])
      results_rows = get_survey_results(survey_id)
      result_rows_by_question_id = results_rows.group_by { |row| row["question_id"].to_i }

      results_hash = {
        questions: result_rows_by_question_id.map do |question_id, rows|
          {
            id: question_id,
            position: rows.first["question_position"].to_i,
            content: rows.first["question_content"],
            possibleAnswers: rows.map do |row|
              {
                id: row["possible_answer_id"].to_i,
                position: row["possible_answer_position"].to_i,
                content: row["possible_answer_content"],
                numAnswers: row["answers_count"].to_i
              }
            end
          }
        end
      }

      response_results = { results: results_hash }.to_json

      jsonp_response(@params['callback'], response_results, @headers)
    end

    def raw_html
      <<-HTML
        <!DOCTYPE html>
        <html>
          <head>
            <title>Results - Crafted with Pulse Insights</title>
            <script src="https://ajax.googleapis.com/ajax/libs/jquery/3.2.1/jquery.min.js"></script>
            <script>
              #{tag_code}
            </script>
          </head>
          <body>
          </body>
        </html>
      HTML
    end

    def tag_code
      @survey_js_host = survey_js_host
      @survey_host = survey_host[@environment]
      @present_results = true

      ERB.new(tag_js).result(binding) # See this file to see all the bindings
    end

    def tag_js
      tag_js_version = postgres_execute("SELECT tag_js_version FROM accounts WHERE identifier = '#{@identifier}'").first['tag_js_version']
      ::File.read(::File.expand_path("../lib/assets/tag_#{tag_js_version}.js.erb", __dir__))
    end

    def survey_js_host
      {
        'test' => 'http://localhost:8888/assets',
        'development' => 'http://localhost:3000/assets', # local
        'production' => '//js.pulseinsights.com',
        'staging' => '//js-staging.pulseinsights.com',
        'develop' => '//js-develop.pulseinsights.com'
      }[@environment]
    end
  end
end
