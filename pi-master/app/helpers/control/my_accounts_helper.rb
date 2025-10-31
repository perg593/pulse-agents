# frozen_string_literal: true
module Control
  module MyAccountsHelper
    def custom_data_snippet_hint
      "
      You can use the <code>pi('set_context_data', object);</code>
      to save context data along with the survey results.<br/>
      The object can be a javascript object, arrays, string or integers size limit is
      1000 characters once serialized into JSON.<br/>
      <br/>
      Examples:<br/>
      <code>pi('set_context_data', {gender: 'male', age: 32, locale: 'en-US'});</code><br/>
      <code>pi('set_context_data', 'christmas_promotion');</code><br/>
      ".html_safe
    end

    def onview_callback_hint
      "
        This code snippet will be executed as soon as the survey is viewed by the user.<br/>
      ".html_safe
    end

    def callback_code_hint
      "
      This code snippet will be executed after the survey submission and the <code>survey</code>
      object gives you access to all the data related to the survey and the submitted answers.<br/>
      <code>survey.questions</code> returns all the details about the survey questions and <code>survey.answers</code>
      returns the submitted answers by the user.<br/>
      In case of Onanswer Callback, <code>answer</code> and <code>question</code> objects representing the current answer
      and question will be also present.<br/>
      <br/>
      Example:<br/>
      <code>var firstQuestionContent = survey.questions[0].content;</code><br />
      <code>var firstAnswerContent = survey.answers[0].content;</code><br />
      <code>ga('send','hitType': 'event',</code><br />
      <code>&nbsp;&nbsp;'eventCategory': 'survey',</code><br />
      <code>&nbsp;&nbsp;'eventAction': 'response',</code><br />
      <code>&nbsp;&nbsp;'eventLabel': firstQuestionContent,</code><br />
      <code>&nbsp;&nbsp;'eventValue': firstAnswerContent</code><br />
      <code>});</code>
      ".html_safe
    end

    def onanswer_callback_hint
      "
        This code snippet will be executed after each answer submission (after submitting but right before the /answer HTTP call).<br/>
        The <code>survey</code> object gives you access to all the data related to the survey and the <code>question</code> object the answered question.<br/>
        Also, an <code>answer</code> object gives you access to the last answer submitted and will be formated as the following:<br/><br/>
        Single choice question:
        <code>{ id: the_possible_answer_id, content: 'asdf', next_question_id: 1234 }</code><br/>
        Multiple choice question:
        <code>{ id: the_possible_answer_id, content: 'asdf', next_question_id: 1234 }</code><br/>
        Free text question:
        <code>{ id: null, content: 'asdf', next_question_id: 1234 }</code><br/>
      ".html_safe
    end

    def onclose_callback_hint
      "
        This code snippet will be executed when the survey is closed before all of its questions have been answered.<br/>
        The <code>survey</code> object gives you access to all the data related to the survey.<br>
      ".html_safe
    end

    def onclick_callback_hint
      "
        This code snippet will be executed after an anchor tag within a custom content question gets clicked.
      ".html_safe
    end

    def print_dynamic_email_template
      erb = ERB.new(File.read("app/views/control/my_accounts/_dynamic_email_template.html.erb"))

      local_binding = binding
      local_binding.local_variable_set(:account_identifier, current_user.account.identifier)

      url = if Rails.env.development?
        # whatever you're using to test the feature
        # must be accessible to outside world
        "a5e39a7e.ngrok.io"
      elsif Rails.env.production?
        "survey.pulseinsights.com"
      elsif Rails.env.staging?
        "staging-survey.pulseinsights.com"
      else
        request.host
      end

      local_binding.local_variable_set(:host, url)

      erb.result(local_binding)
    end

    def audit_data_integration_columns
      %w(oncomplete_callback_enabled oncomplete_callback_code onanswer_callback_enabled onanswer_callback_code onclose_callback_enabled onclose_callback_code
         custom_data_enabled custom_data_snippet onview_callback_enabled onview_callback_code)
    end
  end
end
