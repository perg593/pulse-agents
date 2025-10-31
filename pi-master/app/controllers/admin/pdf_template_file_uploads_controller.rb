# frozen_string_literal: true
require "English"

module Admin
  class PDFTemplateFileUploadsController < BaseController
    before_action :set_pdf_template_file_upload, only: %i(destroy show)
    before_action :set_survey, only: %i(upload)
    before_action :validate_erb, only: %i(upload)

    def show
      s3_object = @pdf_template_file_upload.fetch_object_from_s3

      send_data(
        s3_object.body.read,
        filename: @pdf_template_file_upload.file_name,
        type: s3_object.content_type
      )
    end

    def destroy
      if @pdf_template_file_upload.try(:position)
        if @pdf_template_file_upload.destroy
          survey_metadatum = @pdf_template_file_upload.survey_metadatum

          all_pdf_uploads = survey_metadatum.pdf_template_static_pdfs.sort_by(&:position)
          file_props = all_pdf_uploads.map { |file_upload| PDFTemplatePresenter.file_prop(file_upload) }

          render json: { success: true, files: file_props } and return
        end
      elsif @pdf_template_file_upload.destroy
        render json: { success: true } and return
      end

      render json: { error: @pdf_template_file_upload.errors.full_messages.join(',') }, status: 500
    end

    def upload
      params[:files].each do |file|
        # Instantiate it as its subtype, otherwise we won't have access
        # to the subclasses methods until it's been saved.
        file_upload = file_upload_type(file).new(
          survey_metadatum: @survey.metadatum,
          file_name: file.original_filename,
          tempfile: file.tempfile
        )

        file_upload.save!
      end

      redirect_to pdf_template_admin_surveys_path(survey_id: @survey.id)
    end

    def reorder_static_pdf_files
      files = params[:files]

      pdf_file_upload_records = PDFTemplateFileUploads::PDFTemplateStaticPDF.where(id: files.map { |file| file[:id] })

      survey_metadatum = pdf_file_upload_records.first.survey_metadatum

      # Confirm that they represent all files associated with that survey metadatum
      unless survey_metadatum.pdf_template_static_pdf_ids.sort == pdf_file_upload_records.pluck(:id).sort
        raise "All files must be associated with that survey metadatum"
      end

      if validate_pdf_positions(pdf_file_upload_records.map(&:position))
        # TODO: Optimize
        files.each do |file|
          file_upload = PDFTemplateFileUploads::PDFTemplateStaticPDF.find(file[:id])
          file_upload.position = file[:position]
          file_upload.save
        end

        render json: { success: true }
      else
        render json: { success: false }
      end
    end

    private

    def validate_erb
      return unless tempfile = params[:files].find { |file| file.original_filename.end_with?(".erb") }&.tempfile
      # write a copy of the file as a TempFile in the Rails tmp directory, which is accessible to the pdf_validator user
      local_template_file_path = Rails.root.join("tmp", File.basename(tempfile))
      FileUtils.cp(tempfile&.path, local_template_file_path)
      FileUtils.chmod "a+r", local_template_file_path

      pdf_valid = validate_pdf(local_template_file_path)
      File.delete(local_template_file_path)

      return if pdf_valid

      current_user.lock_access!
      UserMailer.with(user: current_user).suspicious_behaviour_detected(current_user, request.remote_ip).deliver_now
      warden.logout
      redirect_to sign_in_url
    end

    def validate_pdf(template_file_path)
      # Not worried about command injection because
      # template_file_path does not have any user-provided information
      pid = Process.spawn("sudo -u pdf_validator ruby app/lib/pdf_template_validator.rb #{template_file_path}")
      Process.wait(pid)

      exit_status = $CHILD_STATUS.exitstatus

      return exit_status.zero?
    end

    def set_pdf_template_file_upload
      @pdf_template_file_upload = PDFTemplateFileUploads::PDFTemplateFileUpload.find(params[:id])
    end

    def set_survey
      @survey = Survey.find_by(id: params[:survey_id])
    end

    def file_upload_type(file)
      if file.original_filename =~ /(.html.erb)$/
        PDFTemplateFileUploads::PDFTemplateHTMLFile
      elsif file.content_type == "application/pdf"
        PDFTemplateFileUploads::PDFTemplateStaticPDF
      else
        PDFTemplateFileUploads::PDFTemplateAsset
      end
    end

    def validate_pdf_positions(positions)
      # check for 0
      return false if positions.include?(0)

      # means no duplicates
      return false unless (positions - positions.uniq).empty?

      # no gaps
      return false unless positions.select(&:positive?).sort.each_cons(2).all? { |a, b| b == a + 1 }
      return false unless positions.select(&:negative?).sort.each_cons(2).all? { |a, b| b == a + 1 }

      true
    end
  end
end
