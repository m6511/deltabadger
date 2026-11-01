# frozen_string_literal: true

require 'test_helper'

# Each bot alert mail belongs to one of the user's email alert switches (Settings › Account) and is
# not sent while that switch is off. The switch is read when the mail is built, not when it is queued.
class BotAlertsMailerTest < ActionMailer::TestCase
  # The app pins the SolidQueue adapter, which ActiveJob::TestHelper leaves alone.
  def queue_adapter_for_test
    ActiveJob::QueueAdapters::TestAdapter.new
  end

  setup do
    @user = create(:user, name: 'Owner')
    @bot = create(:dca_single_asset, user: @user)
  end

  MAILS = {
    end_of_funds: :email_low_funds,
    notify_about_error: :email_bot_errors,
    notify_about_restart: :email_bot_errors,
    stopped_by_error: :email_bot_stopped,
    stopped_by_amount_limit: :email_bot_stopped,
    stopped_by_base_amount_limit: :email_bot_stopped
  }.freeze

  def alert(mail)
    params = { user: @user, bot: @bot, label: @bot.label, errors: ['boom'], restart_at: 5.minutes.from_now,
               quote: 'CHF', base: 'BTC', amount: 100 }
    BotAlertsMailer.with(params).public_send(mail)
  end

  MAILS.each do |mail, switch|
    test "#{mail} is sent while #{switch} is on" do
      assert_emails(1) { alert(mail).deliver_now }
    end

    test "#{mail} is not sent while #{switch} is off" do
      @user.update!(switch => false)

      assert_emails(0) { alert(mail).deliver_now }
    end
  end

  test 'turning low funds off leaves the other alerts alone' do
    @user.update!(email_low_funds: false)

    assert_emails(2) do
      alert(:notify_about_error).deliver_now
      alert(:stopped_by_error).deliver_now
    end
  end

  test 'a mail queued while the switch was on is not sent once it is off' do
    assert_enqueued_emails(1) { @bot.notify_end_of_funds }
    @user.update!(email_low_funds: false)

    assert_emails(0) { perform_enqueued_jobs }
  end

  test 'an alert mail says where to turn it off: the account settings, in the user’s language' do
    I18n.with_locale(:en) do
      html = alert(:end_of_funds).body.to_s
      assert_includes html, %(href="http://localhost:3000/settings/account")

      @user.update!(locale: 'de')
      assert_includes alert(:end_of_funds).body.to_s, %(href="http://localhost:3000/de/settings/account")
    end
  end

  test 'a mail that is not a bot alert has no such line' do
    assert_not_includes TestMailer.test_email(@user).body.to_s, '/settings/account'
  end
end
