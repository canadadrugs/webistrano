require 'digest/sha1'
class User < ActiveRecord::Base
  has_many :deployments, :dependent => :nullify, :order => 'created_at DESC'

  # Project stages that a user is allowed to see and deploy
  has_many :user_stages, :dependent => :destroy
  has_many :stages, :through => :user_stages

  # All projects which a user is authorised to.
  has_many :authorized_projects, :class_name => "Project", :finder_sql => %q(
                                                                              SELECT DISTINCT pj.* FROM projects pj
                                                                              JOIN stages st ON st.project_id=pj.id
                                                                              JOIN user_stages us ON us.stage_id=st.id
                                                                              WHERE us.user_id=#{id}
                                                                            )

  # Virtual attribute for the unencrypted password
  attr_accessor :password
  
  attr_accessible :login, :email, :password, :password_confirmation, :time_zone, :tz, :stage_ids, :guid

  validates_presence_of     :login, :email
  validates_presence_of     :guid, :if => :use_ldap_authentication?
  validates_presence_of     :password,                   :if => :password_required?
  validates_presence_of     :password_confirmation,      :if => :password_required?
  validates_length_of       :password, :within => 4..40, :if => :password_required?
  validates_confirmation_of :password,                   :if => :password_required?
  validates_length_of       :login,    :within => 3..40
  validates_length_of       :email,    :within => 3..100
  validates_uniqueness_of   :email, :case_sensitive => false
  validates_uniqueness_of   :login, :case_sensitive => false, :scope => :guid
  validate                  :only_one_enabled_unique_login
  before_save :encrypt_password
  
  named_scope :enabled, :conditions => {:disabled => nil}
  named_scope :disabled, :conditions => "disabled IS NOT NULL"

  def only_one_enabled_unique_login
    # Verify that this user is the only enabled user with the login
    if !disabled? && User.find_all_by_login_and_disabled(login, nil).reject{|user| user.id == self.id}.size > 0
      errors.add(:login, 'name can only be active for one user at a time.')
    end
  end

  def validate_on_update
    if User.find(self.id).admin? && !self.admin?
      errors.add('admin', 'status can no be revoked as there needs to be one admin left.') if User.admin_count == 1
    end
  end
  
  # Authenticates a user by their login name and unencrypted password.  Returns the user or nil.
  def self.authenticate(login, password)
    case WebistranoConfig[:authentication_method]
    when :ldap
      User.authenticate_ldap(login, password)
    else 
      User.authenticate_locally(login, password)
    end
  end
  
  def self.authenticate_ldap(login, password)
    attributes = AuthenticationLDAP.authenticate(login, password)

    return nil unless attributes

    find_by_login_and_disabled_and_guid(login, nil, attributes[:guid]) || create!(attributes.merge(:password_confirmation => password, :password => password))
  end
  
  def self.authenticate_locally(login, password)
    u = find_by_login_and_disabled(login, nil) # need to get the salt
    u && u.authenticated?(password) ? u : nil
  end
  
  # Encrypts some data with the salt.
  def self.encrypt(password, salt)
    Digest::SHA1.hexdigest("--#{salt}--#{password}--")
  end

  # All projects that a user has stages for. Admin users see all projects
  def projects
    if admin?
      Project.find(:all, :include => :stages, :order => 'name ASC')
    else
      authorized_projects
    end
  end

  def stages_for_project(project)
    if admin?
      project.stages
    else
      stages.for_project(project)
    end
  end

  # Encrypts the password with the user salt
  def encrypt(password)
    self.class.encrypt(password, salt)
  end

  def authenticated?(password)
    crypted_password == encrypt(password)
  end

  def remember_token?
    remember_token_expires_at && Time.now < remember_token_expires_at
  end

  # These create and unset the fields required for remembering users between browser closes
  def remember_me
    remember_me_for 2.weeks
  end

  def remember_me_for(time)
    remember_me_until time.from_now.utc
  end

  def remember_me_until(time)
    self.remember_token_expires_at = time
    self.remember_token            = encrypt("#{email}--#{remember_token_expires_at}")
    save(false)
  end

  def forget_me
    self.remember_token_expires_at = nil
    self.remember_token            = nil
    save(false)
  end
  
  def admin?
    self.admin.to_i == 1
  end
  
  def revoke_admin!
    self.admin = 0
    self.save!
  end
  
  def make_admin!
    self.admin = 1
    self.save!
  end
  
  def self.admin_count
    count(:id, :conditions => ['admin = 1 AND disabled IS NULL'])
  end
  
  def recent_deployments(limit=3)
    self.deployments.find(:all, :limit => limit, :order => 'created_at DESC')
  end
  
  def disabled?
    !self.disabled.blank?
  end
  
  def disable
    self.update_attribute(:disabled, Time.now)
    self.forget_me
  end
  
  def enable
    self.disabled = nil
    self.save
  end

  def authorized_for_project?(project_id)
    if admin?
      true
    else
      # Since has_many with finder_sql doesnt support find_in_collection, we cannot use
      # authorized_projects.find(project_id) , so we have to use a custom sequel
      begin
        project = Project.find(
          :first,
          :joins => "JOIN stages ON stages.project_id=projects.id JOIN user_stages ON user_stages.stage_id=stages.id",
          :conditions => ["user_stages.user_id=? AND projects.id=?", self.id, project_id]
        )
        project.present?
      rescue
        false
      end
    end
  end

  def authorized_for_stage?(stage_id)
    if admin?
      true
    else
      begin
        stages.find(stage_id).present?
      rescue
        false
      end
    end
  end

  protected
    # before filter
    def encrypt_password
      return if password.blank?
      self.salt = Digest::SHA1.hexdigest("--#{Time.now.to_s}--#{login}--") if new_record?
      self.crypted_password = encrypt(password)
    end

    def password_required?
      WebistranoConfig[:authentication_method] != :cas && (crypted_password.blank? || !password.blank?)
    end

    def use_ldap_authentication?
      WebistranoConfig[:authentication_method] == :ldap
    end
end
