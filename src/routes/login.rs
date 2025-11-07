use axum::response::Html;

const LOGIN_PAGE_HTML: &str = r#"
<!DOCTYPE html>
<html lang=\"ko\">
  <head>
    <meta charset=\"UTF-8\" />
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />
    <title>Google 로그인</title>
    <style>
      :root {
        color-scheme: light dark;
        font-family: 'Noto Sans KR', system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
        background: #f5f7fb;
      }

      body {
        margin: 0;
        display: flex;
        min-height: 100vh;
        align-items: center;
        justify-content: center;
        background: radial-gradient(circle at top, #e2ebff -20%, #f5f7fb 55%);
      }

      .card {
        width: min(380px, 92vw);
        background: #fff;
        border-radius: 18px;
        padding: 32px 36px;
        box-shadow: 0 18px 35px rgba(24, 63, 137, 0.12);
      }

      h1 {
        font-size: 1.6rem;
        margin: 0 0 8px;
        color: #17304f;
      }

      p.subtitle {
        margin: 0 0 28px;
        color: #5b6b82;
        font-size: 0.95rem;
      }

      label {
        display: block;
        font-weight: 600;
        font-size: 0.9rem;
        color: #2c3f5b;
        margin-bottom: 6px;
      }

      input {
        width: 100%;
        border-radius: 10px;
        border: 1px solid #d5dcef;
        padding: 12px 14px;
        font-size: 0.95rem;
        margin-bottom: 18px;
        outline: none;
        transition: border 0.15s ease, box-shadow 0.15s ease;
      }

      input:focus {
        border-color: #2f68ff;
        box-shadow: 0 0 0 2px rgba(47, 104, 255, 0.15);
      }

      button {
        width: 100%;
        border: none;
        border-radius: 12px;
        padding: 13px 16px;
        font-size: 1rem;
        font-weight: 600;
        letter-spacing: 0.3px;
        color: #fff;
        background: linear-gradient(135deg, #2f68ff, #5b8dff);
        cursor: pointer;
        transition: transform 0.15s ease, box-shadow 0.15s ease;
      }

      button:hover {
        transform: translateY(-1px);
        box-shadow: 0 8px 18px rgba(47, 104, 255, 0.25);
      }

      .helper {
        margin-top: 18px;
        font-size: 0.85rem;
        color: #6f7c92;
        text-align: center;
      }

      .helper a {
        color: #2f68ff;
        text-decoration: none;
        font-weight: 600;
      }
    </style>
  </head>
  <body>
    <main class=\"card\">
      <h1>Google 계정 로그인</h1>
      <p class=\"subtitle\">서비스를 사용하려면 Google Email과 Password를 입력하세요.</p>
      <form method=\"post\" action=\"/login\">
        <label for=\"email\">Google Email</label>
        <input
          id=\"email\"
          name=\"email\"
          type=\"email\"
          inputmode=\"email\"
          placeholder=\"name@example.com\"
          autocomplete=\"username\"
          required
        />

        <label for=\"password\">Password</label>
        <input
          id=\"password\"
          name=\"password\"
          type=\"password\"
          autocomplete=\"current-password\"
          minlength=\"8\"
          required
        />

        <button type=\"submit\">로그인</button>
      </form>
      <p class=\"helper\">
        비밀번호를 잊으셨나요?
        <a href=\"https://accounts.google.com/signin/v2/sl/pwd\" rel=\"noopener noreferrer\">Google 계정 복구</a>
      </p>
    </main>
  </body>
</html>
"#;

pub async fn login_page_handler() -> Html<&'static str> {
    Html(LOGIN_PAGE_HTML)
}
