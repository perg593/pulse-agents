# frozen_string_literal: true

module AIOutlineGeneration
  module DataProviders
    class AIAnalysisProvider < Base
      def call
        analysis_data = {}

        analysis_data.merge!(survey_brief_data)
        analysis_data.merge!(summarization_data)
        analysis_data.merge!(recommendations_data)

        analysis_data
      end

      private

      def survey_brief_data
        brief_jobs = survey.survey_brief_jobs.done.order(created_at: :desc).limit(3)
        return {} unless brief_jobs.any?

        { summary: "Previous AI analysis found: #{brief_jobs.map(&:brief).join('; ')}" }
      end

      def summarization_data
        summarization_jobs = AISummarizationJob.joins(question: :survey).
                             where(surveys: { id: survey.id }).
                             done.
                             order(created_at: :desc).
                             limit(5)

        return {} unless summarization_jobs.any?

        insights = summarization_jobs.map do |job|
          "Question '#{job.question.text}': #{job.summary}"
        end.join("\n")

        { insights: "## Free Text Analysis\n#{insights}" }
      end

      def recommendations_data
        recommendations = survey.survey_recommendations.recent.limit(3)
        return {} unless recommendations.any?

        rec_text = recommendations.map do |rec|
          "- #{rec.content['recommendation'] || rec.content['summary'] || 'Recommendation available'}"
        end.join("\n")

        { recommendations: "## Previous Recommendations\n#{rec_text}" }
      end
    end
  end
end
