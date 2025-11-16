mod config;
mod routes;
mod secret_manager;

use anyhow::{anyhow, Context};
use axum::routing::{get, post};
use axum::Router;
use chrono::{SecondsFormat, Utc};
use config::{load as load_config, SecretSource};
use gcp_auth::AuthenticationManager;
use rand::{distributions::Alphanumeric, Rng};
use reqwest::{Client, Url};
use routes::{
    check_secret::check_secret_handler,
    health::health_handler,
    insert_test_data::insert_test_data_handler,
    login::{login_page_handler, login_submit_handler},
};
use secret_manager::{access_secret, configure as configure_secret_manager, SecretManagerSettings};
use serde::{Deserialize, Serialize};
use serde_json::json;
use std::net::SocketAddr;
use std::sync::Arc;
use std::time::Duration;
use tokio::sync::OnceCell;
use tracing::{error, info, Level};
use tracing_subscriber::FmtSubscriber;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    init_tracing();

    let app_config = load_config()?;

    configure_secret_manager(SecretManagerSettings {
        scope: app_config.secret_manager_scope.clone(),
        endpoint: app_config.secret_manager_endpoint.clone(),
    })?;

    let config::AppConfig {
        google_client_id,
        google_client_secret_source,
        google_api_key_source,
        gcp_project_id,
        firestore_scope,
        firestore_endpoint,
        firestore_database_id,
        firestore_collection,
        ..
    } = app_config;

    let secret_state = match google_client_secret_source {
        SecretSource::Plain(secret) => SecretState::Plain(secret),
        SecretSource::SecretManager { resource } => SecretState::SecretManager {
            resource,
            cache: Arc::new(OnceCell::new()),
        },
    };

    let api_key_state = match google_api_key_source {
        SecretSource::Plain(secret) => SecretState::Plain(secret),
        SecretSource::SecretManager { resource } => SecretState::SecretManager {
            resource,
            cache: Arc::new(OnceCell::new()),
        },
    };

    let auth_manager = Arc::new(
        AuthenticationManager::new()
            .await
            .context("failed to initialize GCP authentication manager")?,
    );

    let app_state = AppState {
        google_client_id,
        google_client_secret: secret_state,
        google_api_key: api_key_state,
        gcp_project_id,
        firestore_scope,
        firestore_endpoint,
        firestore_database_id,
        firestore_collection,
        http_client: Client::builder()
            .timeout(Duration::from_secs(15))
            .build()
            .context("failed to build HTTP client")?,
        auth_manager,
    };

    let app = Router::new()
        .route("/", get(login_page_handler))
        .route("/login", post(login_submit_handler))
        .route("/v1/health", get(health_handler))
        .route("/v1/check-secret", get(check_secret_handler))
        .route("/v1/insert-test-data", post(insert_test_data_handler))
        .with_state(app_state);

    let addr = SocketAddr::from(([0, 0, 0, 0], 3000));

    info!("starting server on {}", addr);

    let listener = tokio::net::TcpListener::bind(addr).await?;

    if let Err(err) = axum::serve(listener, app).await {
        error!("server error: {err}");
        return Err(err.into());
    }

    Ok(())
}

fn init_tracing() {
    let subscriber = FmtSubscriber::builder()
        .with_max_level(Level::INFO)
        .finish();

    if let Err(err) = tracing::subscriber::set_global_default(subscriber) {
        eprintln!("tracing subscriber already set: {err}");
    }
}

#[derive(Clone)]
pub(crate) struct AppState {
    google_client_id: String,
    google_client_secret: SecretState,
    google_api_key: SecretState,
    gcp_project_id: String,
    firestore_scope: String,
    firestore_endpoint: String,
    firestore_database_id: String,
    firestore_collection: String,
    http_client: Client,
    auth_manager: Arc<AuthenticationManager>,
}

#[derive(Clone)]
enum SecretState {
    Plain(String),
    SecretManager {
        resource: String,
        cache: Arc<OnceCell<String>>,
    },
}

