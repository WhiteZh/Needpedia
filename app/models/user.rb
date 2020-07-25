class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :masqueradable, :database_authenticatable, :registerable, :recoverable, :rememberable, :validatable, :omniauthable

  after_create :add_default_credit

  has_rich_text :about

  has_person_name

  has_many :notifications, foreign_key: :recipient_id
  has_many :services
  has_many :posts, dependent: :destroy
  has_many :posted_gigs, class_name: 'Gig', dependent: :destroy

  has_many :transferred_transactions, class_name: 'Transaction', foreign_key: :actor_id
  has_many :received_transactions, class_name: 'Transaction', foreign_key: :recipient_id

  has_many :user_gigs
  has_many :gigs, through: :user_gigs, dependent: :destroy

  has_many :comments, dependent: :destroy

  has_many :flags, dependent: :destroy

  has_many :post_tokens, dependent: :destroy

  has_many :likes, dependent: :destroy

  has_many :shares, dependent: :destroy

  has_many :connections
  has_many :friends, through: :connections

  has_many :inverse_connections, class_name: 'Connection', foreign_key: 'friend_id'
  has_many :inverse_friends, through: :inverse_connections, source: :user

  has_many :connection_requests

  has_one_attached :profile_image

  has_many_attached :pictures

  def credit_hours
    active_gigs_amount = posted_gigs.active_progress.sum(:amount)
    sum = (received_transactions&.sum(:amount) - transferred_transactions&.sum(:amount) - active_gigs_amount).round(1)
    sum.negative? ? 0 : sum
  end

  def add_default_credit
    TransactionService.new(actor: nil, recipient: self, gig: nil, amount: 1, type: Transaction::TRANSACTION_TYPE_DEFAULT).call
  end

  def connection_status(current_user)
    if is_connected_with current_user
      state = { status: 'connected' }
    elsif ConnectionRequest.find_by user_id: current_user.id, to: self.uuid, status: 'pending'
      request = ConnectionRequest.find_by user_id: current_user.id, to: self.uuid, status: 'pending'
      state = {status: 'request_sent', request_uuid: request.uuid}
    elsif ConnectionRequest.find_by user_id: self.id, to: current_user.uuid, status: 'pending'
      request = ConnectionRequest.find_by user_id: self.id, to: current_user.uuid, status: 'pending'
      state = { status: 'request_received', request_uuid: request.uuid }
    else
      state = { status: 'not_connected' }
    end
    state
  end

  # this method returns the user connections and inverse connections
  def links
    self.friends + self.inverse_friends
  end

  # this method checks if a link exist between current user and the user in sent in argument
  def is_connected_with(user)
    links.include? user
  end
end
