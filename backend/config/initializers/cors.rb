# 前端通过 nginx 反代 /api 访问；同时放行开发环境 Vite 直连
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins "*"
    resource "*",
      headers: :any,
      methods: %i[get post put patch delete options head]
  end
end

Rails.application.config.action_dispatch.default_headers = {
  "X-Frame-Options" => "SAMEORIGIN",
  "X-Content-Type-Options" => "nosniff"
}
