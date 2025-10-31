# frozen_string_literal: true
module Admin
  module CustomAuditsHelper
    def get_enum(audit, attribute)
      audit.auditable_type.constantize.send(attribute.pluralize).invert
    rescue NoMethodError
      nil
    end

    def get_association_name(attribute, value)
      association_class_name = get_association_class_name(attribute)

      begin
        association_class_name.constantize.send(:find_by, id: value).try(:name) if association_class_name
      rescue NameError => e
        # TODO: Handle more complex situtations, like next_question_id, whose model is Question
      end
    end

    def get_association_class_name(attribute)
      attribute.sub(/_id$/, "").camelize if attribute =~ /_id$/
    end

    def print_username(audit, is_admin: false)
      username = if audit.user.is_a?(String)
        if is_admin
          audit.username
        else
          begin
            audit.username if current_user.admin?
          rescue NameError
            nil
          end
        end
      else
        username = audit.user&.name
      end

      username ||= "an automated process"
    end
  end
end
