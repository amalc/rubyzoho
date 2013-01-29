class RubyZoho::Crm::Lead

  attr_accessor :contact_id, :sm_owner_id, :contact_owner, :email, :first_name, :last_name,
                :account_id, :account_name, :phone, :smcreatorid, :created_by,
                :modified_by, :modified_by, :created_time, :modified_time,
                :mailing_street, :mailing_city, :mailing_state, :mailing_zip,
                :mailing_country, :email_opt_out, :salutation, :Add_to_quickbooks,
                :last_activity_time,

  def initialize(h = {})
    @contact_id = h[:contact_id],
    @smowner_id = h[:sm_owner_id],
    @contact_owner = h[:contact_owner],
    @email = h[:email]
    @first_name = h[:first_name],
    @last_name = h[:last_name],
    @account_id = h[:account_id],
    @account_name = h[:account_name],
    @phone = h[:phone],
    @smcreatorid = h[:smcreatorid],
    @created_by = h[:created_by],
    @modified_by = h[:modified_by],
    @modified_by = h[:modified_by],
    @created_time = h[:created_time],
    @modified_time = h[:modified_time],
    @mailing_street = h[:mailing_street],
    @mailing_city = h[:mailing_city],
    @mailing_state = h[:mailing_state],
    @mailing_zip = h[:mailing_zip],
    @mailing_country = h[:mailing_country],
    @email_opt_out = h[:email_opt_out],
    @salutation = h[:salutation],
    @Add_to_quickbooks = h[:Add_to_quickbooks],
    @last_activity_time = h[:last_activity_time]
  end

end