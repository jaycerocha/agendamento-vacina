class Patient < ApplicationRecord
  devise :database_authenticatable, :registerable, :rememberable, authentication_keys: [:cpf]

  MAX_LOGIN_ATTEMPTS = 2

  has_many :appointments, dependent: :destroy
  belongs_to :main_ubs, class_name: 'Ubs'

  validates :name, presence: true
  validates :cpf, presence: true, uniqueness: true, cpf_format: true
  validates :mother_name, presence: true
  validates :birth_date, presence: true
  validates :phone, presence: true
  validates :neighborhood, presence: true

  after_initialize :set_main_ubs

  scope :bedridden, -> { where(bedridden: true) }

  # TODO: remove `chronic` field from schema
  enum target_audience: [:kid, :elderly, :chronic, :disabled, :pregnant, :postpartum, :not_target_audience]

  def active_appointments
    appointments.select(&:active?)
  end

  def set_main_ubs
    self.main_ubs =
      # samples an active ubs near the patient neighborhood
      Neighborhood.find_by(name: neighborhood)&.active_ubs&.sample ||
      # samples any active ubs
      Ubs.active.sample ||
      # samples an inactive ubs near the patient neighborhood
      Neighborhood.find_by(name: neighborhood)&.sample ||
      # samples any inactive ubs
      Ubs.all.sample
  end

  def email_required?
    false
  end

  def email_changed?
    false
  end

  def increase_login_attempts
    update!(login_attempts: login_attempts + 1)
  end

  def remaining_attempts
    MAX_LOGIN_ATTEMPTS - login_attempts
  end

  def blocked?
    login_attempts >= MAX_LOGIN_ATTEMPTS
  end

  def bedridden?
    bedridden == true
  end

  def unblock!
    update!(login_attempts: 0)
  end

  def encrypted_password
    ''
  end

  def allowed_age?
    p_year = birth_date[0..3].to_i
    p_month = birth_date[5..6].to_i
    p_day = birth_date[8..9].to_i

    now_year = DateTime.now.strftime('%Y').to_i
    now_month = DateTime.now.strftime('%m').to_i
    now_day = DateTime.now.strftime('%d').to_i

    if elderly?
      # Older than 60 years old
      return false if p_year > (now_year - 60) or
        (p_year == (now_year - 60) and p_month >= now_month and p_day > now_day)
    elsif kid?
      # Between 6 months and 5 years old
      return false if (now_year - p_year) * 12 + (now_month - p_month) < 6
      return false if (now_year - p_year) * 12 + (now_month - p_month) > 72
    end

    return true
  end

  def validate_year
    p_year = birth_date[0..3].to_i
    p_month = birth_date[5..6].to_i
    p_day = birth_date[8..9].to_i

    if p_year < 1850
      if p_year > 20
        p_year = p_year + 1900
      else
        p_year = p_year + 2000
      end

      new_birth_date = '%04d-%02d-%02d' % [p_year, p_month, p_day]
      update!(birth_date: new_birth_date)
    end
  end

end
