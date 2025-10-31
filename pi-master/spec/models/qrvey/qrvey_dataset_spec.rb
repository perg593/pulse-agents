# frozen_string_literal: true
require 'spec_helper'

describe QrveyDataset do
  describe "Associations" do
    it { is_expected.to belong_to(:qrvey_application) }
  end

  describe "Validations" do
    it { is_expected.to validate_uniqueness_of(:qrvey_survey_id_column_id).scoped_to(:qrvey_dataset_id) }
  end

  describe "#fetch_datasets" do
    let(:stub_qrvey_datasets) do
      3.times.map do |_|
        {
          "datasetId" => FFaker::Lorem.unique.word
        }
      end
    end

    let(:stub_qrvey_columns_for_dataset) do
      columns = {}

      stub_qrvey_datasets.each do |stub_qrvey_dataset|
        columns[stub_qrvey_dataset["datasetId"]] = {
          "origColumnSourceName" => "survey_id",
          "columnId" => FFaker::Lorem.unique.word
        }
      end

      columns
    end

    before do
      @qrvey_user = create(:qrvey_user, account: create(:account))
      @qrvey_application = create(:qrvey_application, qrvey_user: @qrvey_user)

      allow(QrveyClient).to receive(:get_all_datasets).
        with(@qrvey_user.qrvey_user_id, @qrvey_application.qrvey_application_id).
        and_return({"Items" => stub_qrvey_datasets})

      stub_qrvey_datasets.each do |stub_qrvey_dataset|
        dataset_id = stub_qrvey_dataset["datasetId"]

        allow(QrveyClient).to receive(:get_dataset).
          with(@qrvey_user.qrvey_user_id, @qrvey_application.qrvey_application_id, dataset_id).
          and_return({"columns" => [stub_qrvey_columns_for_dataset[dataset_id]]})
      end

      described_class.fetch_datasets(@qrvey_user, @qrvey_application)
    end

    it "creates dataset records" do
      expect(described_class.count).to be stub_qrvey_datasets.count

      stub_qrvey_columns_for_dataset.each do |dataset_id, stub_qrvey_column|
        dataset = described_class.find_by(qrvey_application: @qrvey_application,
                                          qrvey_dataset_id: dataset_id,
                                          qrvey_survey_id_column_id: stub_qrvey_column["columnId"])

        expect(dataset).not_to be_nil
      end
    end

    context "when run again" do
      it "does not request new records" do
        expect(QrveyClient).not_to receive(:get_dataset)
        expect(QrveyClient).not_to receive(:get_all_datasets)

        described_class.fetch_datasets(@qrvey_user, @qrvey_application)
      end
    end

    context "when run with force = true" do
      it "requests new records" do
        expect(QrveyClient).to receive(:get_dataset)
        expect(QrveyClient).to receive(:get_all_datasets)

        described_class.fetch_datasets(@qrvey_user, @qrvey_application, force: true)
      end

      it "deletes old records" do
        @old_record_ids = described_class.all.pluck(:id)

        described_class.fetch_datasets(@qrvey_user, @qrvey_application, force: true)

        expect(described_class.where(id: @old_record_ids)).not_to be_present
      end

      it "creates new records" do
        described_class.fetch_datasets(@qrvey_user, @qrvey_application, force: true)

        expect(described_class.count).to be stub_qrvey_datasets.count
      end
    end
  end
end
