# frozen_string_literal: true
class AnswersDatatable
  delegate :params, to: :@view

  def initialize(view, start_date, end_date)
    delete_answers(view.params[:answer_ids]) if view.params[:answer_ids].present?
    @view = view
    @start_date = start_date
    @end_date = end_date
  end

  def as_json(_options = {})
    {
      sEcho: params[:sEcho].to_i,
      iTotalRecords: answers.total_entries,
      iTotalDisplayRecords: answers.total_entries,
      aaData: data
    }
  end

  private

  def delete_answers(answer_ids)
    Answer.where(id: answer_ids).destroy_all
  end

  def data
    answers.map do |answer|
      [
        answer.created_at.strftime('%Y/%m/%d'),
        answer.created_at.strftime('%H:%M:%S'),
        answer.q_content,
        answer.pa_content || answer.text_answer,
        answer.question_id,
        answer.id,
        answer.next_question_id,
        answer.survey_id,
        answer.pageview_count,
        answer.visit_count,
        answer.sub_ip_address,
        answer.device_type,
        answer.udid,
        answer.client_key,
        answer.sub_url,
        answer.sub_custom_data.to_s,
        answer.sub_user_agent
      ]
    end
  end

  def answers
    @answers ||= fetch_answers
  end

  def fetch_answers
    answers = if @start_date.present? && @end_date.present?
      Answer.where('answers.created_at BETWEEN ? AND ?', @start_date, @end_date)
    else
      Answer.where('answers.created_at >= ?', @start_date)
    end

    answers = answers.order("#{sort_column} #{sort_direction}").joins(submission: :device).joins(question: :survey).
              joins('LEFT JOIN possible_answers ON possible_answers.id = answers.possible_answer_id')
    answers = answers.page(page).per_page(per_page)
    answers = answers.select('answers.created_at, questions.content q_content, possible_answers.content pa_content,
                              answers.question_id, answers.id, questions.next_question_id', 'submissions.id submission_id',
                             'submissions.survey_id', 'submissions.pageview_count', 'submissions.visit_count',
                             'submissions.ip_address sub_ip_address', 'submissions.device_type', 'devices.udid',
                             'devices.client_key', 'submissions.url sub_url', 'submissions.custom_data sub_custom_data',
                             'submissions.user_agent sub_user_agent', 'surveys.account_id', 'answers.text_answer', 'answers.possible_answer_id')

    # Special filter on: Time Range
    if params[:search][:value].present?
      answers = filtered_answers(answers, params[:search][:value])
    end

    # Footer searches
    footer_searches(answers)
  end

  def footer_searches(answers)
    question_id = params[:columns][:'4'][:search][:value]
    answers = answers.where('answers.question_id = ?', question_id) if question_id.present?

    response_id = params[:columns][:'5'][:search][:value]
    answers = answers.where('answers.id = ?', response_id) if response_id.present?

    next_question_id = params[:columns][:'6'][:search][:value]
    answers = answers.where('questions.next_question_id = ?', next_question_id) if next_question_id.present?

    survey_id = params[:columns][:'7'][:search][:value]
    answers = answers.where('submissions.survey_id = ?', survey_id) if survey_id.present?

    answers
  end

  def filtered_answers(answers, filter)
    case filter
    when /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/ # udid
      answers.where('devices.udid = :search', search: filter)
    when Resolv::IPv4::Regex # ip
      answers.where('submissions.ip_address = :search', search: filter)
    when /\A\d+\Z/ # account id
      answers.where('surveys.account_id = :search', search: filter.to_i)
    else
      answers
    end
  end

  def page
    (params[:start].to_i / per_page) + 1
  end

  def per_page
    params[:length].to_i.zero? ? params[:length].to_i : 100
  end

  def sort_column
    columns[params[:order]['0']['column']]
  end

  def sort_direction
    params[:order]['0']['dir'] == 'desc' ? 'desc' : 'asc'
  end

  def columns
    {
      '0' => 'answers.created_at',
      '1' => 'answers.created_at',
      '2' => 'questions.content',
      '3' => 'possible_answers.content',
      '4' => 'answers.question_id',
      '5' => 'answers.id',
      '6' => 'questions.next_question_id',
      '7' => 'submissions.survey_id',
      '8' => 'submissions.pageview_count',
      '9' => 'submissions.visit_count',
      '10' => 'submissions.ip_address',
      '11' => 'submissions.device_type',
      '12' => 'devices.udid',
      '13' => 'devices.client_key',
      '14' => 'submissions.url',
      '15' => 'submissions.custom_data',
      '16' => 'submissions.user_agent'
    }
  end
end
