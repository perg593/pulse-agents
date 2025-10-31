# frozen_string_literal: true

require 'spec_helper'

describe Rack::PDFResponse do
  let(:pdf_response) { described_class.new(test_pg_connection, answer_params) }

  let(:unescaped_survey_name) { "test/test | 'test' - \"test\"" }
  let(:escaped_survey_name) { URI.encode_www_form_component(unescaped_survey_name.gsub(' ', '_')) }

  let(:survey) do
    s = create(:survey_without_question, name: unescaped_survey_name)
    create(:survey_metadatum, survey: s)

    question = create(:single_choice_question, survey: s, position: 0)
    create(:question_metadatum, question: question)
    question.possible_answers.each { |possible_answer| create(:possible_answer_metadatum, possible_answer: possible_answer) }

    question = create(:multiple_choices_question, survey: s, position: 1)
    create(:question_metadatum, question: question)
    question.possible_answers.each { |possible_answer| create(:possible_answer_metadatum, possible_answer: possible_answer) }

    question = create(:slider_question, survey: s, position: 2)
    create(:question_metadatum, question: question)
    question.possible_answers.each { |possible_answer| create(:possible_answer_metadatum, possible_answer: possible_answer) }

    question = create(:free_text_question, survey: s, position: 3)
    create(:question_metadatum, question: question)

    question = create(:custom_content_question, survey: s, position: 4)
    create(:question_metadatum, question: question)

    s.reload
  end

  let(:answer_params) do
    survey.questions.map do |question|
      question_params = {
        'question_id' => question.id.to_s,
        'question_type' => question.question_type
      }

      if question.single_choice_question? || question.slider_question?
        question_params['answer'] = question.possible_answers.take.id.to_s
      elsif question.multiple_choices_question?
        question_params['answer'] = question.possible_answers.ids.join(',')
      elsif question.free_text_question?
        question_params['answer'] = FFaker::Lorem.sentence
      elsif question.custom_content_question?
        question_params['answer'] = nil
      end

      question_params
    end
  end

  describe "generate" do
    before do
      @stubbed_template = "<html>Hello, world!</html>"

      object_key = "#{FFaker::Lorem.word}/#{FFaker::Lorem.word}.html.erb"
      create(:pdf_template_html_file, survey_metadatum: survey.metadatum, object_key: object_key)

      template_questions = survey.questions.map do |question|
        next if %w(free_text_question custom_content_question).include? question.question_type

        template_possible_answers = question.possible_answers.map do |possible_answer|
          {
            id: possible_answer.id,
            metaname: possible_answer.metadatum.name,
            content: possible_answer.content,
            # rubocop:disable Layout/LineLength
            selected: answer_params.detect { |answer_param| answer_param['question_id'] == question.id.to_s && answer_param['answer'].include?(possible_answer.id.to_s) }.present?
          }
        end

        {
          id: question.id,
          metaname: question.metadatum.name,
          content: question.content,
          type: question.question_type,
          possible_answers: template_possible_answers
        }
      end.compact

      @template_submission = {
        questions: template_questions
      }

      @final_pdf = "%PDF"

      # TODO: Investigate fixtures and feasability of generating PDFs in tests
      # rubocop:disable RSpec/AnyInstance
      allow_any_instance_of(Rack::PdfTemplates::PDFGenerator).to receive(:generate).with(survey.id, @template_submission).and_return(@final_pdf)

      @response = pdf_response.generate
    end

    it "returns 200" do
      expect(@response[0]).to eq 200
    end

    it "returns the expected headers" do
      headers = @response[1]
      expect(headers["Content-Type"]).to eq "application/pdf"
      expect(headers["Access-Control-Allow-Origin"]).to eq("*")
      expect(headers["Access-Control-Expose-Headers"]).to eq("File-Name")
      expect(headers["File-Name"]).to eq("#{escaped_survey_name}.pdf")
    end

    it "returns the mocked pdf" do
      expect(@response[2]).to be_a Array
      expect(@response[2].length).to eq(1)
      expect(@response[2].first).to eq(@final_pdf)
    end

    # TODO: Investigate fixtures and feasability of generating PDFs in tests
    it "uses CombinePDF and HTML to generate the pdf" do
      # expect(CombinePDF).to have_received(:parse).exactly(1).times
    end
  end

  def test_pg_connection
    config = YAML.load_file('config/database.yml', aliases: true)['test']
    PG.connect({
                 dbname: config["database"],
                 user: config["username"],
                 password: config["password"],
                 host: config["rack-host"],
                 port: config["port"]
               })
  end
end
