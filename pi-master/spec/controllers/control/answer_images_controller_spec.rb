# frozen_string_literal: true
require 'spec_helper'

describe Control::AnswerImagesController do
  before do
    Account.delete_all
    User.delete_all
    AnswerImage.delete_all
    Invitation.delete_all
  end

  let(:valid_params) { { answer_image: { image: 'foo' } } }

  describe "POST #create" do
    before do
      @old_answer_image_count = AnswerImage.count
    end

    it "is not possible without logging in" do
      post :create, params: valid_params

      expect(response).to have_http_status(:found)
      expect(AnswerImage.count).to eq @old_answer_image_count
    end

    it "is available to reporting level users" do
      user = create(:reporting_only_user)
      sign_in user

      post :create, params: valid_params

      it_succeeds_with_json_response
    end

    it "is available to full access users" do
      user = create(:user)
      sign_in user

      post :create, params: valid_params

      it_succeeds_with_json_response
    end

    it 'creates an answer_image for the account the user is logged in with' do
      user = create(:user)
      sign_in user

      post :create, params: valid_params

      it_succeeds_with_json_response

      expect(json_response).to eq({ "answerImage" => {"id" => AnswerImage.last.id, "url" => nil} })
      expect(AnswerImage.count).to eq @old_answer_image_count + 1
      expect(AnswerImage.last.imageable_id).to eq user.account.id
    end

    describe 'SVG sanitization' do
      before do
        AnswerImageUploader.enable_processing = true # https://github.com/carrierwaveuploader/carrierwave#testing-with-carrierwave

        sign_in create(:user)
      end

      after do
        AnswerImageUploader.enable_processing = false # https://github.com/carrierwaveuploader/carrierwave#testing-with-carrierwave
      end

      it 'removes script tags while keeping other tags' do
        svg_file = Tempfile.new %w(malicious .svg) # Passing an array so a hash will be appended before '.svg'
        svg_file.write <<-SVG # Taken from https://app.cobalt.io/pulse-insights/pulse-insights-pt9084/findings/12
          <?xml version="1.0" standalone="no"?>
          <!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
          <svg version="1.1" baseProfile="full" xmlns="http://www.w3.org/2000/svg">
            <polygon id="triangle" points="0,0 0,50 50,0" fill="#009900" stroke="#004400"/>
            <script type="text/javascript"> alert(document.cookie); </script>
          </svg>
        SVG
        svg_file.rewind # Resetting the line number to 0 so 'svg_file.read' will be able to show the entire content

        expect(AnswerImage.count).to eq 0
        post :create, params: { answer_image: { image: Rack::Test::UploadedFile.new(svg_file, "image/svg") } }
        expect(AnswerImage.count).to eq 1

        sanitized_svg = AnswerImage.first.image.file.read
        expect(sanitized_svg).not_to include '<script'
        expect(sanitized_svg).to include '<svg'
        expect(sanitized_svg).to include '<?xml'
      end

      describe 'File type' do
        before do
          file.write file_content
          file.rewind
          post :create, params: { answer_image: { image: Rack::Test::UploadedFile.new(file, file_type) } }
        end

        context 'when it masquerades as another file type' do
          let(:file) { Tempfile.new %w(masquerade .png) }
          let(:file_type) { 'image/png' }
          let(:file_content) { "<html><svg/onload=alert('n00b')></html>" }

          it 'removes script tags' do
            expect(AnswerImage.first.image.file.read).not_to include 'alert'
          end
        end

        context 'when it is indeed a different type of file' do
          let(:file) { Tempfile.new(%w(innocent .png), binmode: true) }
          let(:file_type) { 'image/png' }
          let(:file_content) { 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABAQAAAAA3bvkkAAAACklEQVR4AWNgAAAAAgABc3UBGAAAAABJRU5ErkJggg==' }

          it 'does not change the content' do
            expect(file.read).to eq AnswerImage.first.image.file.read
          end
        end
      end
    end
  end
end
