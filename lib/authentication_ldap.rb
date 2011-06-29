require 'net/ldap'

class LDAPCommError < StandardError;end

class AuthenticationLDAP

  def self.authenticate(username,password)
    config = WebistranoConfig[:ldap]
    user_attributes = nil
    domain_username = username
    domain_username = "#{domain_username}@#{config[:domain]}" if config[:domain].present?

    connection = initialize_ldap_connection(:username => domain_username, :password => password)
    if connection.bind
      search_attributes = ["mail"]
      search_attributes << config[:ldap_id] if config[:ldap_id].present?
      search_attributes << 'memberof' if config[:memberof].present?
      connection.search(:filter => Net::LDAP::Filter.eq("sAMAccountName", username), :attributes =>  search_attributes) do |entry|
        if config[:memberof].nil? || entry[:memberof].include?(config[:memberof])
          user_attributes = {
            :email => entry[:mail].first,
            :login => username
          }
          user_attributes[:ldap_id] = entry[config[:ldap_id]].first if config[:ldap_id].present?
        end
      end
    end
    user_attributes
  rescue Net::LDAP::LdapError => e
    ActiveRecord::Base.logger.error("#{self}.class#authenticate Error #{e.class}: #{e.message}")
    return nil
  end

private
  def self.initialize_ldap_connection(options={})
    config = WebistranoConfig[:ldap]

    Net::LDAP.new(
      :host => config[:host],
      :port => config[:port],
      :base => config[:base],
      :auth => {
        :method => :simple,
        :username => options[:username],
        :password => options[:password]
      }
    )
  end
end
