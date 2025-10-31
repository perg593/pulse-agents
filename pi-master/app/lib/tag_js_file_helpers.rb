# frozen_string_literal: true

module TagJsFileHelpers
  def self.tag_js(version_number)
    File.read(Rails.root.join("lib", "assets", "tag_#{version_number}.js.erb"))
  end

  def self.tag_js_versions
    Dir.children(Rails.root.join("lib", "assets")).filter_map do |filename|
      filename.scan(/tag_(.+)\.js\.erb/)
    end.flatten
  end
end
