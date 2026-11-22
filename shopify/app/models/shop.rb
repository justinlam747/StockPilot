class Shop < ActiveRecord::Base
  class ReauthorizationRequired < StandardError; end
  class TokenError < StandardError; end

  encrypts :access_token, :refresh_token
  has_many :products
  has_many :variants
  has_many :inventory_snapshots

  scope :active, -> { where(uninstalled_at: nil) }
  validates :shop_domain, presence: true, format: { with: /\A[a-z0-9][a-z0-9-]*\.myshopify\.com\z/ }

  def self.install!(domain, pair)
    transaction do
      shop = create_or_find_by!(shop_domain: domain) do |new_shop|
        new_shop.access_token = pair.token
        new_shop.installed_at = Time.current
      end
      shop.lock!
      if shop.uninstalled_at?
        shop.installed_at = Time.current
        shop.installation_id = SecureRandom.uuid
      end
      shop.installation_id ||= SecureRandom.uuid
      shop.uninstalled_at = nil
      shop.save_token_pair!(pair)
      shop
    end
  end

  def save_token_pair!(pair)
    if pair.token.blank? || pair.refresh_token.blank? || pair.expires_at.to_i <= Time.current.to_i
      raise TokenError, 'Shopify did not return a usable expiring token pair'
    end
    refresh_lifetime = pair.params['refresh_token_expires_in']
    update!(access_token: pair.token, access_token_expires_at: Time.at(pair.expires_at),
            refresh_token: pair.refresh_token, refresh_token_expires_at: refresh_lifetime&.to_i&.seconds&.from_now,
            reauthorization_required_at: nil)
  end

  def inventory_access_token
    raise ReauthorizationRequired if reauthorization_required_at?
    return access_token unless refresh_due?

    generation = installation_id
    token = with_lock do
      raise ActiveRecord::RecordNotFound if uninstalled_at? || generation != installation_id
      next if reauthorization_required_at?
      next access_token unless refresh_due?
      refresh_access_token
    end
    token || raise(ReauthorizationRequired, 'Reconnect Shopify to resume inventory sync')
  end

  private

  def refresh_due?
    # Existing installations keep their original offline grant until their next OAuth connection.
    access_token_expires_at && access_token_expires_at <= 2.minutes.from_now
  end

  def refresh_access_token
    if refresh_token.blank? || (refresh_token_expires_at && refresh_token_expires_at <= Time.current)
      return require_reauthorization
    end
    client = OAuth2::Client.new(ENV.fetch('SHOPIFY_API_KEY'), ENV.fetch('SHOPIFY_API_SECRET'),
      site: "https://#{shop_domain}", token_url: '/admin/oauth/access_token', auth_scheme: :request_body,
      max_redirects: 0, connection_opts: { request: { open_timeout: 5, timeout: 12 } })
    pair = client.get_token(grant_type: 'refresh_token', refresh_token: refresh_token)
    save_token_pair!(pair)
    access_token
  rescue OAuth2::Error => error
    return require_reauthorization if error.code == 'invalid_grant' || (error.response.status == 401 && error.code == 'invalid_request')
    raise TokenError, 'Shopify token refresh failed', cause: nil
  rescue Faraday::Error, OAuth2::ConnectionError, OAuth2::TimeoutError
    raise TokenError, 'Shopify token service is unavailable', cause: nil
  end

  def require_reauthorization
    update!(reauthorization_required_at: Time.current)
    nil
  end
end