impl AppState {
    async fn resolve_secret(state: &SecretState, label: &str) -> anyhow::Result<String> {
        match state {
            SecretState::Plain(secret) => Ok(secret.clone()),
            SecretState::SecretManager { resource, cache } => {
                let resource = resource.clone();
                let cache = Arc::clone(cache);

                let secret_ref = cache.get_or_try_init(|| async move {
                    access_secret(&resource).await.with_context(|| {
                        format!(
                            "failed to load {} from Secret Manager resource `{}`",
                            label,
                            resource
                        )
                    })
                })
                .await?;

                Ok(secret_ref.clone())
            }
        }
    }

    async fn google_client_secret(&self) -> anyhow::Result<String> {
        Self::resolve_secret(&self.google_client_secret, "google-client-secret").await
    }

    async fn google_api_key(&self) -> anyhow::Result<String> {
        Self::resolve_secret(&self.google_api_key, "google-api-key").await
    }

    pub(crate) async fn google_secret_suffix(&self, count: usize) -> anyhow::Result<String> {
        let secret = self.google_client_secret().await?;
        Ok(last_n_chars(&secret, count))
    }

    pub(crate) async fn authenticate_google_user(
        &self,
        email: &str,
        password: &str,
    ) -> anyhow::Result<GoogleAuthResult> {
        info!(
            client_id = %self.google_client_id,
            project_id = %self.gcp_project_id,
            "starting Google authentication request"
        );

        let api_key = self.google_api_key().await?;

        let payload = json!({
            "email": email,
            "password": password,
            "returnSecureToken": true
        });

        let mut url = Url::parse(GOOGLE_VERIFY_PASSWORD_ENDPOINT)
            .context("failed to parse Google verifyPassword endpoint URL")?;
        {
            let mut pairs = url.query_pairs_mut();
            pairs.append_pair("key", api_key.trim());
        }

        let response = self
            .http_client
            .post(url)
            .json(&payload)
            .send()
            .await
            .context("failed to call Google verifyPassword endpoint")?;

        let status = response.status();
        let body_text = response
            .text()
            .await
            .context("failed to read Google verifyPassword response body")?;

        if !status.is_success() {
            error!(
                status = %status,
                body = %body_text,
                "Google authentication failed"
            );
            return Err(anyhow!(
                "Google authentication failed with status {}: {}",
                status,
                body_text
            ));
        }

        let auth_response: GoogleVerifyPasswordResponse = serde_json::from_str(&body_text)
            .context("failed to parse Google verifyPassword response body")?;

        let refresh_token = auth_response
            .refresh_token
            .ok_or_else(|| anyhow!("Google verifyPassword response missing refresh_token"))?;

        let user_id = auth_response
            .email
            .unwrap_or_else(|| email.to_string());

        let user_name = auth_response
            .display_name
            .or(auth_response.local_id)
            .unwrap_or_else(|| user_id.clone());

        info!(user_id = %user_id, "Google authentication succeeded");

        Ok(GoogleAuthResult {
            user_id,
            user_name,
            refresh_token,
        })
    }

    pub(crate) async fn insert_login_document(
        &self,
        user_id: &str,
        user_name: &str,
        google_refresh_token: &str,
        updated_at: chrono::DateTime<Utc>,
    ) -> anyhow::Result<String> {
        info!(
            user_id = %user_id,
            user_name = %user_name,
            "starting Firestore login document insert"
        );

        let payload = login_document_payload(user_id, user_name, google_refresh_token, updated_at);

        let document_name = self.insert_firestore_payload(payload).await?;

        info!(
            document_name = %document_name,
            user_id = %user_id,
            "Firestore login document insert completed"
        );

        Ok(document_name)
    }

