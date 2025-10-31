# frozen_string_literal: true

RSpec.shared_examples "trend report colors" do
  it 'loops through the colour palette when it has exhausted all colours' do
    (described_class::COLOR_PALETTE.size * 3).times { |_| create_possible_answer_with_answer }

    presenter = described_class.new(@survey, survey_locale_group: @survey.survey_locale_group, current_user: @current_user)
    trend_report_params = presenter.trend_report_params

    data_series = trend_report_params[:questions][@question.id][:seriesData]
    colors = data_series.map { |datum| datum[:color] }

    expect(colors).to match_array(described_class::COLOR_PALETTE * 3)
  end

  it 'returns user-specified colours when available' do
    described_class::COLOR_PALETTE.count.times { |_| create_possible_answer_with_answer }

    first_possible_answer = @question.possible_answers.first
    colored_record = @survey.localized? ? first_possible_answer.possible_answer_locale_group : first_possible_answer

    custom_color = "#00f"
    colored_record.update(report_color: custom_color)

    presenter = described_class.new(@survey, survey_locale_group: @survey.survey_locale_group, current_user: @current_user)

    trend_report_params = presenter.trend_report_params

    data_series = trend_report_params[:questions][@question.id][:seriesData]

    expect(data_series.map { |series| series[:id] }.include?(colored_record.id)).to be true

    data_series.each do |data|
      if data[:id] == colored_record.id
        expect(data[:color]).to eq(custom_color)
      else
        expect(described_class::COLOR_PALETTE.include?(data[:color])).to be(true)
      end
    end
  end

  it 'returns the same colours as report_component_params' do
    described_class::COLOR_PALETTE.count.times { |_| create_possible_answer_with_answer }

    presenter = described_class.new(@survey, survey_locale_group: @survey.survey_locale_group, current_user: @current_user)
    trend_report_params = presenter.trend_report_params

    @survey.questions.each do |question|
      data_series = trend_report_params[:questions][question.id][:seriesData]

      color_by_possible_answer = {}

      data_series.each do |data|
        color_by_possible_answer[data[:id]] = data[:color]
      end

      presenter.report_component_params[:data].each do |datum|
        next unless datum[:question][:id] == question.id

        datum[:possibleAnswers].each do |possible_answer_data|
          expect(possible_answer_data[:color]).to eq(color_by_possible_answer[possible_answer_data[:id]])
        end
      end
    end
  end

  def create_possible_answer_with_answer
    possible_answer = create(:possible_answer, question: @question)

    if @survey.localized?
      possible_answer_locale_group = create(:possible_answer_locale_group, question_locale_group: @question.question_locale_group)
      possible_answer.update(possible_answer_locale_group: possible_answer_locale_group)
    end

    submission = create(:submission, survey_id: @question.survey_id)
    create(:answer, question_id: @question.id, submission_id: submission.id, possible_answer_id: possible_answer.id)
  end
end
