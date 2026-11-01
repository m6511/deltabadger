class BotAlertsMailer < ApplicationMailer
  # The user's switch for each mail (Settings › Account › Email alerts), read when the mail is built, not when it is queued.
  ALERT_SWITCHES = {
    'end_of_funds' => :email_low_funds?,
    'notify_about_error' => :email_bot_errors?,
    'notify_about_restart' => :email_bot_errors?,
    'stopped_by_error' => :email_bot_stopped?,
    'stopped_by_amount_limit' => :email_bot_stopped?,
    'stopped_by_base_amount_limit' => :email_bot_stopped?
  }.freeze

  before_action { @alert_switch = ALERT_SWITCHES.fetch(action_name) }
  after_action { message.perform_deliveries = false unless params[:user].public_send(@alert_switch) }

  def notify_about_error
    @user = params[:user]
    @errors = params[:errors].to_sentence
    @bot = params[:bot]
    @label = @bot.label
    @exchange_name = Exchange.find(@bot.exchange_id).name.upcase
    set_locale(@user)

    mail(to: @user.email, subject: t('.subject', label: @label))
  end

  def stopped_by_error
    @user = params[:user]
    @errors = params[:errors].to_sentence
    @bot = params[:bot]
    @label = @bot.label
    @exchange_name = Exchange.find(@bot.exchange_id).name.upcase
    set_locale(@user)

    mail(to: @user.email, subject: t('.subject', label: @label))
  end

  def notify_about_restart
    @user = params[:user]
    @restart_at = params[:restart_at]
    @errors = params[:errors].to_sentence
    @bot = params[:bot]
    @label = @bot.label
    @exchange_name = Exchange.find(@bot.exchange_id).name.upcase
    set_locale(@user)

    mail(to: @user.email, subject: default_i18n_subject)
  end

  def end_of_funds
    @user = params[:user]
    @bot = params[:bot]
    @quote = params[:quote]
    @label = @bot.label
    @exchange_name = Exchange.find(@bot.exchange_id).name
    set_locale(@user)

    mail(to: @user.email, subject: t('.subject', exchange_name: @exchange_name, quote: @quote))
  end

  def stopped_by_amount_limit
    @user = params[:user]
    @label = params[:label]
    @amount = params[:amount]
    @quote = params[:quote]
    set_locale(@user)

    mail(to: @user.email, subject: t('.subject', label: @label))
  end

  def stopped_by_base_amount_limit
    @user = params[:user]
    @label = params[:label]
    @amount = params[:amount]
    @base = params[:base]
    set_locale(@user)

    mail(to: @user.email, subject: t('.subject', label: @label))
  end
end
