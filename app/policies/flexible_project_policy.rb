class FlexibleProjectPolicy < ApplicationPolicy
  def publish?
    done_by_owner_or_admin?
  end

  def validate_publish?
    done_by_owner_or_admin?
  end

  def push_to_online?
    done_by_owner_or_admin?
  end

  def finish?
    done_by_owner_or_admin? && record.open_for_contributions? && record.expires_at.nil?
  end
end
