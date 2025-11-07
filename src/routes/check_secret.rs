use axum::{extract::State, http::StatusCode};
use tracing::error;

use crate::AppState;

pub async fn check_secret_handler(
    State(state): State<AppState>,
) -> Result<String, (StatusCode, String)> {
    match state.google_secret_suffix(5).await {
        Ok(suffix) => Ok(suffix),
        Err(err) => {
            error!("failed to resolve google-client-secret: {err:?}");
            Err((
                StatusCode::INTERNAL_SERVER_ERROR,
                "failed to load google-client-secret".to_string(),
            ))
        }
    }
}
