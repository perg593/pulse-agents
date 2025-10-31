# frozen_string_literal: true

require 'spec_helper'

describe Admin::AccountsHelper do
  describe '#select_tag_options_for_tag_js' do
    it "returns a list of pairs containing the label and the db value for a tag.js version" do
      tag_js_filenames = Dir.children('lib/assets').filter { |filename| filename.match?(/^tag_.+\.js\.erb$/) }
      versions = tag_js_filenames.map { |filename| filename.match(/tag_(.+)\.js\.erb/)[1] }
      options = versions.map { |version| [version, version.dup] }
      options = options.sort.reverse
      options.first.first << ' (Latest)'
      expect(helper.select_tag_options_for_tag_js).to eq options
    end
  end
end
