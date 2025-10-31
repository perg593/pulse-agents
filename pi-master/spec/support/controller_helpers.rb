# frozen_string_literal: true
module ControllerHelpers
  def it_handles_missing_records(endpoint, custom_id: :id, id: -1)
    request_args = [endpoint[:verb], endpoint[:url]]
    request_kwargs = { params: { custom_id => id } }

    if endpoint[:json]
      send(*request_args, **request_kwargs.merge(xhr: true))

      assert_response 404, request.params.inspect.to_s
    end

    return unless endpoint[:json] != :always

    send(*request_args, **request_kwargs.merge(xhr: false))

    assert_response 302, request.params.inspect.to_s
    assert_redirected_to dashboard_url, request.params.inspect.to_s
  end
end
