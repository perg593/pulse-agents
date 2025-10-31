# frozen_string_literal: true

RSpec.shared_examples "color validation" do
  # The model attribute to validate
  def attribute_to_validate
    raise NotImplementedError, "You must implement 'attribute_to_validate' to use 'color validation'"
  end

  it "accepts valid rgb hex colours" do
    good_values = %w(#000 #ffffff #BBB)
    good_values.each do |good_value|
      subject[attribute_to_validate] = good_value
      expect(subject.valid?).to be true
    end
  end

  it "rejects invalid rgb hex colours" do
    bad_values = %w(000 #fffffff #xyz)
    bad_values.each do |bad_value|
      subject[attribute_to_validate] = bad_value
      expect(subject.valid?).to be false
    end
  end
end
