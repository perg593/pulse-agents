# frozen_string_literal: true

# https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-keys.html
RSpec.shared_examples "s3 object key validation" do
  # The model attribute to validate
  def attribute_to_validate
    raise NotImplementedError, "You must implement 'attribute_to_validate' to use 's3 object key validation'"
  end

  it "accepts valid s3 object key characters" do
    subject[attribute_to_validate] = "A-fine-and_good_name"

    expect(subject.valid?).to be true
  end

  it "rejects invalid s3 object key characters" do
    # Technically forward slash "/" is discouraged too, but that's only an issue
    # if we start putting object keys in URLs. "/" is used as a pseudo directory separator
    # in S3, so it seems fine to include it generally.
    bad_values = [
      "\\", "{", "^", "}", "%", "`", "]", "\"", ">", "[", "~", "<", "#", "|",
      "&", "$", "@", "=", ";", ":", "+", " ", ",", "?"
    ]

    bad_values.each do |bad_value|
      subject[attribute_to_validate] = "a#{bad_value}"

      expect(subject.valid?).to be(false), "'#{bad_value}' should be invalid"
    end
  end
end
