use std::collections::HashMap;
use std::fs;
use std::path::Path;

use anyhow::{anyhow, Context, Result};

#[derive(Debug, Clone)]
pub struct AppConfig {
    pub google_client_id: String,
    pub google_client_secret_source: SecretSource,
    pub google_api_key_source: SecretSource,
    pub gcp_project_id: String,
    pub firestore_scope: String,
    pub firestore_endpoint: String,
    pub firestore_database_id: String,
    pub firestore_collection: String,
    pub secret_manager_scope: String,
    pub secret_manager_endpoint: String,
}

#[derive(Debug, Clone)]
pub enum SecretSource {
    Plain(String),
    SecretManager { resource: String },
}

pub fn load() -> Result<AppConfig> {
    let path = Path::new("config/application.properties");
    let properties = read_properties(path).with_context(|| {
        format!(
            "failed to read application properties from {}",
            path.display()
        )
    })?;

    let google_client_id = read_google_client_id()?;

    let raw_secret = properties
        .get("google-client-secret")
        .cloned()
        .ok_or_else(|| anyhow!("missing `google-client-secret` property"))?;

    let google_client_secret_source = if raw_secret.trim().is_empty() {
        SecretSource::SecretManager {
            resource: default_secret_resource("google-client-secret")?,
        }
    } else {
        parse_secret_source(raw_secret.trim())?
    };

    let raw_api_key = properties
        .get("google-api-key")
        .cloned()
        .unwrap_or_default();

    let google_api_key_source = if raw_api_key.trim().is_empty() {
        SecretSource::SecretManager {
            resource: default_secret_resource("google-api-key")?,
        }
    } else {
        parse_secret_source(raw_api_key.trim())?
    };

    let gcp_project_id = read_project_id()?;
    let firestore_scope = get_required_property(&properties, "firestore-scope")?;
    let firestore_endpoint = get_required_property(&properties, "firestore-endpoint")?;
    let firestore_database_id = get_required_property(&properties, "firestore-database-id")?;
    let firestore_collection = get_required_property(&properties, "firestore-collection")?;
    let secret_manager_scope = get_required_property(&properties, "secret-manager-scope")?;
    let secret_manager_endpoint = get_required_property(&properties, "secret-manager-endpoint")?;

    Ok(AppConfig {
        google_client_id,
        google_client_secret_source,
        google_api_key_source,
        gcp_project_id,
        firestore_scope,
        firestore_endpoint,
        firestore_database_id,
        firestore_collection,
        secret_manager_scope,
        secret_manager_endpoint,
    })
}

fn read_properties(path: &Path) -> Result<HashMap<String, String>> {
    let content = fs::read_to_string(path)?;
    let mut map = HashMap::new();

    for (idx, line) in content.lines().enumerate() {
        let trimmed = line.trim();

        if trimmed.is_empty() || trimmed.starts_with('#') || trimmed.starts_with("!") {
            continue;
        }

        let Some((key, value)) = trimmed.split_once('=') else {
            return Err(anyhow!(
                "failed to parse properties line {}: `{}`",
                idx + 1,
                line
            ));
        };

        map.insert(key.trim().to_string(), value.trim().to_string());
    }

    Ok(map)
}

fn parse_secret_source(trimmed: &str) -> Result<SecretSource> {
    if trimmed.is_empty() {
        return Err(anyhow!("secret value cannot be empty"));
    }

    if let Some(resource) = trimmed.strip_prefix("secretmanager:") {
        let normalized = normalize_secret_resource(resource.trim())?;
        Ok(SecretSource::SecretManager {
            resource: normalized,
        })
    } else {
        Ok(SecretSource::Plain(trimmed.to_string()))
    }
}

fn normalize_secret_resource(resource: &str) -> Result<String> {
    let cleaned = resource.trim_start_matches('/');

    if cleaned.is_empty() {
        return Err(anyhow!("Secret Manager resource cannot be empty"));
    }

    if cleaned.contains("/versions/") {
        Ok(cleaned.to_string())
    } else {
        Ok(format!("{}/versions/latest", cleaned.trim_end_matches('/')))
    }
}

fn get_required_property(map: &HashMap<String, String>, key: &str) -> Result<String> {
    let value = map
        .get(key)
        .cloned()
        .ok_or_else(|| anyhow!("missing `{}` property", key))?;

    if value.is_empty() {
        Err(anyhow!("`{}` property cannot be empty", key))
    } else {
        Ok(value)
    }
}

fn default_secret_resource(secret_name: &str) -> Result<String> {
    let project_id = read_project_id()?;
    Ok(format!(
        "projects/{}/secrets/{}/versions/latest",
        project_id, secret_name
    ))
}

fn read_google_client_id() -> Result<String> {
    let path = Path::new("google-client-id");
    let content = fs::read_to_string(path).with_context(|| {
        format!(
            "failed to read google client id from {}",
            path.display()
        )
    })?;

    let trimmed = content.trim();

    if trimmed.is_empty() {
        return Err(anyhow!("google-client-id file cannot be empty"));
    }

    Ok(trimmed.to_string())
}

fn read_project_id() -> Result<String> {
    let path = Path::new("project_id");
    let content = fs::read_to_string(path).with_context(|| {
        format!(
            "failed to read default project id from {}",
            path.display()
        )
    })?;

    let trimmed = content.trim();

    if trimmed.is_empty() {
        return Err(anyhow!("project_id file cannot be empty"));
    }

    Ok(trimmed.to_string())
}
