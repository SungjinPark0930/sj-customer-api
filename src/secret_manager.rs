use anyhow::{anyhow, Context, Result};
use base64::engine::general_purpose::STANDARD as BASE64_STANDARD;
use base64::Engine;
use gcp_auth::AuthenticationManager;
use reqwest::{Client, StatusCode};
use serde::Deserialize;
use serde_json::json;
use std::process::Stdio;
use std::sync::OnceLock;
use tokio::process::Command;
use tracing::warn;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SecretManagerSettings {
    pub scope: String,
    pub endpoint: String,
}

static SETTINGS: OnceLock<SecretManagerSettings> = OnceLock::new();

pub fn configure(settings: SecretManagerSettings) -> Result<()> {
    match SETTINGS.set(settings) {
        Ok(()) => Ok(()),
        Err(settings) => {
            let existing = SETTINGS
                .get()
                .expect("Secret Manager settings should exist after set failure");

            if *existing == settings {
                Ok(())
            } else {
                Err(anyhow!(
                    "Secret Manager settings have already been configured differently"
                ))
            }
        }
    }
}

fn settings() -> &'static SecretManagerSettings {
    SETTINGS
        .get()
        .expect("Secret Manager settings must be configured before use")
}

pub async fn access_secret(resource: &str) -> Result<String> {
    if let Some(secret) = access_secret_via_gcloud(resource).await? {
        return Ok(secret);
    }

    let token = fetch_token().await?;
    let client = Client::new();
    access_secret_with_fallback(&client, &token, resource).await
}

async fn access_secret_with_fallback(
    client: &Client,
    token: &gcp_auth::Token,
    resource: &str,
) -> Result<String> {
    match access_secret_once(client, token, resource).await {
        Ok(secret) => Ok(secret),
        Err(AccessSecretError::NotFound { resource }) => {
            let original_resource = resource.clone();
            let mut gcloud_candidates = Vec::new();

            let maybe_fallback_resource =
                match resolve_latest_version(client, token, &resource).await {
                    Ok(value) => value,
                    Err(err) => {
                        warn!("failed to resolve latest secret version via API: {err:?}");
                        None
                    }
                };

            if let Some(fallback_resource) = maybe_fallback_resource {
                match access_secret_once(client, token, &fallback_resource).await {
                    Ok(secret) => return Ok(secret),
                    Err(AccessSecretError::NotFound {
                        resource: missing_resource,
                    }) => {
                        gcloud_candidates.push(missing_resource);
                    }
                    Err(err) => return Err(err.into_anyhow()),
                }
            }

            gcloud_candidates.push(original_resource.clone());

            for candidate in &gcloud_candidates {
                if let Some(secret) = access_secret_via_gcloud(candidate).await? {
                    return Ok(secret);
                }
            }

            Err(anyhow!(
                "Secret Manager resource `{}` was not found",
                gcloud_candidates
                    .last()
                    .cloned()
                    .unwrap_or(original_resource)
            ))
        }
        Err(err) => Err(err.into_anyhow()),
    }
}

async fn access_secret_once(
    client: &Client,
    token: &gcp_auth::Token,
    resource: &str,
) -> Result<String, AccessSecretError> {
    let url = format!("{}/{}:access", settings().endpoint, resource);

    let response = client
        .post(url)
        .bearer_auth(token.as_str())
        .json(&json!({}))
        .send()
        .await
        .map_err(|err| {
            AccessSecretError::Other(anyhow!("failed to call Secret Manager API: {err}"))
        })?;

    if response.status() == StatusCode::NOT_FOUND {
        return Err(AccessSecretError::NotFound {
            resource: resource.to_string(),
        });
    }

    if !response.status().is_success() {
        let status = response.status();
        let body = response
            .text()
            .await
            .unwrap_or_else(|_| "<unable to read response body>".to_string());
        return Err(AccessSecretError::Other(anyhow!(
            "Secret Manager request failed (status {}): {}",
            status,
            body
        )));
    }

    let body: AccessSecretResponse = response.json().await.map_err(|err| {
        AccessSecretError::Other(anyhow!(
            "failed to deserialize Secret Manager response: {err}"
        ))
    })?;

    let payload = body.payload.and_then(|p| p.data).ok_or_else(|| {
        AccessSecretError::Other(anyhow!("Secret Manager response payload was missing data"))
    })?;

    let decoded = BASE64_STANDARD.decode(payload).map_err(|err| {
        AccessSecretError::Other(anyhow!("failed to base64 decode secret payload: {err}"))
    })?;

    let secret = String::from_utf8(decoded).map_err(|err| {
        AccessSecretError::Other(anyhow!("secret payload is not valid UTF-8: {err}"))
    })?;
    Ok(secret)
}

