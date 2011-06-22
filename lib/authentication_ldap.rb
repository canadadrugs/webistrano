require 'net/ldap'

class LDAPCommError < StandardError;end

class AuthenticationLDAP

  def self.authenticate(username,password)
    user_attributes = nil

    connection = initialize_ldap_connection(:username => "#{username}@CANDRUGCORP", :password => password)
    filter = Net::LDAP::Filter.eq( "sAMAccountName", username )
    if connection.bind
      connection.search( :filter => filter, :attributes => ["mail","description","givenname",'sn',"samaccountname", "memberof", 'objectguid'] ) do |entry|
        if entry[:memberof].include?("CN=Employees,CN=Users,DC=CanDrugCorp")
          user_attributes = {
            :email => entry[:mail].first,
            :login => username,
            :guid => entry[:objectguid].first
          }
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
    options.merge!(WebistranoConfig[:ldap])

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
