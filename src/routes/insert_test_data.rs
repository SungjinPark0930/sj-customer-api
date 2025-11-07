use axum::{extract::State, http::StatusCode, Json};
use tracing::{error, info};

use crate::{AppState, InsertTestDataResponse};

pub async fn insert_test_data_handler(
    State(state): State<AppState>,
) -> Result<Json<InsertTestDataResponse>, (StatusCode, String)> {
    info!("received request to insert Firestore test data document");

    match state.insert_test_document().await {
        Ok(response) => Ok(Json(response)),
        Err(err) => {
            error!("failed to insert Firestore test document: {err:?}");
            Err((
                StatusCode::INTERNAL_SERVER_ERROR,
                "failed to insert test data document".to_string(),
            ))
        }
    }
}
