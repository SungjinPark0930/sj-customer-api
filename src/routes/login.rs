use axum::{extract::{Form, State}, response::Html};
use chrono::Utc;
use serde::Deserialize;
use tracing::{error, info};

use crate::AppState;

const LOGIN_PAGE_TEMPLATE: &str = r#"
<!DOCTYPE html>
<html lang="ko">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
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

      .user-badge {
        position: fixed;
        top: 20px;
        right: 26px;
        padding: 10px 16px;
        border-radius: 999px;
        background: rgba(23, 48, 79, 0.08);
        color: #17304f;
        font-weight: 600;
        font-size: 0.9rem;
        box-shadow: 0 4px 12px rgba(23, 48, 79, 0.12);
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

      .status-banner {
        margin-top: 18px;
        padding: 12px 16px;
        border-radius: 12px;
        font-size: 0.9rem;
        font-weight: 600;
      }

      .status-success {
        background: rgba(77, 174, 91, 0.18);
        color: #0a6b2b;
      }

      .status-error {
        background: rgba(250, 81, 81, 0.18);
        color: #a11010;
      }
    </style>
  </head>
  <body>
    __USER_BADGE__
    __CARD_CONTENT__
  </body>
</html>
"#;

#[derive(Deserialize)]
pub struct LoginForm {
    email: String,
    password: String,
}

pub async fn login_page_handler() -> Html<String> {
    Html(render_login_page(None, None))
}

pub async fn login_submit_handler(State(state): State<AppState>, Form(form): Form<LoginForm>) -> Html<String> {
    let email = form.email.trim().to_string();
    let password = form.password.trim().to_string();

    if email.is_empty() || password.is_empty() {
        return Html(render_login_page(
            None,
            Some(StatusMessage::error("이메일과 비밀번호를 모두 입력해주세요.")),
        ));
    }

    info!("received login request");

    let auth_result = match state.authenticate_google_user(&email, &password).await {
        Ok(result) => result,
        Err(err) => {
            error!("Google authentication failed: {err:?}");
            return Html(render_login_page(
                None,
                Some(StatusMessage::error("Google 인증에 실패했습니다. 자격 증명을 다시 확인해주세요.")),
            ));
        }
    };

    let now = Utc::now();

    if let Err(err) = state
        .insert_login_document(
            &auth_result.user_id,
            &auth_result.user_name,
            &auth_result.refresh_token,
            now,
        )
        .await
    {
        error!("failed to insert Firestore login document: {err:?}");
        return Html(render_login_page(
            None,
            Some(StatusMessage::error(
                "Firestore에 로그인 이력을 저장하는 중 오류가 발생했습니다.",
            )),
        ));
    }

    Html(render_login_page(
        Some(&auth_result.user_name),
        Some(StatusMessage::success("로그인에 성공했습니다. Firestore에 기록했습니다.")),
    ))
}

fn render_login_page(user_name: Option<&str>, status: Option<StatusMessage>) -> String {
    let badge_html = user_name
        .map(|name| format!(r#"<div class="user-badge">현재 로그인: {}</div>"#, html_escape(name)))
        .unwrap_or_default();

    let status_html = status
        .map(|message| {
            format!(
                r#"<div class="status-banner status-{}">{}</div>"#,
                message.kind.css_class(),
                html_escape(&message.text)
            )
        })
        .unwrap_or_default();

    let card_content = match user_name {
        Some(name) => {
            let escaped_name = html_escape(name);
            format!(
                r#"<main class="card">
      <h1>로그인이 완료되었습니다.</h1>
      <p class="subtitle">현재 {escaped_name} 계정으로 로그인되어 있습니다.</p>
      {status_html}
    </main>"#,
            )
        }
        None => format!(
            r#"<main class="card">
      <h1>Google 계정 로그인</h1>
      <p class="subtitle">서비스를 사용하려면 Google Email과 Password를 입력하세요.</p>
      <form method="post" action="/login">
        <label for="email">Google Email</label>
        <input
          id="email"
          name="email"
          type="email"
          inputmode="email"
          placeholder="name@example.com"
          autocomplete="username"
          required
        />

        <label for="password">Password</label>
        <input
          id="password"
          name="password"
          type="password"
          autocomplete="current-password"
          minlength="8"
          required
        />

        <button type="submit">로그인</button>
      </form>
      <p class="helper">
        비밀번호를 잊으셨나요?
        <a href="https://accounts.google.com/signin/v2/sl/pwd" rel="noopener noreferrer">Google 계정 복구</a>
      </p>
      {status_html}
    </main>"#,
        ),
    };

    LOGIN_PAGE_TEMPLATE
        .replace("__USER_BADGE__", &badge_html)
        .replace("__CARD_CONTENT__", &card_content)
}

#[derive(Clone)]
struct StatusMessage {
    kind: StatusKind,
    text: String,
}

impl StatusMessage {
    fn success(message: impl Into<String>) -> Self {
        Self {
            kind: StatusKind::Success,
            text: message.into(),
        }
    }

    fn error(message: impl Into<String>) -> Self {
        Self {
            kind: StatusKind::Error,
            text: message.into(),
        }
    }
}

#[derive(Clone, Copy)]
enum StatusKind {
    Success,
    Error,
}

impl StatusKind {
    fn css_class(self) -> &'static str {
        match self {
            StatusKind::Success => "success",
            StatusKind::Error => "error",
        }
    }
}

fn html_escape(input: &str) -> String {
    let mut escaped = String::with_capacity(input.len());

    for c in input.chars() {
        match c {
            '&' => escaped.push_str("&amp;"),
            '<' => escaped.push_str("&lt;"),
            '>' => escaped.push_str("&gt;"),
            '\"' => escaped.push_str("&quot;"),
            '\'' => escaped.push_str("&#39;"),
            _ => escaped.push(c),
        }
    }

    escaped
}
