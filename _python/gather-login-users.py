#!/usr/bin/env python3
"""
Firestore의 sj-customer2 프로젝트에 있는 sj-customer 컬렉션에서 이번 달에 업데이트된
사용자(userId) 목록을 조회하고, 그 결과를 send_updated_users.out 파일로 저장한다.
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable, List
from google.cloud import firestore
from google.cloud.firestore_v1 import FieldFilter

PROJECT_ID = (
    Path(__file__).resolve().parents[1] / "project_id"
).read_text(encoding="utf-8").strip()
DATABASE_NAME = "sj-customer2"
COLLECTION_NAME = "sj-customer"


@dataclass
class MonthlyChanges:
    start: datetime
    end: datetime

    @classmethod
    def current_month(cls) -> "MonthlyChanges":
        now = datetime.now(timezone.utc)
        start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        # 다음 달 1일 계산
        if start.month == 12:
            next_month = start.replace(year=start.year + 1, month=1)
        else:
            next_month = start.replace(month=start.month + 1)
        return cls(start=start, end=next_month)


def fetch_updated_user_ids(window: MonthlyChanges) -> List[str]:
    client = firestore.Client(project=PROJECT_ID, database=DATABASE_NAME)
    query = client.collection(COLLECTION_NAME).where(
        filter=FieldFilter("updatedAt", ">=", window.start)
    ).where(filter=FieldFilter("updatedAt", "<", window.end))
    return [
        doc.get("userId") or doc.id
        for doc in query.stream()
        if doc.get("userId") or doc.id
    ]


def build_email_body(user_ids: Iterable[str], window: MonthlyChanges) -> str:
    user_ids = list(user_ids)
    user_list = "\n".join(f"- {uid}" for uid in user_ids) or "이번 달 업데이트된 사용자가 없습니다."
    return (
        f"조회 기간: {window.start.isoformat()} ~ {window.end.isoformat()}\n"
        f"총 {len(user_ids)}명\n\n"
        f"{user_list}"
    )


def send_email(subject: str, body: str) -> None:
    """현재 디렉터리에 send_updated_users.out 파일로 저장한다."""
    output_path = Path(__file__).resolve().parent / "send_updated_users.out"
    content = f"{subject}\n\n{body}\n"
    output_path.write_text(content, encoding="utf-8")


def main() -> None:
    window = MonthlyChanges.current_month()
    user_ids = fetch_updated_user_ids(window)
    subject = f"[sj-customer] {window.start.strftime('%Y-%m')} 업데이트된 사용자 목록"
    body = build_email_body(user_ids, window)
    send_email(subject, body)


if __name__ == "__main__":
    main()
