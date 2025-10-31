# frozen_string_literal: true
require "spec_helper"

describe Trigger do
  describe "validations" do
    allowed_values= %w(
      RegexpTrigger UrlTrigger PageviewTrigger VisitTrigger PreviousAnswerTrigger
      MobilePageviewTrigger MobileRegexpTrigger MobileLaunchTrigger MobileInstallTrigger
      PageAfterSecondsTrigger PageScrollTrigger PageElementVisibleTrigger PageElementClickedTrigger
      PageIntentExitTrigger TextOnPageTrigger GeoTrigger ClientKeyTrigger UrlMatchesTrigger
      PseudoEventTrigger DeviceDataTrigger
    )

    subject { described_class.new(survey: create(:survey)) }

    it { is_expected.to validate_inclusion_of(:type_cd).in_array(allowed_values).with_message("type_cd must be one of #{allowed_values}") }
  end
end
