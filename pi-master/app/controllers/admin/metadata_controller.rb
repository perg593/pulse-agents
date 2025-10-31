# frozen_string_literal: true

module Admin
  class MetadataController < ApplicationController
    def create
      type = {
        "survey" => Metadata::SurveyMetadatum,
        "question" => Metadata::QuestionMetadatum,
        "possible_answer" => Metadata::PossibleAnswerMetadatum
      }[params[:type]]

      metadatum = Metadata::Metadatum.new(name: params[:name], type: type, owner_record_id: params[:owner_record_id])

      if metadatum.save
        render json: metadatum_json(metadatum)
      else
        render json: { error: metadatum.errors.full_messages.join(',') }, status: 500
      end
    end

    def update
      metadatum = Metadata::Metadatum.find(params[:id])

      if metadatum.update(metadatum_params)
        render json: metadatum_json(metadatum)
      else
        render json: { error: metadatum.errors.full_messages.join(',') }, status: 500
      end
    end

    def destroy
      metadatum = Metadata::Metadatum.find(params[:id])
      response_json = metadatum_json(metadatum)

      if metadatum.destroy
        render json: response_json
      else
        render json: { error: metadatum.errors.full_messages.join(',') }, status: 500
      end
    end

    private

    def metadatum_params
      params.require(:metadatum).permit(:name)
    end

    def metadatum_json(metadatum)
      {
        id: metadatum.id,
        name: metadatum.name
      }
    end
  end
end
