# frozen_string_literal: true

Rails.application.configure do
  # We will only report breaches for a while, then actually enforce these CSP rules by removing this line
  config.content_security_policy_report_only = true

  s3_buckets = %w[development2 staging2 production public photos-overrides].map { "collectif-objets-#{_1}" }
  s3_uris1 = s3_buckets.map { "https://s3.fr-par.scw.cloud/#{_1}/" }
  s3_uris2 = s3_buckets.map { "https://#{_1}.s3.fr-par.scw.cloud/" }

  config.content_security_policy do |policy|
    # Specify URI for violation reports
    if Rails.configuration.x.environment_specific_name == "production"
      policy.report_uri "https://sentry.incubateur.net/api/40/security/?sentry_key=5f6f9cf638ac413b82d1d9c8a9ba2025"
    end

    policy.default_src :self, :https
    policy.script_src  :self, :https
    policy.img_src \
      :self,
      :data,
      :blob, # cf https://maplibre.org/maplibre-gl-js-docs/api/#csp-directives
      *s3_uris1,
      *s3_uris2,
      "https://s3.eu-west-3.amazonaws.com/pop-phototeque/",
      "https://collectif-objets.beta.gouv.fr/" # for mail previews

    policy.connect_src \
      :self,
      "https://sentry.incubateur.net",
      "https://stats.beta.gouv.fr",
      "https://openmaptiles.geo.data.gouv.fr",
      *s3_uris2,
      *(Rails.env.development? ? ["ws://#{ ViteRuby.config.host_with_port }"] : [])

    policy.object_src  :none
    policy.font_src :self, :https, :data
    policy.child_src :blob # cf https://maplibre.org/maplibre-gl-js-docs/api/#csp-directives
    policy.worker_src :blob # cf https://maplibre.org/maplibre-gl-js-docs/api/#csp-directives

    policy.style_src :self, :https, *(Rails.env.development? ? [:unsafe_inline] : [])

    policy.frame_src "https://collectif-objets-metabase.osc-secnum-fr1.scalingo.io/"
  end

  # Generate session nonces for permitted importmap and inline scripts
  config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }

  nonce_directives = %w(script-src)
  nonce_directives += %w(style-src) unless Rails.env.development?
  config.content_security_policy_nonce_directives = nonce_directives
end
