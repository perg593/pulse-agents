# frozen_string_literal: true

module BundleAudit
  class Result
    attr_reader :title, :url, :description, :gem_name, :our_gem_version, :patched_versions

    def initialize(input_hash)
      @title = input_hash["advisory"]["title"]
      @url = input_hash["advisory"]["url"]
      @description = input_hash["advisory"]["description"]
      @gem_name = input_hash["gem"]["name"]
      @our_gem_version = input_hash["gem"]["version"]
      @patched_versions = input_hash["advisory"]["patched_versions"].join(",")
    end
  end
end

# Real-world example of input_hash:
#
# rubocop:disable Layout/LineLength
# {"type"=>"unpatched_gem",
#   "gem"=>{"name"=>"rails-html-sanitizer", "version"=>"1.4.2"},
#   "advisory"=>
#    {"path"=>"/Users/thunderdog/.local/share/ruby-advisory-db/gems/rails-html-sanitizer/CVE-2022-32209.yml",
#     "id"=>"CVE-2022-32209",
#     "url"=>"https://groups.google.com/g/rubyonrails-security/c/ce9PhUANQ6s",
#     "title"=>"Possible XSS vulnerability with certain configurations of Rails::Html::Sanitizer",
#     "date"=>"2022-06-10",
#     "description"=>
#      "There is a possible XSS vulnerability with certain configurations of Rails::Html::Sanitizer.\nThis vulnerability has been assigned the CVE identifier CVE-2022-32209.\n\nVersions Affected: ALL\nNot affected: NONE\nFixed Versions: v1.4.3\n\n## Impact\n\nA possible XSS vulnerability with certain configurations of\nRails::Html::Sanitizer may allow an attacker to inject content if the\napplication developer has overridden the sanitizer's allowed tags to allow\nboth `select` and `style` elements.\n\nCode is only impacted if allowed tags are being overridden. This may be done via application configuration:\n\n```ruby\n# In config/application.rb\nconfig.action_view.sanitized_allowed_tags = [\"select\", \"style\"]\n```\n\nsee https://guides.rubyonrails.org/configuring.html#configuring-action-view\n\nOr it may be done with a `:tags` option to the Action View helper `sanitize`:\n\n```\n<%= sanitize @comment.body, tags: [\"select\", \"style\"] %>\n```\n\nsee https://api.rubyonrails.org/classes/ActionView/Helpers/SanitizeHelper.html#method-i-sanitize\n\nOr it may be done with Rails::Html::SafeListSanitizer directly:\n\n```ruby\n# class-level option\nRails::Html::SafeListSanitizer.allowed_tags = [\"select\", \"style\"]\n```\n\nor\n\n```ruby\n# instance-level option\nRails::Html::SafeListSanitizer.new.sanitize(@article.body, tags: [\"select\", \"style\"])\n```\n\nAll users overriding the allowed tags by any of the above mechanisms to include both \"select\" and \"style\" should either upgrade or use one of the workarounds immediately.\n\n## Releases\n\nThe FIXED releases are available at the normal locations.\n\n## Workarounds\n\nRemove either `select` or `style` from the overridden allowed tags.\n\n## Credits\n\nThis vulnerability was responsibly reported by [windshock](https://hackerone.com/windshock?type=user).\n",
#     "cvss_v2"=>nil,
#     "cvss_v3"=>nil,
#     "cve"=>"2022-32209",
#     "osvdb"=>nil,
#     "ghsa"=>nil,
#     "unaffected_versions"=>[],
#     "patched_versions"=>[">= 1.4.3"]}}
