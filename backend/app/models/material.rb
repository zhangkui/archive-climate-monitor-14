class Material < ApplicationRecord
  has_many :zones, dependent: :restrict_with_error
  has_many :risk_rules, dependent: :restrict_with_error

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
end
