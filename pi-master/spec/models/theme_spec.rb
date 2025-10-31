# frozen_string_literal: true
require 'spec_helper'

describe Theme do
  describe "validations" do
    describe "name" do
      subject { described_class.new }

      it { is_expected.to validate_presence_of(:name) }
    end
  end
end
