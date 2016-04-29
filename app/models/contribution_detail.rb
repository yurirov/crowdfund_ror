class ContributionDetail < ActiveRecord::Base
  self.table_name = '"1".contribution_details'
  include I18n::Alchemy
  TRANSITION_DATES = %i(refused_at paid_at pending_refund_at refunded_at)

  belongs_to :user
  belongs_to :project
  belongs_to :reward
  belongs_to :contribution
  belongs_to :payment

  delegate :payer_email, :payer_name, to: :contribution
  delegate :pay, :refuse, :trash, :chargeback, :refund, :request_refund, :request_refund!,
           :credits?, :paid?, :refused?, :pending?, :deleted?, :refunded?, :direct_refund,
           :slip_payment?, :pending_refund?, :second_slip_path,
           :pagarme_delegator, :waiting_payment?, :slip_expired?, to: :payment

  scope :with_state, ->(state){ where(state: state) }
  scope :was_confirmed, ->{ where("contribution_details.state = ANY(confirmed_states())") }

  # Scopes based on project state
  scope :with_project_state, ->(state){ where(project_state: state) }
  scope :for_successful_projects, -> { with_project_state('successful').available_to_display }
  scope :for_online_projects, -> {
    with_project_state(['online', 'waiting_funds']).
    where("contribution_details.state not in('deleted')")
  }
  scope :for_failed_projects, -> { with_project_state('failed').available_to_display }

  scope :available_to_display, -> {
    joins(:payment).
    where("contribution_details.state not in('deleted', 'refused', 'pending') OR payments.waiting_payment")
  }

  scope :slips_past_waiting, -> {
    where(payment_method: 'BoletoBancario',
          state: 'pending',
          waiting_payment: false,
          project_state: 'online')
  }

  scope :no_confirmed_contributions_on_project, -> {
    where("NOT EXISTS (
          SELECT true 
          FROM contributions c 
          WHERE 
            c.user_id = contribution_details.user_id 
            AND c.project_id = contribution_details.project_id 
            AND c.was_confirmed)"
         )
  }

  scope :pending, -> { joins(:payment).merge(Payment.waiting_payment) }

  scope :ordered, -> { order(id: :desc) }

  def can_show_slip?
    self.slip_payment? && !self.slip_expired?
  end

  def can_show_receipt?
    project = self.project.flexible_project || self.project
    self.paid? && (project.successful? || project.online? || project.waiting_funds?)
  end

  def can_generate_slip?
    self.slip_payment? &&
      self.project.open_for_contributions? &&
      self.pending? &&
      self.slip_expired? &&
      (self.reward.nil? || !self.reward.sold_out?)
  end
end
