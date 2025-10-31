# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../rack/pdf_templates/template_renderer'

describe Rack::PdfTemplates::TemplateRenderer do
  describe "#render_template" do
    let(:template_file) do
      template_file = Tempfile.new("test.html.erb")
      template_file.write(html_erb_string)
      template_file.rewind

      template_file
    end

    after do
      template_file.close
      template_file.unlink
    end

    context "when called with an html.erb file" do
      let(:renderer) { described_class.new(template_file) }
      let(:html_erb_string) { "<html>Hello, World!</html>" }

      it "returns a rendered version (string)" do
        rendered_template = renderer.render_template

        expect(rendered_template).to eq html_erb_string
      end
    end

    describe "security" do
      let(:renderer) { described_class.new(template_file) }

      describe "dangerous methods" do
        # This is not an exhaustive list, just the low hanging fruit
        [
          "`ls`", # backticks, command output expression, runs in subshell
          "%x {ls}", # alias of command output expression
          "send('`', 'ls')", # another way to send arbitrary commands to objects
          # "a = 'foo'; a.send('`', 'ls')", # another way to send arbitrary commands to objects. Tough to prevent
          "system('ls')", # executes command in subshell
          "fork", # No subprocesses
          "alias_method :malicious, :eval", # No copying methods
          # "alias malicious eval", # No copying methods. This one's tough because it's a Ruby keyword.
          "require 'pty'" # Loads arbitrary external code
        ].each do |command|
          context "when passed #{command}" do
            let(:html_erb_string) { "<html><%= #{command} %></html>" }

            it "raises an error" do
              expect { renderer.render_template }.to raise_error(SecurityError, /Call to blacklisted function .* detected/)
            end
          end
        end

        describe "Kernel" do
          [
            "Kernel::`('ls')" # backticks, command output expression, runs in subshell
          ].each do |command|
            context "when passed #{command}" do
              let(:html_erb_string) { "<html><%= #{command} %></html>" }

              it "raises an error" do
                expect { renderer.render_template }.to raise_error(SecurityError, "Call to Kernel method detected")
              end
            end
          end
        end

        describe "Tempfile" do
          [
            "Tempfile.new('malicious.exe')", # Prevent Tempfile creation
            "Tempfile.create('malicious.exe', '/tmp')" # Prevent Tempfile creation
          ].each do |command|
            context "when passed #{command}" do
              let(:html_erb_string) { "<html><%= #{command} %></html>" }

              it "raises an error" do
                expect { renderer.render_template }.to raise_error(SecurityError, "Call to Tempfile method detected")
              end
            end
          end
        end

        describe "Process" do
          [
            "Process.pid" # No subprocesses
          ].each do |command|
            context "when passed #{command}" do
              let(:html_erb_string) { "<html><%= #{command} %></html>" }

              it "raises an error" do
                expect { renderer.render_template }.to raise_error(SecurityError, "Call to Process method detected")
              end
            end
          end
        end

        describe "File" do
          [
            "File.delete('important_file_path')", # Don't let them delete files
            "File.new('malicious.exe')" # Don't let them write to disk
          ].each do |command|
            context "when passed #{command}" do
              let(:html_erb_string) { "<html><%= #{command} %></html>" }

              it "raises an error" do
                expect { renderer.render_template }.to raise_error(SecurityError, "Call to File method detected")
              end
            end
          end
        end

        describe "IO" do
          [
            "IO.new(42)", # No IO
            "IO.open(42)", # No IO
            "IO.popen(42)" # No IO
          ].each do |command|
            context "when passed #{command}" do
              let(:html_erb_string) { "<html><%= #{command} %></html>" }

              it "raises an error" do
                expect { renderer.render_template }.to raise_error(SecurityError, "Call to IO method detected")
              end
            end
          end
        end

        describe "Socket" do
          [
            "Socket.new(:INET, :STREAM)" # No sockets
          ].each do |command|
            context "when passed #{command}" do
              let(:html_erb_string) { "<html><%= #{command} %></html>" }

              it "raises an error" do
                expect { renderer.render_template }.to raise_error(SecurityError, "Call to Socket method detected")
              end
            end
          end
        end

        describe "Open3" do
          [
            "Open3.popen3('echo abc')" # No subprocesses
          ].each do |command|
            context "when passed #{command}" do
              let(:html_erb_string) { "<html><%= #{command} %></html>" }

              it "raises an error" do
                expect { renderer.render_template }.to raise_error(SecurityError, "Call to Open3 method detected")
              end
            end
          end
        end

        describe "PTY" do
          [
            "PTY.open" # No new terminals
          ].each do |command|
            context "when passed #{command}" do
              let(:html_erb_string) { "<html><%= #{command} %></html>" }

              it "raises an error" do
                expect { renderer.render_template }.to raise_error(SecurityError, "Call to PTY method detected")
              end
            end
          end
        end
      end
    end

    describe "bindings" do
      # style_tag takes a filename
      # it loads the styles contained in that file and renders them in the HTML
      describe "style_tag" do
        def create_css_file
          Tempfile.new
        end

        after do
          @css_files&.each(&:close)
          @css_files&.each(&:unlink)
        end

        context "when supplied the name of a CSS file" do
          let(:css_string) { "body { background-color: blue; }" }
          let(:css_filename) { File.basename(@css_file.path) }
          let(:html_erb_string) { "<html><%= style_tag('#{css_filename}') %></html>" }

          before do
            @css_file = create_css_file
            @css_file.write(css_string)
            @css_file.rewind

            other_css_file = create_css_file

            @css_files = [other_css_file, @css_file]
          end

          it "returns a rendered version (string)" do
            renderer = described_class.new(template_file, css_files: @css_files)
            rendered_template = renderer.render_template

            expect(rendered_template).to eq "<html><style>#{css_string}</style></html>"
          end
        end

        context "when there is no corresponding css file" do
          let(:html_erb_string) { "<html><%= style_tag('not_found') %></html>" }

          it "raises an error" do
            renderer = described_class.new(template_file)

            expect { renderer.render_template }.to raise_error ArgumentError
          end
        end
      end
    end

    describe "image_tag" do
      def create_image_file
        Tempfile.new
      end

      after do
        @image_files&.each(&:close)
        @image_files&.each(&:unlink)
      end

      context "when supplied the name of an image file" do
        let(:image_filename) { File.basename(@image_file.path) }
        let(:html_erb_string) { "<html><%= image_tag('#{image_filename}') %></html>" }
        let(:image_string) { "IMAGE_DATA" }

        before do
          @image_file = create_image_file
          @image_file.write(image_string)
          @image_file.rewind

          other_image_file = create_image_file

          @image_files = [other_image_file, @image_file]
        end

        it "injects an image tag" do
          renderer = described_class.new(template_file, image_files: @image_files)
          rendered_template = renderer.render_template

          expected_image_tag = <<~HTML
            <img src='file://#{@image_file.path}'>
          HTML

          expect(rendered_template).to eq "<html>#{expected_image_tag}</html>"
        end
      end

      context "when there is no corresponding image file" do
        let(:html_erb_string) { "<html><%= image_tag('not_found') %></html>" }

        it "raises an error" do
          renderer = described_class.new(template_file)

          expect { renderer.render_template }.to raise_error ArgumentError
        end
      end
    end

    describe "font_url" do
      def create_font_file
        Tempfile.new
      end

      after do
        @font_files&.each(&:close)
        @font_files&.each(&:unlink)
      end

      context "when supplied the name of a font file" do
        let(:font_filename) { File.basename(@font_file.path) }
        let(:html_erb_string) do
          <<~HTML
            <html>
              <style>
                @font-face {
                  font-family: "Tsukimi"
                  src: <%= font_url('#{font_filename}') %>
                }
              </style>
            </html>
          HTML
        end

        let(:font_string) { "font_DATA" }

        before do
          @font_file = create_font_file
          @font_file.write(font_string)
          @font_file.rewind

          other_font_file = create_font_file

          @font_files = [other_font_file, @font_file]
        end

        it "injects the font file's absolute path" do
          renderer = described_class.new(template_file, font_files: @font_files)
          rendered_template = renderer.render_template

          expected_html = <<~HTML
            <html>
              <style>
                @font-face {
                  font-family: "Tsukimi"
                  src: url("file://#{@font_file.path}")
                }
              </style>
            </html>
          HTML

          expect(rendered_template).to eq expected_html
        end
      end

      context "when there is no corresponding font file" do
        let(:html_erb_string) { "<html><%= font_url('not_found') %></html>" }

        it "raises an error" do
          renderer = described_class.new(template_file)

          expect { renderer.render_template }.to raise_error ArgumentError
        end
      end
    end

    describe "answer_info" do
      let(:html_erb_string) do
        <<~HTML
          <html>
            <%= answer_info.inspect %>
          </html>
        HTML
      end

      it "returns provided answer info object" do
        # answer_info can be any arbitrary object
        answer_info = {
          questions: [
            {
              content: "question 1",
              type: "single_choice_question",
              possible_answers: [
                { content: "answer 1", selected: true },
                { content: "answer 2", selected: false }
              ]
            }
          ]
        }

        renderer = described_class.new(template_file, answer_info: answer_info)
        rendered_template = renderer.render_template

        expected_html = <<~HTML
          <html>
            #{answer_info.inspect}
          </html>
        HTML

        expect(rendered_template).to eq expected_html
      end
    end
  end
end
