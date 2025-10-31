# frozen_string_literal: true
require 'spec_helper'

describe Device do
  it "is able to create a device" do
    described_class.create(udid: '00000000-0000-4000-f000-000000000000')
  end

  it "validates the udid presence and correct length" do
    device = described_class.new
    expect(device).not_to be_valid
    expect(device.errors[:udid]).to eq(["can't be blank", "is too short (minimum is 36 characters)"])
  end

  describe 'validates udid: true' do
    context 'when udid is valid' do
      it 'creates a device' do
        device = described_class.new(udid: 'c054eeeb-3e3f-4e01-a063-879b9460b739')
        expect(device).to be_valid
      end
    end

    context 'when udid is invalid' do
      it 'adds error to instance' do
        udid = 'c054eeeb-3e3f-4e01-a063-%%%%%%%%%%%%'
        device = described_class.new(udid: udid)

        expect(device).not_to be_valid
        expect(device.errors[:udid]).to eq(["Invalid UDID: #{udid}"])
      end
    end

    describe 'capped letters are valid' do
      it 'creates a device' do
        device = described_class.new(udid: 'C054EEEB-3E3F-4E01-A063-879B9460B739')
        expect(device).to be_valid
      end
    end
  end

  describe "#eligible_for_refire_for_survey?" do
    subject { device.eligible_for_refire_for_survey?(survey) }

    let(:device) { create(:device) }
    let(:survey) { create(:survey) }

    context "when survey refire period is not active" do
      it { is_expected.to be false }
    end

    context "when survey refire period is active" do
      before do
        survey.update(
          refire_enabled: true,
          refire_time_period: "hours",
          refire_time: 1
        )
      end

      context "when the device's last submissions created_at plus the refire period is before now" do
        before do
          create(:submission, device: device, survey: survey, created_at: 61.minutes.ago)
        end

        it { is_expected.to be true }
      end

      context "when the device's last submissions created_at plus the refire period is after now" do
        before do
          create(:submission, device: device, survey: survey, created_at: 59.minutes.ago)
        end

        it { is_expected.to be false }
      end
    end
  end
end
