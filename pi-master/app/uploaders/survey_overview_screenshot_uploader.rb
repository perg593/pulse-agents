# frozen_string_literal: true

class SurveyOverviewScreenshotUploader < CarrierWave::Uploader::Base
  # Include RMagick or MiniMagick support:
  include CarrierWave::MiniMagick

  # Choose what kind of storage to use for this uploader:
  storage :fog

  # We don't want these publicly accessible from the CDN
  def fog_public
    false
  end

  # Override the directory where uploaded files will be stored.
  def store_dir
    "survey_overview_documents/#{Rails.env}/#{model.id}"
  end

  # Add a white list of extensions which are allowed to be uploaded.
  def extension_allowlist
    %w(jpg jpeg gif png)
  end
end
