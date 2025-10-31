# frozen_string_literal: true
class UserPreview < ActionMailer::Preview
  def reset_email
    UserMailer.reset_email('current@email.com', 'new@email.com', SecureRandom.hex(10))
  end

  def send_out_invitation
    UserMailer.send_out_invitation(Invitation.first)
  end

  def locked_notification
    UserMailer.locked_notification(User.first, "128.0.0.1")
  end

  def automation_triggered
    emails = %w(user1@test.com user2@test.com)

    UserMailer.automation_triggered(emails, "test survey", "test question", %w(automation_1 automation_2), "test answer")
  end
end
