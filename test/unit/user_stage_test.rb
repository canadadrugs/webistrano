require 'test_helper'

class UserStageTest < ActiveSupport::TestCase
  def test_creation
    assert_equal 0, UserStage.count

    assert_nothing_raised{
      user_stage = UserStage.create!(:user_id => 1, :stage_id => 1)
    }
    assert_equal 1, UserStage.count
  end

  def test_validation
    user_stage = UserStage.create!(:user_id => 2, :stage_id => 1)
    
    # try to create another user stage for the same user and stage
    new_stage = UserStage.new(:user_id => 2, :stage_id => 1)
    assert !new_stage.valid?
    assert_not_nil new_stage.errors

    # try to create a user stage without a user id
    new_stage = UserStage.new(:stage_id => 1)
    assert !new_stage.valid?
    assert_not_nil new_stage.errors.on("user_id")

    # try to create a user stage without a stage id
    new_stage = UserStage.new(:user_id => 1)
    assert !new_stage.valid?
    assert_not_nil new_stage.errors.on("stage_id")
    
    # make it pass
    new_stage = UserStage.new(:user_id => 3, :stage_id => 3)
    assert new_stage.valid?
  end
end