    pub(crate) async fn insert_test_document(&self) -> anyhow::Result<InsertTestDataResponse> {
        let user_id = random_alphanumeric(10);
        let user_name = random_alphanumeric(10);
        let google_refresh_token = random_alphanumeric(10);
        let updated_at = Utc::now();

        info!(
            user_id = %user_id,
            user_name = %user_name,
            "generated random test data values"
        );

        let document_name = self
            .insert_login_document(
                &user_id,
                &user_name,
                &google_refresh_token,
                updated_at,
            )
            .await?;

        Ok(InsertTestDataResponse {
            document_name,
            user_id,
            user_name,
            google_refresh_token,
            updated_at: updated_at.to_rfc3339_opts(SecondsFormat::Secs, true),
        })
    }

    async fn insert_firestore_payload(&self, payload: serde_json::Value) -> anyhow::Result<String> {
        info!("requesting Firestore access token");

        let token = self
            .auth_manager
            .get_token(&[self.firestore_scope.as_str()])
            .await
            .context("failed to obtain Firestore access token")?;

        info!("obtained Firestore access token");

        let url = format!(
            "{}/projects/{}/databases/{}/documents/{}",
            self.firestore_endpoint,
            self.gcp_project_id,
            self.firestore_database_id,
            self.firestore_collection
        );

        info!("requesting Firestore document insert at {}", url);

        let response = self
            .http_client
            .post(&url)
            .bearer_auth(token.as_str())
            .json(&payload)
            .send()
            .await
            .context("failed to call Firestore API")?;

        let status = response.status();

        info!(%status, "received Firestore response");

        let body_text = response
            .text()
            .await
            .context("failed to read Firestore response body")?;

        if !status.is_success() {
            error!(
                status = %status,
                body = %body_text,
                "Firestore insert failed"
            );
            return Err(anyhow!(
                "Firestore insert failed with status {}: {}",
                status,
                body_text
            ));
        }

        let body: serde_json::Value = serde_json::from_str(&body_text)
            .context("failed to parse Firestore response body")?;

        let document_name = body
            .get("name")
            .and_then(|value| value.as_str())
            .unwrap_or_default()
            .to_string();

        Ok(document_name)
    }
}

fn last_n_chars(input: &str, count: usize) -> String {
    if input.chars().count() <= count {
        return input.to_string();
    }

    input
        .chars()
        .rev()
        .take(count)
        .collect::<Vec<_>>()
        .into_iter()
        .rev()
        .collect()
}

#[derive(Clone, Debug)]
pub(crate) struct GoogleAuthResult {
    pub user_id: String,
    pub user_name: String,
    pub refresh_token: String,
}

#[derive(Serialize)]
pub(crate) struct InsertTestDataResponse {
    document_name: String,
    #[serde(rename = "userId")]
    user_id: String,
    #[serde(rename = "userName")]
    user_name: String,
    #[serde(rename = "googleRefreshToken")]
    google_refresh_token: String,
    #[serde(rename = "updatedAt")]
    updated_at: String,
}

fn random_alphanumeric(len: usize) -> String {
    rand::thread_rng()
        .sample_iter(&Alphanumeric)
        .map(char::from)
        .take(len)
        .collect()
}

const GOOGLE_VERIFY_PASSWORD_ENDPOINT: &str =
    "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword";

#[derive(Debug, Deserialize)]
struct GoogleVerifyPasswordResponse {
    email: Option<String>,
    #[serde(rename = "displayName")]
    display_name: Option<String>,
    #[serde(rename = "localId")]
    local_id: Option<String>,
    #[serde(rename = "refreshToken")]
    refresh_token: Option<String>,
}

fn login_document_payload(
    user_id: &str,
    user_name: &str,
    google_refresh_token: &str,
    updated_at: chrono::DateTime<Utc>,
) -> serde_json::Value {
    json!({
        "fields": {
            "userId": { "stringValue": user_id },
            "userName": { "stringValue": user_name },
            "googleRefreshToken": { "stringValue": google_refresh_token },
            "updatedAt": { "timestampValue": updated_at.to_rfc3339_opts(SecondsFormat::Secs, true) }
        }
    })
}
