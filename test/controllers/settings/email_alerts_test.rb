# frozen_string_literal: true

require 'test_helper'

# Settings › Account › Email alerts: one switch per kind of bot alert mail, on until the user turns it off.
class Settings::EmailAlertsTest < ActionDispatch::IntegrationTest
  setup do
    create(:user, admin: true) # satisfies the onboarding gate (an admin must exist)
    @user = create(:user)
    sign_in @user
  end

  test 'every alert is on to begin with' do
    assert @user.email_low_funds?
    assert @user.email_bot_errors?
    assert @user.email_bot_stopped?
  end

  test 'the switch stores the state it posts, for its own alert only' do
    patch settings_update_email_alerts_path, params: { alert: 'low_funds', enabled: '0' }, as: :turbo_stream

    assert_response :ok
    @user.reload
    assert_not @user.email_low_funds?
    assert @user.email_bot_errors?
    assert @user.email_bot_stopped?

    patch settings_update_email_alerts_path, params: { alert: 'low_funds', enabled: '1' }, as: :turbo_stream

    assert @user.reload.email_low_funds?
  end

  test 'each alert has its own switch' do
    %w[bot_errors bot_stopped].each do |alert|
      patch settings_update_email_alerts_path, params: { alert:, enabled: '0' }, as: :turbo_stream
    end

    @user.reload
    assert @user.email_low_funds?
    assert_not @user.email_bot_errors?
    assert_not @user.email_bot_stopped?
  end

  test 'an alert preference belongs only to the signed-in account' do
    other = create(:user)
    @user.update!(email_low_funds: false)
    sign_out @user
    sign_in other

    get settings_account_path

    assert_select 'turbo-frame#email_low_funds input[type=checkbox][checked]'
    patch settings_update_email_alerts_path, params: { alert: 'bot_errors', enabled: '0' }, as: :turbo_stream
    assert_response :ok
    assert @user.reload.email_bot_errors?
    assert_not other.reload.email_bot_errors?
    assert_not @user.email_low_funds?
    assert other.email_low_funds?
  end

  test 'a post with no state reads as off' do
    patch settings_update_email_alerts_path, params: { alert: 'bot_errors' }, as: :turbo_stream

    assert_not @user.reload.email_bot_errors?
  end

  test 'an alert that does not exist is refused and nothing is written' do
    assert_no_changes -> { @user.reload.updated_at } do
      patch settings_update_email_alerts_path, params: { alert: 'admin', enabled: '0' }, as: :turbo_stream
    end

    assert_response :unprocessable_entity
  end

  test 'the answer replaces only the row that was switched, drawn in its new state' do
    patch settings_update_email_alerts_path, params: { alert: 'low_funds', enabled: '0' }, as: :turbo_stream

    assert_turbo_stream action: 'replace', target: 'email_low_funds', count: 1 do
      assert_select 'input[type=checkbox]:not([checked])'
      assert_select 'input[type=hidden][name=enabled][value="1"]'
      assert_select 'input[type=hidden][name=alert][value=low_funds]'
    end
    assert_select 'turbo-stream', count: 1
  end

  test 'the account section shows a switch per alert, in the stored state' do
    @user.update!(email_bot_errors: false)

    get settings_account_path

    assert_select 'turbo-frame#email_low_funds input[type=checkbox][checked]'
    assert_select 'turbo-frame#email_bot_errors input[type=checkbox]:not([checked])'
    assert_select 'turbo-frame#email_bot_stopped input[type=checkbox][checked]'
  end

  test 'signed out, the switch asks for a sign-in and writes nothing' do
    sign_out @user

    patch settings_update_email_alerts_path, params: { alert: 'low_funds', enabled: '0' }

    assert_redirected_to new_user_session_path
    assert @user.reload.email_low_funds?
  end
end
