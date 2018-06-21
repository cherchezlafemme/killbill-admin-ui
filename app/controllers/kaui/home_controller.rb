class Kaui::HomeController < Kaui::EngineController

  QUERY_PARSE_REGEX = ['FIND:(?<object_type>.*) BY:(?<search_by>.*) FOR:(?<search_for>.*) ONLY_FIRST:(?<fast>.*)',
                       'FIND:(?<object_type>.*) BY:(?<search_by>.*) FOR:(?<search_for>.*)',
                       'FIND:(?<object_type>.*) FOR:(?<search_for>.*) ONLY_FIRST:(?<fast>.*)',
                       'FIND:(?<object_type>.*) FOR:(?<search_for>.*)']

  SIMPLE_PARSE_REGEX = '(?<search_for>.*)'

  def index
    @search_query = params[:q]
  end

  def search
    object_type, search_query, search_by, fast = parse_query(params[:q])
    send("#{object_type}_search", search_query, search_by, fast) unless object_type.nil?
  end

  private

  def account_search(search_query, search_by = nil, fast = 0)
    if search_by == 'ID'
      begin
        account = Kaui::Account.find_by_id(search_query, false, false, options_for_klient)
        redirect_to account_path(account.account_id) and return
      rescue KillBillClient::API::NotFound => _
        search_error("No account matches \"#{search_query}\"")
      end
    elsif search_by == 'EXTERNAL_KEY'
      begin
        account = Kaui::Account.find_by_external_key(search_query, false, false, options_for_klient)
        redirect_to account_path(account.account_id) and return
      rescue KillBillClient::API::NotFound => _
        search_error("No account matches \"#{search_query}\"")
      end
    else
      account = Kaui::Account.list_or_search(search_query, 0, 1, options_for_klient).first
      if account.blank?
        search_error("No account matches \"#{search_query}\"")
      elsif true?(fast)
        redirect_to account_path(account.account_id) and return
      else
        redirect_to accounts_path(:q => search_query, :fast => fast) and return
      end
    end
  end

  def invoice_search(search_query, search_by = nil, fast = 0)
    if search_by == 'ID'
      begin
        invoice = Kaui::Invoice.find_by_id(search_query, false, 'NONE', options_for_klient)
        redirect_to account_invoice_path(invoice.account_id, invoice.invoice_id) and return
      rescue KillBillClient::API::NotFound => _
        search_error("No invoice matches \"#{search_query}\"")
      end
    elsif search_by == 'EXTERNAL_KEY'
      unsupported_external_key_search('INVOICE')
    else
      invoice = Kaui::Invoice.list_or_search(search_query, 0, 1, options_for_klient).first
      if invoice.blank?
        search_error("No invoice matches \"#{search_query}\"")
      elsif true?(fast)
        redirect_to account_invoice_path(invoice.account_id, invoice.invoice_id) and return
      else
        redirect_to account_invoices_path(:account_id => invoice.account_id, :q => search_query, :fast => fast) and return
      end
    end
  end

  def payment_search(search_query, search_by = nil, fast = 0)
    if search_by == 'ID'
      begin
        payment = Kaui::Payment.find_by_id(search_query, false, false, options_for_klient)
        redirect_to account_payment_path(payment.account_id, payment.payment_id) and return
      rescue KillBillClient::API::NotFound => _
        search_error("No payment matches \"#{search_query}\"")
      end
    elsif search_by == 'EXTERNAL_KEY'
      begin
        payment = Kaui::Payment.find_by_external_key(search_query, false, false, options_for_klient)
        redirect_to account_payment_path(payment.account_id, payment.payment_id) and return
      rescue KillBillClient::API::NotFound => _
        search_error("No payment matches \"#{search_query}\"")
      end
    else
      payment = Kaui::Payment.list_or_search(search_query, 0, 1, options_for_klient).first
      if payment.blank?
        search_error("No payment matches \"#{search_query}\"")
      elsif true?(fast)
        redirect_to account_payment_path(payment.account_id, payment.payment_id) and return
      else
        redirect_to account_payments_path(:account_id => payment.account_id, :q => search_query, :fast => fast) and return
      end
    end
  end

  def transaction_search(search_query, search_by = nil, fast = 0)
    if search_by.blank? || search_by == 'ID'
      begin
        payment = Kaui::Payment.find_by_transaction_id(search_query, false, true, options_for_klient)
        redirect_to account_payment_path(payment.account_id, payment.payment_id) and return
      rescue KillBillClient::API::NotFound => _
        search_error("No transaction matches \"#{search_query}\"")
      end
    else
      begin
        payment = Kaui::Payment.find_by_transaction_external_key(search_query, false, true, 'NONE', options_for_klient)
        redirect_to account_payment_path(payment.account_id, payment.payment_id) and return
      rescue KillBillClient::API::NotFound => _
        search_error("No transaction matches \"#{search_query}\"")
      end
    end
  end

  def bundle_search(search_query, search_by = nil, fast = 0)
    if search_by == 'ID'
      begin
        bundle = Kaui::Bundle.find_by_id(search_query, options_for_klient)
        redirect_to kaui_engine.account_bundles_path(bundle.account_id) and return
      rescue KillBillClient::API::NotFound => _
        search_error("No bundle matches \"#{search_query}\"")
      end
    elsif search_by == 'EXTERNAL_KEY'
      begin
        bundle = Kaui::Bundle.find_by_external_key(search_query, false, options_for_klient)
        redirect_to kaui_engine.account_bundles_path(bundle.account_id) and return
      rescue KillBillClient::API::NotFound => _
        search_error("No bundle matches \"#{search_query}\"")
      end
    else
      bundle = Kaui::Bundle.list_or_search(search_query, 0, 1, options_for_klient).first
      if bundle.blank?
        search_error("No bundle matches \"#{search_query}\"")
      else
        redirect_to kaui_engine.account_bundles_path(bundle.account_id) and return
      end
    end
  end

  def credit_search(search_query, search_by = nil, fast = 0)
    if search_by.blank? || search_by == 'ID'
      begin
        credit = Kaui::Credit.find_by_id(search_query, options_for_klient)
        redirect_to account_invoice_path(credit.account_id, credit.invoice_id) and return
      rescue KillBillClient::API::NotFound => _
        search_error("No credit matches \"#{search_query}\"")
      end
    else
      unsupported_external_key_search('CREDIT')
    end
  end

  def custom_field_search(search_query, search_by = nil, fast = 0)
    if search_by.blank? || search_by == 'ID'
      custom_field = Kaui::CustomField.list_or_search(search_query, 0, 1, options_for_klient)
      if custom_field.blank?
        search_error("No custom field matches \"#{search_query}\"")
      else
        redirect_to custom_fields_path(:q => search_query, :fast => fast) and return
      end
    else
      unsupported_external_key_search('CUSTOM FIELD')
    end
  end

  def invoice_payment_search(search_query, search_by = nil, fast = 0)
    if search_by.blank? || search_by == 'ID'
      begin
        invoice_payment = Kaui::InvoicePayment.find_safely_by_id(search_query, options_for_klient)
        redirect_to account_payment_path(invoice_payment.account_id, invoice_payment.payment_id) and return
      rescue KillBillClient::API::NotFound => _
        search_error("No invoice payment matches \"#{search_query}\"")
      end
    else
      unsupported_external_key_search('INVOICE PAYMENT')
    end
  end

  def subscription_search(search_query, search_by = nil, fast = 0)
    if search_by.blank? || search_by == 'ID'
      begin
        subscription = Kaui::Subscription.find_by_id(search_query, options_for_klient)
        redirect_to account_bundles_path(subscription.account_id) and return
      rescue KillBillClient::API::NotFound => _
        search_error("No subscription matches \"#{search_query}\"")
      end
    else
      unsupported_external_key_search('SUBSCRIPTION')
    end
  end

  def tag_search(search_query, search_by = nil, fast = 0)
    if search_by.blank? || search_by == 'ID'
      tag = Kaui::Tag.list_or_search(search_query, 0, 1, options_for_klient)
      if tag.blank?
        search_error("No tag matches \"#{search_query}\"")
      else
        redirect_to tags_path(:q => search_query, :fast => fast) and return
      end
    else
      unsupported_external_key_search('TAG')
    end
  end

  def tag_definition_search(search_query, search_by = nil, fast = 0)
    if search_by == 'ID'
      begin
        Kaui::TagDefinition.find_by_id(search_query, 'NONE', options_for_klient)
        redirect_to tag_definitions_path(:q => search_query, :fast => fast) and return
      rescue KillBillClient::API::NotFound => _
        search_error("No tag definition matches \"#{search_query}\"")
      end
    elsif search_by == 'EXTERNAL_KEY'
      unsupported_external_key_search('TAG DEFINITION')
    else
      tag_definition = Kaui::TagDefinition.find_by_name(search_query, 'NONE', options_for_klient)
      if tag_definition.blank?
        begin
          Kaui::TagDefinition.find_by_id(search_query, 'NONE', options_for_klient)
          redirect_to tag_definitions_path(:q => search_query, :fast => fast) and return
        rescue KillBillClient::API::NotFound => _
          search_error("No tag definition matches \"#{search_query}\"")
        end
      else
        redirect_to tag_definitions_path(:q => search_query, :fast => fast) and return
      end
    end
  end

  def unsupported_external_key_search(object_type)
    search_error("\"#{object_type}\": Search by \"EXTERNAL KEY\" is not supported.")
  end

  def search_error(message)
    flash[:error] = message
    redirect_to kaui_engine.home_path and return
  end

  def parse_query(query)
    statements, simple_regex_used = regex_parse_query(query)

    object_type = statements[:object_type].strip.downcase rescue 'account'
    search_for = statements[:search_for].strip
    search_by = statements[:search_by].strip.upcase rescue simple_regex_used && uuid?(search_for) ? 'ID' : nil
    fast = statements[:fast] rescue '0'

    if !search_by.blank? && !(search_by == 'ID' || search_by == 'EXTERNAL_KEY')
      search_error("\"#{search_by}\" is not a valid search by value")
    end

    return object_type, search_for, search_by, fast
  end

  def regex_parse_query(query)
    statements = nil
    simple_regex_used = false
    QUERY_PARSE_REGEX.each do |query_regex|
      regex_exp = Regexp.new(query_regex, true)
      statements = regex_exp.match(query)
      break unless statements.nil?
    end

    if statements.nil?
      regex_exp = Regexp.new(SIMPLE_PARSE_REGEX, true)
      statements = regex_exp.match(query)
      simple_regex_used = true
    end

    return statements, simple_regex_used
  end

  def true?(statement)
    [1,'1',true,'true'].include? ((statement.instance_of? String) ? statement.downcase : statement)
  end

  def uuid?(value)
    value =~ /[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}/
  end
end
