# frozen_string_literal: true

# Namespaced so they never shadow the Pundit policies in spec/policies.rb. ActionPolicy looks
# policies up by top-level constant name, so specs stub_const these into place.
module ActionPolicies
  class ApplicationPolicy < ActionPolicy::Base
    def show? = admin?

    def destroy? = false

    def history? = admin?

    def show_in_app? = admin?

    def dashboard? = admin?

    def index? = false

    def create? = admin?

    def update? = admin?
    alias_rule :edit?, to: :update?

    def export? = admin?

    def rails_admin_index? = true

    private

    def admin? = role?(:admin)

    def role?(role) = user.roles.include?(role)
  end

  class PlayerPolicy < ApplicationPolicy
    relation_scope do |relation|
      role?(:see_retired) ? relation : relation.where(retired: false)
    end

    def create?
      role?(:manage_player) || (role?(:create_player) && (!record.is_a?(Player) || record.suspended))
    end

    def update?
      role?(:manage_player) || (role?(:update_player) && (!record.is_a?(Player) || !record.retired))
    end

    def destroy? = role?(:manage_player)

    def index? = admin?

    def attributes_for(action)
      (action == :new) ? {position: "Catcher"} : {}
    end
  end

  class RetiredPlayerPolicy < PlayerPolicy
    relation_scope { |relation| relation.where(retired: true) }
  end

  class SuspendedPlayerPolicy < PlayerPolicy
    def destroy? = super && !(record.is_a?(Player) && record.suspended)
  end

  class AccountPlayerPolicy < PlayerPolicy
    authorize :account

    relation_scope { |relation| relation.where(team: account) }
  end

  # A policy with no relation scope at all.
  class TeamPolicy < ApplicationPolicy
    def index? = admin?
  end

  # A policy whose only relation scope is a named one.
  class DivisionPolicy < ApplicationPolicy
    relation_scope(:own) { |relation| relation }

    def index? = admin?
  end

  # Stubbed in as PaperTrailTestPolicy.
  class PaperTrailTestPolicy < ApplicationPolicy
    relation_scope { |relation| relation.where.not(name: "out of scope") }

    def index? = admin?
  end

  # Stubbed in as BallPolicy; Hardball, Ball's STI subclass, has no policy of its own.
  class BallPolicy < ApplicationPolicy
    relation_scope { |relation| relation.where(color: "red") }

    def show? = false

    def update? = false
  end
end
