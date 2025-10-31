# frozen_string_literal: true
require 'spec_helper'

describe QrveyDashboardMapping do
  describe "validations" do
    subject { described_class.new }

    it { is_expected.to validate_presence_of(:qrvey_name) }
    it { is_expected.to validate_presence_of(:pi_name) }
    it { is_expected.to validate_presence_of(:position) }

    it { is_expected.to validate_uniqueness_of(:qrvey_name) }
    it { is_expected.to validate_uniqueness_of(:pi_name) }
    it { is_expected.to validate_uniqueness_of(:position) }
  end
end
