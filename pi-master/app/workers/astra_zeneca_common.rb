# frozen_string_literal: true

# rubocop:disable Metrics/ModuleLength
module AstraZenecaCommon
  AZ_ANEMIA = 264 # AstraZeneca Rethink Anemia of CKD
  AZ_FARXIGA_HCP = 266 # AstraZeneca Farxiga HCP
  AZ_FARXIGA_CONSUMER = 272 # AstraZeneca Farxiga Consumer
  AZ_BYDUREON_CONSUMER = 273 # AstraZeneca Bydureon Consumer
  AZ_BRILINTA_CONSUMER = 274 # AstraZeneca Brilinta Consumer
  AZ_BRILINTA_HCP = 275 # AstraZeneca Brilinta HCP
  AZ_BREZTRI_HCP = 282 # AstraZeneca Breztri HCP
  AZ_BYDUREON_HCP = 292 # Astrazeneca | Bydureon HCP
  AZ_PRECISION_MED = 296 # AstraZeneca | Precision Med
  AZ_LOKELMA = 298 # AstraZeneca | Lokelma HCP
  AZ_FASENRA_HCP = 293 # AstraZeneca Fasenra HCP
  AZ_CALQUENCE_HCP = 313 # AstraZeneca Calquence HCP
  AZ_MY_WAYPOINT_AZ = 322 # (AstraZeneca MyWaypointAZ)
  AZ_CALQUENCE = 353 # AstraZeneca Calquence Consumer
  AZ_TEZSPIRE_HCP = 312 # AstraZeneca Tezspire HCP
  AZ_LOKELMA_CONSUMER = 346 # AstraZeneca Lokelma Consumer
  AZ_LYNPARZA = 314 # AstraZeneca Lynparza HCP
  AZ_AIRSUPRA = 386 # AstraZeneca Airsupra Unbranded

  AZ_HCP_ACCOUNTS = [
    AZ_FARXIGA_HCP,
    AZ_BRILINTA_HCP,
    AZ_BREZTRI_HCP,
    AZ_BYDUREON_HCP,
    AZ_PRECISION_MED,
    AZ_LOKELMA,
    AZ_FASENRA_HCP,
    AZ_CALQUENCE_HCP,
    AZ_TEZSPIRE_HCP,
    AZ_LYNPARZA
  ].freeze

  ALL_AZ_ACCOUNTS = (
    [
      AZ_ANEMIA,
      AZ_CALQUENCE,
      AZ_FARXIGA_CONSUMER,
      AZ_BYDUREON_CONSUMER,
      AZ_BRILINTA_CONSUMER,
      AZ_MY_WAYPOINT_AZ,
      AZ_LOKELMA_CONSUMER,
      AZ_AIRSUPRA
    ] + AZ_HCP_ACCOUNTS
  ).freeze

  ACCOUNT_INFO = {
    AZ_CALQUENCE => {
      url: "https://www.calquence.com/",
      custom_identifier: "Unknown",
      identifier: "PI-13880098"
    },
    AZ_ANEMIA => {
      url: "www.rethinkanemiaofckd.com",
      custom_identifier: "aa301501e3",
      identifier: "PI-22996544"
    },
    AZ_FARXIGA_HCP => {
      url: "www.farxiga-hcp.com",
      custom_identifier: "f9e216de17",
      identifier: "PI-25917395"
    },
    AZ_FARXIGA_CONSUMER => {
      url: "www.farxiga.com",
      custom_identifier: nil,
      identifier: "PI-58922696"
    },
    AZ_BYDUREON_CONSUMER => {
      url: "www.bydureon.com/bydureon-bcise.html",
      custom_identifier: nil,
      identifier: "PI-60354020"
    },
    AZ_BRILINTA_CONSUMER => {
      url: "www.brilinta.com",
      custom_identifier: nil,
      identifier: "PI-84014262"
    },
    AZ_BRILINTA_HCP => {
      url: "www.brilintahcp.com",
      custom_identifier: "d7e741ca95",
      identifier: "PI-15118518"
    },
    AZ_BREZTRI_HCP => {
      url: "www.BreztriHCP.com",
      custom_identifier: "d89308fae3",
      identifier: "PI-67126468"
    },
    AZ_BYDUREON_HCP => {
      url: "www.bydureonhcp.com",
      custom_identifier: "ef0307828a",
      identifier: "PI-88269384"
    },
    AZ_PRECISION_MED => {
      url: "azprecisionmed.com",
      custom_identifier: "999f6317dd",
      identifier: "PI-26436716"
    },
    AZ_LOKELMA => {
      url: "www.lokelma-hcp.com",
      custom_identifier: "b59488dbc6",
      identifier: "PI-87471538"
    },
    AZ_FASENRA_HCP => {
      url: "https://www.fasenrahcp.com/",
      custom_identifier: "2c23f9bdac",
      identifier: "PI-05402076"
    },
    AZ_CALQUENCE_HCP => {
      url: "https://www.calquencehcp.com/",
      custom_identifier: "c227c16734",
      identifier: "PI-85060290"
    },
    AZ_MY_WAYPOINT_AZ => {
      url: "https://www.mywaypointaz.com/",
      custom_identifier: nil,
      identifier: "PI-96619421"
    },
    AZ_TEZSPIRE_HCP => {
      url: "https://www.tezspirehcp.com/",
      custom_identifier: "7609df5c5f",
      identifier: "PI-56074549"
    },
    AZ_LOKELMA_CONSUMER => {
      url: "https://www.lokelma.com",
      custom_identifier: nil,
      identifier: "PI-46887353"
    },
    AZ_LYNPARZA => {
      url: "www.lynparzahcp.com",
      custom_identifier: nil,
      identifier: "PI-04254011"
    },
    AZ_AIRSUPRA => {
      url: "www.risinginflammation.com",
      custom_identifier: nil,
      identifier: "PI-26567439"
    }
  }.freeze

  def wec_id_sql
    cases = @az_accounts.map do |account_id|
      info = ACCOUNT_INFO[account_id]
      next unless custom_identifier = info[:custom_identifier]

      "WHEN s.identifier = '#{info[:identifier]}' THEN '#{custom_identifier}'"
    end.compact.join("\n")

    <<-SQL
      CASE
        #{cases}
        ELSE 'Unknown'
      END wec_id
    SQL
  end

  def survey_website_sql
    cases = @az_accounts.map do |account_id|
      info = ACCOUNT_INFO[account_id]
      next unless url = info[:url]

      "WHEN s.identifier = '#{info[:identifier]}' THEN '#{url}'"
    end.compact.join("\n")

    <<-SQL
      CASE
        #{cases}
        ELSE 'Unknown'
      END survey_website
    SQL
  end

  def answers_rows
    @answers_rows ||= postgres_execute(answers_sql, readonly: true)
  end

  def report_start_date
    if @start_date
      @start_date.utc.beginning_of_day
    else
      @date.utc.yesterday.beginning_of_day
    end
  end

  def report_end_date
    if @end_date
      @end_date.utc.end_of_day
    else
      @date.utc.yesterday.end_of_day
    end
  end

  def upload_to_s3(filename)
    s3_credentials = Rails.application.credentials.astra_zeneca

    begin
      transfer_to_s3(filename, s3_credentials)
      # AstraZeneca updates their keys every three months.
      # To avoid missed reports, we'll try the new ones before falling back to the old ones.
    rescue Aws::S3::Errors::InvalidAccessKeyId => _e
      old_credentials = s3_credentials.dup.merge!(
        access_key_id: s3_credentials.old_access_key_id,
        secret_access_key: s3_credentials.old_secret_access_key
      )

      transfer_to_s3(filename, old_credentials)
    end
  end

  def answers_sql
    <<-SQL
      SELECT *,
        substring(s.user_agent from '\\((.*?)\\)') os,
        #{previous_surveys_sql},
        #{browser_version_sql},
        #{wec_id_sql},
        #{survey_website_sql}
        FROM (
          SELECT
            accounts.identifier,
            accounts.name,
            submissions.view_name view_name,
            answers.submission_id submission_id,
            devices.id device_id,
            submissions.created_at submission_created_at,
            to_char(answers.created_at AT TIME ZONE 'UTC' AT TIME ZONE 'EST', 'MM/DD/YYYY') AS date,
            to_char(answers.created_at AT TIME ZONE 'UTC' AT TIME ZONE 'EST', 'HH24:MI:SS') AS time,
            questions.content question,
            CASE  WHEN questions.question_type = 1 THEN answers.text_answer
                  ELSE possible_answers.content
            END response,
            string_agg(tags.name, ', ') tags,
            questions.survey_id survey_id,
            questions.id question_id,
            answers.possible_answer_id response_id,
            submissions.pageview_count,
            submissions.visit_count,
            submissions.device_type,
            #{channel_sql},
            devices.udid,
            devices.client_key,
            submissions.url,
            submissions.pseudo_event,
            submissions.custom_data::text,
            device_data.device_data,
            #{next_question_id_sql},
            submissions.user_agent,
            #{browser_sql},
            #{google_nlp_sql},
            to_char(answers.created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD HH24:MI:SS.US') AS timestamp
            FROM answers
            LEFT JOIN submissions ON submissions.id = answers.submission_id
            LEFT JOIN surveys ON surveys.id = submissions.survey_id
            LEFT JOIN accounts ON accounts.id = surveys.account_id
            LEFT JOIN questions ON questions.id = answers.question_id
            LEFT JOIN possible_answers ON possible_answers.id = answers.possible_answer_id
            LEFT JOIN applied_tags ON applied_tags.answer_id = answers.id
            LEFT JOIN tags ON tags.id = applied_tags.tag_id
            LEFT JOIN devices ON submissions.device_id = devices.id
            LEFT JOIN device_data ON device_data.device_id = devices.id AND device_data.account_id = surveys.account_id
            WHERE accounts.id IN (#{@az_accounts.join(', ')})
                AND answers.created_at BETWEEN '#{PG::Connection.escape(report_start_date.to_s)}' AND '#{PG::Connection.escape(report_end_date.to_s)}'
            GROUP BY accounts.identifier, accounts.name, answers.id, submissions.id, questions.id, possible_answers.id, devices.id, device_data.id
            ORDER BY answers.created_at DESC) s
    SQL
  end
end
