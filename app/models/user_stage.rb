class UserStage < ActiveRecord::Base
  belongs_to :user
  belongs_to :stage

  validates_presence_of :user_id, :stage_id

  # Validate uniqueness.
  def validate
    errors.add_to_base("This user already has this stage") if UserStage.find_by_user_id_and_stage_id(user_id, stage_id)
  end
end
