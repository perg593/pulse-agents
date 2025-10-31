# frozen_string_literal: true

module Rack
  module PdfTemplates
    class TemplateRenderer
      def initialize(template_file, css_files: [], image_files: [], font_files: [], answer_info: nil)
        @template_file = template_file
        @css_files = css_files
        @image_files = image_files
        @font_files = font_files
        @answer_info = answer_info
      end

      def render_template
        template_context = TemplateContext.new(css_files: @css_files, image_files: @image_files, font_files: @font_files, answer_info: @answer_info)

        ::ERB.new(@template_file.read).result(template_context.get_binding)
      end

      class TemplateContext
        BLACKLISTED_FUNCTIONS = Kernel.methods + [:alias_method]
        WHITELISTED_FUNCTIONS = [
          :raise, # need this to raise errors
          :binding, # need this to adjust our binding
          :send, # "may cause serious problems if redefined"
          :__send__, # "may cause serious problems if redefined"
          :object_id, # "may cause serious problems if redefined"
          :const_defined?
        ].freeze

        attr_reader :answer_info

        # We want to override Ruby's File module, but File in this context refers
        # to Rack::File, which we don't want to touch. This proxy allows us to
        # override ::File without affecting code outside the TemplateContext instance
        class FileProxy
          def initialize
            @file = ::File
          end

          def method_missing(_name, *_args, &_block)
            raise SecurityError, "Call to File method detected"
          end

          def respond_to_missing?
            false
          end
        end

        def initialize(css_files: [], image_files: [], font_files: @font_files, answer_info: nil)
          @css_files = css_files
          @image_files = image_files
          @answer_info = answer_info
          @font_files = font_files

          @file_proxy = FileProxy.new

          @binding = binding
          secure_binding!
        end

        # rubocop:disable Naming/AccessorMethodName
        # The official docs use get_binding, so I feel like we have permission
        def get_binding
          @binding
        end

        def font_url(font_file_identifier)
          font_file = @font_files.find { |file| ::File.basename(file) == font_file_identifier }

          raise ArgumentError, "Font file '#{font_file_identifier}' not found" if font_file.nil?

          "url(\"file://#{font_file.path}\")"
        end

        def style_tag(css_file_identifier)
          css_file = @css_files.find { |file| ::File.basename(file) == css_file_identifier }

          raise ArgumentError, "CSS file '#{css_file_identifier}' not found" if css_file.nil?

          "<style>#{css_file.read}</style>"
        end

        def image_tag(image_file_identifier)
          image_file = @image_files.find { |file| ::File.basename(file) == image_file_identifier }

          raise ArgumentError, "Image file '#{image_file_identifier} not found" if image_file.nil?

          # Can't use Rails.root in Rack app
          <<~HTML
            <img src='file://#{image_file.path}'>
          HTML
        end

        private

        def secure_binding!
          overwrite_tempfile!
          overwrite_process!
          overwrite_file!
          overwrite_socket!
          overwrite_open3!
          overwrite_pty!
          overwrite_kernel!
          overwrite_io!

          (BLACKLISTED_FUNCTIONS - WHITELISTED_FUNCTIONS).each do |func|
            overwrite_function!(func)
          end
        end

        def overwrite_tempfile!
          overwrite_class!("Tempfile", %w(method_missing new))
        end

        def overwrite_process!
          overwrite_class!("Process", ["method_missing"])
        end

        def overwrite_file!
          @binding.eval <<~RUBY
            File = @file_proxy
          RUBY
        end

        def overwrite_socket!
          overwrite_class!("Socket", ["new"])
        end

        def overwrite_open3!
          overwrite_class!("Open3", ["method_missing"])
        end

        def overwrite_pty!
          overwrite_class!("PTY", ["method_missing"])
        end

        def overwrite_kernel!
          overwrite_class!("Kernel", ["method_missing"])
        end

        def overwrite_io!
          overwrite_class!("IO", %w(new open popen))
        end

        def overwrite_class!(class_name, class_method_names)
          # rubocop:disable Style/DocumentDynamicEvalDefinition
          # I don't now how to satisfy Rubocop
          # def class_name
          #   def self.func(*args, &block)
          #     raise SecurityError, 'Call to blacklisted function func detected'
          #   end
          # end
          @binding.eval <<~RUBY
            class #{class_name}
              #{
                class_method_names.map do |class_method_name|
                  <<~RUBY
                    def self.#{class_method_name}(*args, &block)
                      raise SecurityError, 'Call to #{class_name} method detected'
                    end
                  RUBY
                end.join("\n")
              }
            end
          RUBY
        end

        def overwrite_function!(func)
          # def func(*args, &block)
          #   raise SecurityError, 'Call to blacklisted function func detected'
          # end
          @binding.eval <<~RUBY
            def #{func}(*args, &block)
              raise SecurityError, 'Call to blacklisted function #{func} detected'
            end
          RUBY
        end
      end
    end
  end
end
