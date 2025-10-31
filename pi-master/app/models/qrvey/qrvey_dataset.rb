# frozen_string_literal: true
require_relative "../../../lib/qrvey_client/qrvey_client"

#------------------------------------------------------------------------------
# Basically a cache to cut down on Qrvey API calls. Stores frequently-used
# dataset values.
#------------------------------------------------------------------------------
class QrveyDataset < ActiveRecord::Base
  audited

  belongs_to :qrvey_application

  validates_uniqueness_of :qrvey_survey_id_column_id, scope: :qrvey_dataset_id

  def self.fetch_datasets(qrvey_user, qrvey_application, force: false)
    pre_existing_datasets = where(qrvey_application: qrvey_application)

    if force
      pre_existing_datasets.destroy_all
    elsif pre_existing_datasets.exists?
      return
    end

    dataset_lookup_information = QrveyClient.get_all_datasets(qrvey_user.qrvey_user_id, qrvey_application.qrvey_application_id)
    dataset_ids = dataset_lookup_information["Items"].map { |item| item["datasetId"] }

    dataset_ids.each do |dataset_id|
      dataset = QrveyClient.get_dataset(qrvey_user.qrvey_user_id, qrvey_application.qrvey_application_id, dataset_id)
      survey_id_column_id = dataset["columns"].detect { |column| column["origColumnSourceName"] == "survey_id" }["columnId"]

      create(qrvey_application: qrvey_application, qrvey_dataset_id: dataset_id, qrvey_survey_id_column_id: survey_id_column_id)
    end
  end
end

# == Schema Information
#
# Table name: qrvey_datasets
#
#  id                        :bigint           not null, primary key
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  qrvey_application_id      :bigint
#  qrvey_dataset_id          :string
#  qrvey_survey_id_column_id :string
#
# Indexes
#
#  index_q_datasets_on_q_dataset_id_and_q_survey_id_column_id  (qrvey_dataset_id,qrvey_survey_id_column_id) UNIQUE
#  index_qrvey_datasets_on_qrvey_application_id                (qrvey_application_id)
#