async fn fetch_token() -> Result<gcp_auth::Token> {
    let manager = AuthenticationManager::new()
        .await
        .context("failed to initialize GCP authentication manager")?;

    manager
        .get_token(&[settings().scope.as_str()])
        .await
        .context("failed to obtain GCP access token")
}

#[derive(Debug, Deserialize)]
struct AccessSecretResponse {
    payload: Option<SecretPayload>,
}

#[derive(Debug, Deserialize)]
struct SecretPayload {
    data: Option<String>,
}

#[derive(Debug)]
enum AccessSecretError {
    NotFound { resource: String },
    Other(anyhow::Error),
}

impl AccessSecretError {
    fn into_anyhow(self) -> anyhow::Error {
        match self {
            AccessSecretError::NotFound { resource } => {
                anyhow!("Secret Manager resource `{}` was not found", resource)
            }
            AccessSecretError::Other(err) => err,
        }
    }
}

async fn resolve_latest_version(
    client: &Client,
    token: &gcp_auth::Token,
    resource: &str,
) -> Result<Option<String>> {
    let Some((secret_path, version_suffix)) = resource.rsplit_once("/versions/") else {
        return Ok(None);
    };

    if version_suffix != "latest" {
        return Ok(None);
    }

    let versions_url = format!("{}/{}/versions", settings().endpoint, secret_path);

    let response = client
        .get(versions_url)
        .bearer_auth(token.as_str())
        .send()
        .await
        .context("failed to list Secret Manager versions")?;

    if response.status() == StatusCode::NOT_FOUND {
        return Ok(None);
    }

    if !response.status().is_success() {
        let status = response.status();
        let body = response
            .text()
            .await
            .unwrap_or_else(|_| "<unable to read response body>".to_string());
        return Err(anyhow!(
            "Secret Manager list versions request failed (status {}): {}",
            status,
            body
        ));
    }

    let body: ListSecretVersionsResponse = response
        .json()
        .await
        .context("failed to deserialize secret versions response")?;

    let latest_enabled = body
        .versions
        .unwrap_or_default()
        .into_iter()
        .filter_map(|version| {
            let state = version.state?;
            if state != "ENABLED" {
                return None;
            }
            let name = version.name?;
            let number = extract_version_number(&name)?;
            Some((number, name))
        })
        .max_by_key(|(number, _)| *number)
        .map(|(_, name)| name);

    Ok(latest_enabled)
}

#[derive(Debug, Deserialize)]
struct ListSecretVersionsResponse {
    versions: Option<Vec<SecretVersion>>,
}

#[derive(Debug, Deserialize)]
struct SecretVersion {
    name: Option<String>,
    state: Option<String>,
}

fn extract_version_number(name: &str) -> Option<u64> {
    let (_, version) = name.rsplit_once("/versions/")?;
    version.parse().ok()
}

async fn access_secret_via_gcloud(resource: &str) -> Result<Option<String>> {
    let Some(parts) = parse_secret_resource(resource) else {
        return Ok(None);
    };

    let mut command = Command::new("gcloud");
    command
        .args([
            "secrets",
            "versions",
            "access",
            &parts.version,
            "--secret",
            &parts.secret,
            "--project",
            &parts.project,
        ])
        .stdout(Stdio::piped())
        .stderr(Stdio::piped());

    match command.output().await {
        Ok(output) if output.status.success() => {
            let secret =
                String::from_utf8(output.stdout).context("gcloud output was not valid UTF-8")?;
            Ok(Some(secret.trim_end_matches(&['\n', '\r'][..]).to_string()))
        }
        Ok(output) => {
            let stderr = String::from_utf8_lossy(&output.stderr);
            warn!(
                "gcloud fallback failed with status {}: {}",
                output.status, stderr
            );
            Ok(None)
        }
        Err(err) => {
            warn!("failed to execute gcloud fallback: {err}");
            Ok(None)
        }
    }
}

struct SecretResourceParts {
    project: String,
    secret: String,
    version: String,
}

fn parse_secret_resource(resource: &str) -> Option<SecretResourceParts> {
    let rest = resource.strip_prefix("projects/")?;
    let (project, rest) = rest.split_once("/secrets/")?;
    let (secret, version) = rest.split_once("/versions/")?;

    Some(SecretResourceParts {
        project: project.to_string(),
        secret: secret.to_string(),
        version: version.to_string(),
    })
}
