# frozen_string_literal: true
module Admin
  module AccountsHelper
    def infos_for_account(account)
      output = ""
      if account.company_name.present?
        output += (account.template_account? ? "<span class='text-warning'><strong>#{account.company_name}</strong></span>" : truncate(account.company_name))
      end
      if account.primary_user_id
        output += "<br />"
        output += "#{sanitize account.primary_user_first_name} "
        output += sanitize account.primary_user_last_name
        output += "(#{account.primary_user_email})"
      end
      output += "<br />"
      output += content_tag(:span, account.identifier, class: 'info')
      output.html_safe
    end

    def user_list?
      controller_name == 'users' && action_name == 'index'
    end

    # Returns an array comprising pairs of the label and the corresponding database value for a tag.js version
    # E.g. [["1.0.1 (Latest)", "1.0.1"], ["1.0.0", "1.0.0"]]
    # https://github.com/heartcombo/simple_form#collections
    def select_tag_options_for_tag_js
      options = TagJsFileHelpers.tag_js_versions.sort.reverse.map { |version| [version, version.dup] }
      options.first.first << ' (Latest)'
      options
    end
  end
end
