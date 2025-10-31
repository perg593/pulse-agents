# frozen_string_literal: true
class UploadsController < ApplicationController
  def create
    @file = params[:file].tempfile
    s3 = Aws::S3::Resource.new(region: 'us-west-2')
    @random = SecureRandom.hex
    obj = s3.bucket('pi-custom-content').object("#{@random}.jpg")
    obj.upload_file @file.path, acl: 'public-read'

    respond_to do |format|
      format.json { render json: { status: :ok, image: cdn_url } }
    end
  end

  private

  def cdn_url
    "http://cdn.pulseinsights.com/#{@random}.jpg"
  end
end
