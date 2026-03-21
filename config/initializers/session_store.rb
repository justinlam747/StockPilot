# frozen_string_literal: true

Rails.application.config.session_store :cookie_store,
                                       key: '_stockpilot_session',
                                       expire_after: 24.hours,
                                       secure: Rails.env.production?,
                                       httponly: true,
                                       same_site: :lax
