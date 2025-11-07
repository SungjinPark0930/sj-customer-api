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
use reqwest::Client;
use routes::{
    check_secret::check_secret_handler,
    health::health_handler,
    insert_test_data::insert_test_data_handler,
};
use secret_manager::{access_secret, configure as configure_secret_manager, SecretManagerSettings};
use serde::Serialize;
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

    let auth_manager = Arc::new(
        AuthenticationManager::new()
            .await
            .context("failed to initialize GCP authentication manager")?,
    );

    let app_state = AppState {
        _google_client_id: google_client_id,
        google_client_secret: secret_state,
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
    _google_client_id: String,
    google_client_secret: SecretState,
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
    pub(crate) async fn google_secret_suffix(&self, count: usize) -> anyhow::Result<String> {
        let secret = match &self.google_client_secret {
            SecretState::Plain(secret) => secret.clone(),
            SecretState::SecretManager { resource, cache } => {
                let resource = resource.clone();
                let cache = Arc::clone(cache);

                let secret_ref = cache.get_or_try_init(|| async move {
                    access_secret(&resource).await.with_context(|| {
                        format!(
                            "failed to load google-client-secret from Secret Manager resource `{}`",
                            resource
                        )
                    })
                })
                .await?;

                secret_ref.clone()
            }
        };

        Ok(last_n_chars(&secret, count))
    }

    pub(crate) async fn insert_test_document(&self) -> anyhow::Result<InsertTestDataResponse> {
        let email = random_alphanumeric(10);
        let username = random_alphanumeric(10);
        let google_refresh_token = random_alphanumeric(10);
        let updated_at = Utc::now();

        info!(
            email = %email,
            username = %username,
            "generated random test data values"
        );

        info!("starting Firestore test document insert");

        let payload = json!({
            "fields": {
                "email": { "stringValue": email },
                "username": { "stringValue": username },
                "googleRefreshToken": { "stringValue": google_refresh_token },
                "updatedAt": { "timestampValue": updated_at.to_rfc3339_opts(SecondsFormat::Secs, true) }
            }
        });

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

        info!(
            document_name = %document_name,
            "successfully inserted Firestore test document"
        );

        info!("completed Firestore test document insert");

        Ok(InsertTestDataResponse {
            document_name,
            email,
            username,
            google_refresh_token,
            updated_at: updated_at.to_rfc3339_opts(SecondsFormat::Secs, true),
        })
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

#[derive(Serialize)]
pub(crate) struct InsertTestDataResponse {
    document_name: String,
    email: String,
    username: String,
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
