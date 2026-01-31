#!/usr/bin/env python3
"""
학습 데이터 레이블링을 위한 스크립트
DynamoDB의 incident에 changeType을 자동 또는 수동으로 추가합니다.
"""
import sys
import re
import boto3
from datetime import datetime
import pytz
from typing import Optional, Dict, List, Tuple, Set
from data_loader import JiraDataLoader
from config import (
    AWS_REGION,
    DYNAMODB_TABLE_NAME,
    CHANGE_TYPES
)


def load_metadata_from_dynamodb(profile_name='AUTO', region_name='ap-northeast-2'):
    """
    DynamoDB에서 메타데이터를 로드하여 전역 변수에 할당

    Returns:
        bool: 로드 성공 여부
    """
    try:
        session = boto3.Session(profile_name=profile_name)
        dynamodb = session.resource('dynamodb', region_name=region_name)
        metadata_table = dynamodb.Table('impactanalysis-metadata')

        print("Loading metadata from DynamoDB...")

        # 전역 변수 선언
        global LABEL_KEYWORDS, CHANGE_TYPE_RISK_SCORES, HIGH_RISK_KEYWORDS
        global HIGH_RISK_COMPONENTS, NORMAL_COMPONENT_RISK_SCORE
        global COMMENT_RISK_KEYWORDS, HIGH_RISK_SERVICE_KEYWORDS

        # 1. LABEL_KEYWORDS 로드
        label_keywords_loaded = {}
        label_keys = [
            'feature_new', 'feature_api', 'feature_ui', 'feature_batch', 'feature_data',
            'bugfix_critical', 'bugfix_data', 'bugfix_ui', 'bugfix_logic', 'bugfix_minor',
            'enhancement_ux', 'enhancement_logic', 'enhancement_data',
            'performance_query', 'performance_api', 'performance_batch',
            'config_infra', 'config_env', 'config_remove', 'config_decommission',
            'upgrade_db', 'upgrade_platform', 'upgrade_jdk', 'upgrade_eks',
            'security_auth', 'security_data', 'security_patch',
            'refactoring', 'text_change', 'other'
        ]

        for key in label_keys:
            data_id = f"LABEL_KEYWORDS#{key}"
            try:
                response = metadata_table.get_item(Key={'dataId': data_id})
                if 'Item' in response:
                    metadata = response['Item'].get('metadata', '')
                    label_keywords_loaded[key] = metadata.split('|') if metadata else []
                else:
                    print(f"  Warning: {data_id} not found, using default values")
                    label_keywords_loaded[key] = LABEL_KEYWORDS.get(key, [])
            except Exception as e:
                print(f"  Warning: Failed to load {data_id}: {e}")
                label_keywords_loaded[key] = LABEL_KEYWORDS.get(key, [])

        LABEL_KEYWORDS = label_keywords_loaded
        print(f"  ✓ Loaded LABEL_KEYWORDS ({len(LABEL_KEYWORDS)} categories)")

        # 2. CHANGE_TYPE_RISK_SCORES 로드
        try:
            response = metadata_table.get_item(Key={'dataId': 'CHANGE_TYPE_RISK_SCORES'})
            if 'Item' in response:
                metadata = response['Item'].get('metadata', '')
                risk_scores_dict = {}
                for item in metadata.split('|'):
                    if ':' in item:
                        k, v = item.split(':', 1)
                        risk_scores_dict[k] = int(v)
                CHANGE_TYPE_RISK_SCORES = risk_scores_dict
                print(f"  ✓ Loaded CHANGE_TYPE_RISK_SCORES ({len(CHANGE_TYPE_RISK_SCORES)} entries)")
            else:
                print("  Warning: CHANGE_TYPE_RISK_SCORES not found, using default values")
        except Exception as e:
            print(f"  Warning: Failed to load CHANGE_TYPE_RISK_SCORES: {e}")

        # 3. HIGH_RISK_KEYWORDS 로드
        try:
            response = metadata_table.get_item(Key={'dataId': 'HIGH_RISK_KEYWORDS'})
            if 'Item' in response:
                metadata = response['Item'].get('metadata', '')
                high_risk_dict = {}
                for item in metadata.split('|'):
                    if ':' in item:
                        k, v = item.split(':', 1)
                        high_risk_dict[k] = int(v)
                HIGH_RISK_KEYWORDS = high_risk_dict
                print(f"  ✓ Loaded HIGH_RISK_KEYWORDS ({len(HIGH_RISK_KEYWORDS)} keywords)")
            else:
                print("  Warning: HIGH_RISK_KEYWORDS not found, using default values")
        except Exception as e:
            print(f"  Warning: Failed to load HIGH_RISK_KEYWORDS: {e}")

        # 4. HIGH_RISK_COMPONENTS 로드
        try:
            response = metadata_table.get_item(Key={'dataId': 'HIGH_RISK_COMPONENTS'})
            if 'Item' in response:
                metadata = response['Item'].get('metadata', '')
                HIGH_RISK_COMPONENTS = set(metadata.split('|')) if metadata else set()
                print(f"  ✓ Loaded HIGH_RISK_COMPONENTS ({len(HIGH_RISK_COMPONENTS)} components)")
            else:
                print("  Warning: HIGH_RISK_COMPONENTS not found, using default values")
        except Exception as e:
            print(f"  Warning: Failed to load HIGH_RISK_COMPONENTS: {e}")

        # 5. NORMAL_COMPONENT_RISK_SCORE 로드
        try:
            response = metadata_table.get_item(Key={'dataId': 'NORMAL_COMPONENT_RISK_SCORE'})
            if 'Item' in response:
                metadata = response['Item'].get('metadata', '')
                NORMAL_COMPONENT_RISK_SCORE = int(metadata) if metadata else 2
                print(f"  ✓ Loaded NORMAL_COMPONENT_RISK_SCORE (value: {NORMAL_COMPONENT_RISK_SCORE})")
            else:
                print("  Warning: NORMAL_COMPONENT_RISK_SCORE not found, using default values")
        except Exception as e:
            print(f"  Warning: Failed to load NORMAL_COMPONENT_RISK_SCORE: {e}")

        # 6. COMMENT_RISK_KEYWORDS 로드
        try:
            response = metadata_table.get_item(Key={'dataId': 'COMMENT_RISK_KEYWORDS'})
            if 'Item' in response:
                metadata = response['Item'].get('metadata', '')
                COMMENT_RISK_KEYWORDS = metadata.split('|') if metadata else []
                print(f"  ✓ Loaded COMMENT_RISK_KEYWORDS ({len(COMMENT_RISK_KEYWORDS)} keywords)")
            else:
                print("  Warning: COMMENT_RISK_KEYWORDS not found, using default values")
        except Exception as e:
            print(f"  Warning: Failed to load COMMENT_RISK_KEYWORDS: {e}")

        # 7. HIGH_RISK_SERVICE_KEYWORDS 로드
        try:
            response = metadata_table.get_item(Key={'dataId': 'HIGH_RISK_SERVICE_KEYWORDS'})
            if 'Item' in response:
                metadata = response['Item'].get('metadata', '')
                HIGH_RISK_SERVICE_KEYWORDS = metadata.split('|') if metadata else []
                print(f"  ✓ Loaded HIGH_RISK_SERVICE_KEYWORDS ({len(HIGH_RISK_SERVICE_KEYWORDS)} keywords)")
            else:
                print("  Warning: HIGH_RISK_SERVICE_KEYWORDS not found, using default values")
        except Exception as e:
            print(f"  Warning: Failed to load HIGH_RISK_SERVICE_KEYWORDS: {e}")

        print("Metadata loaded successfully from DynamoDB.\n")
        return True

    except Exception as e:
        print(f"Error loading metadata from DynamoDB: {e}")
        print("Using default hardcoded values.\n")
        return False


# 변경 유형별 키워드 매핑 (세분화) - DynamoDB 저장
LABEL_KEYWORDS = ""

class RiskCalculator:
    """위험평가점수 계산기"""

    _incident_risk_stats = None
    _incident_issue_keys = []

    @classmethod
    def load_incident_risk_stats(cls):
        """과거 장애 발생 통계 로드 (DynamoDB에서)"""
        if cls._incident_risk_stats is None:
            import json
            import boto3

            # 1. DynamoDB에서 incident 이력 로드 시도
            try:
                session = boto3.Session(profile_name='AUTO')
                dynamodb = session.resource('dynamodb', region_name='ap-northeast-2')
                metadata_table = dynamodb.Table('impactanalysis-metadata')

                response = metadata_table.get_item(Key={'dataId': 'INCIDENT#HISTORY'})

                if 'Item' in response:
                    incident_history = response['Item'].get('metadata', '')
                    incident_issue_keys = incident_history.split('|') if incident_history else []

                    print(f"Loaded incident history from DynamoDB: {len(incident_issue_keys)} incidents")

                    # issue_key 리스트를 저장 (나중에 사용 가능)
                    cls._incident_issue_keys = incident_issue_keys

                    # 백업 파일도 로드 (changeType별 통계용)
                    stats_path = '/app/impactanalysis/kor-impactanalysis/ml/models/incident_risk_stats.json'
                    try:
                        with open(stats_path, 'r', encoding='utf-8') as f:
                            cls._incident_risk_stats = json.load(f)
                    except:
                        cls._incident_risk_stats = {}
                else:
                    print("Warning: INCIDENT#HISTORY not found in DynamoDB")
                    print("Run train.py first to generate incident statistics.")
                    cls._incident_risk_stats = {}
                    cls._incident_issue_keys = []

            except Exception as e:
                print(f"Warning: Failed to load from DynamoDB: {e}")

                # 2. Fallback: 로컬 파일에서 로드
                stats_path = '/app/impactanalysis/kor-impactanalysis/ml/models/incident_risk_stats.json'
                try:
                    with open(stats_path, 'r', encoding='utf-8') as f:
                        cls._incident_risk_stats = json.load(f)
                    print(f"Fallback: Loaded incident risk statistics from {stats_path}")
                    cls._incident_issue_keys = []
                except FileNotFoundError:
                    print(f"Warning: Incident risk stats not found at {stats_path}")
                    print("Run train.py first to generate incident statistics.")
                    cls._incident_risk_stats = {}
                    cls._incident_issue_keys = []
                except Exception as e2:
                    print(f"Warning: Failed to load incident risk stats: {e2}")
                    cls._incident_risk_stats = {}
                    cls._incident_issue_keys = []

        return cls._incident_risk_stats

    @classmethod
    def get_incident_issue_keys(cls) -> List[str]:
        """
        과거 incident 발생한 issue_key 리스트 반환

        Returns:
            List[str]: incident 발생 issue_key 리스트
        """
        if cls._incident_risk_stats is None:
            cls.load_incident_risk_stats()
        return cls._incident_issue_keys

    @classmethod
    def calculate_comment_risk_score(cls, comments: List[Dict]) -> int:
        """
        댓글 기반 위험도 점수 계산

        Args:
            comments: JIRA 댓글 리스트

        Returns:
            int: 0-10점 (고위험키워드 60% = 6점, 댓글수 40% = 4점)
        """
        if not comments:
            return 0

        score = 0

        # 1. 댓글 수 기반 점수 (40% = 4점)
        comment_count = len(comments)
        if comment_count >= 15:
            score += 4  # 15개 이상
        elif comment_count >= 10:
            score += 3  # 10-14개
        elif comment_count >= 5:
            score += 2  # 5-9개
        elif comment_count >= 3:
            score += 1  # 3-4개
        # else: 2개 이하 = 0점

        # 2. 고위험 키워드 기반 점수 (60% = 6점)
        keyword_count = 0
        for comment in comments:
            body = comment.get('body', '').lower()
            for keyword in COMMENT_RISK_KEYWORDS:
                if keyword.lower() in body:
                    keyword_count += 1

        # 키워드 1개당 1점, 최대 6점
        keyword_score = min(6, keyword_count)
        score += keyword_score

        return min(10, score)  # 최대 10점

    @classmethod
    def calculate_risk_score(
        cls,
        change_type: str,
        summary: str,
        description: str,
        components: List[str] = None,
        comments: List[Dict] = None
    ) -> int:
        """
        위험평가점수 계산

        Args:
            change_type: 변경 유형
            summary: JIRA 요약
            description: JIRA 상세 설명
            components: JIRA 컴포넌트 리스트
            comments: JIRA 댓글 리스트

        Returns:
            int: 위험평가점수 (0-100)

        계산 요소:
            1. base_score: changeType별 기본 점수 (3-85점)
            2. keyword_score: 고위험 키워드 (+5~20점)
            3. incident_score: 과거 장애 발생률 (0-30점)
            4. component_score: 컴포넌트별 가중치 (+2~5점)
            5. comment_score: 댓글 기반 위험도 (0-10점)
            6. service_score: 특정 서비스 키워드 (+2점)

        총점 = base_score + keyword_score + incident_score + component_score + comment_score + service_score
        """
        # 1. 변경 유형별 기본 점수
        base_score = CHANGE_TYPE_RISK_SCORES.get(change_type, 50)

        # 2. 고위험 키워드 검사
        text = f"{summary or ''} {description or ''}".lower()
        keyword_score = 0

        for keyword, score_add in HIGH_RISK_KEYWORDS.items():
            if keyword.lower() in text:
                keyword_score += score_add

        # 3. 과거 장애 발생 이력 기반 점수 추가
        incident_stats = cls.load_incident_risk_stats()
        incident_score = 0

        if change_type in incident_stats:
            incident_rate = incident_stats[change_type].get('incident_rate', 0.0)
            # 장애 발생 비율에 따라 0~30점 추가
            # 예: 50% 장애율 -> +15점, 100% 장애율 -> +30점
            incident_score = int(incident_rate * 30)

        # 4. 컴포넌트 기반 위험도 점수
        component_score = 0
        if components:
            for component in components:
                component_lower = component.lower()
                if component_lower in HIGH_RISK_COMPONENTS:
                    component_score += 5
                else:
                    component_score += NORMAL_COMPONENT_RISK_SCORE

        # 5. 댓글 기반 위험도 점수 (최대 10점)
        comment_score = cls.calculate_comment_risk_score(comments) if comments else 0

        # 6. 특정 서비스 키워드 기반 위험도 점수 (+2점)
        service_score = 0
        text_original = f"{summary or ''} {description or ''}"  # 대소문자 구분을 위해 원본 텍스트 사용
        for service_keyword in HIGH_RISK_SERVICE_KEYWORDS:
            if service_keyword in text_original:
                service_score = 2
                break  # 하나라도 매칭되면 2점 추가

        # 7. 총 점수 계산
        total_score = base_score + keyword_score + incident_score + component_score + comment_score + service_score

        # 8. 0-100 범위로 제한
        final_score = min(100, max(0, total_score))

        return final_score


class AutoLabeler:
    """자동 레이블링 엔진"""

    def __init__(self):
        self.keyword_patterns = self._compile_patterns()

    def _compile_patterns(self) -> Dict[str, List[re.Pattern]]:
        """키워드를 정규식 패턴으로 컴파일"""
        patterns = {}
        for label, keywords in LABEL_KEYWORDS.items():
            patterns[label] = [
                re.compile(r'\b' + re.escape(kw) + r'\b', re.IGNORECASE)
                for kw in keywords
            ]
        return patterns

    def predict_label(
        self,
        summary: str,
        description: str,
        threshold: float = 0.3
    ) -> Optional[Tuple[str, float, List[str]]]:
        """
        summary와 description을 기반으로 자동 레이블 예측

        Args:
            summary: JIRA 티켓 요약
            description: JIRA 티켓 상세 설명
            threshold: 최소 신뢰도 임계값

        Returns:
            (label, confidence, matched_keywords) 또는 None
        """
        if not summary and not description:
            return None

        # Summary와 Description 분리 (가중치를 다르게 적용하기 위해)
        summary_lower = (summary or '').lower()
        description_lower = (description or '').lower()

        # 각 레이블별 점수 계산
        scores = {}
        matched_keywords_by_label = {}

        for label, patterns in self.keyword_patterns.items():
            matched = []
            score = 0

            for pattern in patterns:
                # Summary에서 매칭 (가중치 2배)
                summary_matches = pattern.findall(summary_lower)
                if summary_matches:
                    matched.extend(summary_matches)
                    score += len(summary_matches) * 2  # Summary는 2배 가중치

                # Description에서 매칭 (가중치 1배)
                description_matches = pattern.findall(description_lower)
                if description_matches:
                    matched.extend(description_matches)
                    score += len(description_matches)  # Description는 1배 가중치

            if matched:
                scores[label] = score
                matched_keywords_by_label[label] = list(set(matched))

        if not scores:
            return None

        # 가장 높은 점수의 레이블 선택
        best_label = max(scores, key=scores.get)
        max_score = scores[best_label]

        # 총 매칭 수 대비 신뢰도 계산
        total_score = sum(scores.values())
        confidence = max_score / total_score if total_score > 0 else 0

        # 임계값 이상일 때만 반환
        if confidence >= threshold:
            matched_kw = matched_keywords_by_label[best_label]
            return best_label, confidence, matched_kw

        return None

    def predict_top_labels(
        self,
        summary: str,
        description: str,
        top_k: int = 3
    ) -> List[Tuple[str, float, List[str]]]:
        """
        상위 K개의 레이블 후보 반환

        Args:
            summary: JIRA 티켓 요약
            description: JIRA 티켓 상세 설명
            top_k: 반환할 후보 개수

        Returns:
            [(label, confidence, matched_keywords), ...] 리스트
        """
        if not summary and not description:
            return []

        # Summary와 Description 분리 (가중치를 다르게 적용하기 위해)
        summary_lower = (summary or '').lower()
        description_lower = (description or '').lower()

        scores = {}
        matched_keywords_by_label = {}

        for label, patterns in self.keyword_patterns.items():
            matched = []
            score = 0

            for pattern in patterns:
                # Summary에서 매칭 (가중치 2배)
                summary_matches = pattern.findall(summary_lower)
                if summary_matches:
                    matched.extend(summary_matches)
                    score += len(summary_matches) * 2

                # Description에서 매칭 (가중치 1배)
                description_matches = pattern.findall(description_lower)
                if description_matches:
                    matched.extend(description_matches)
                    score += len(description_matches)

            if matched:
                scores[label] = score
                matched_keywords_by_label[label] = list(set(matched))

        if not scores:
            return []

        # 점수 순으로 정렬
        sorted_labels = sorted(scores.items(), key=lambda x: x[1], reverse=True)

        # 신뢰도 계산
        total_score = sum(scores.values())
        results = []

        for label, score in sorted_labels[:top_k]:
            confidence = score / total_score
            matched_kw = matched_keywords_by_label[label]
            results.append((label, confidence, matched_kw))

        return results


class DataLabeler:
    """데이터 레이블링 도구"""

    def __init__(self, auto_mode: bool = False):
        """
        Args:
            auto_mode: True이면 자동 레이블링, False이면 수동 레이블링
        """
        self.loader = JiraDataLoader()
        session = boto3.Session(profile_name='AUTO')
        self.dynamodb = session.resource('dynamodb', region_name=AWS_REGION)
        self.table = self.dynamodb.Table(DYNAMODB_TABLE_NAME)
        self.auto_labeler = AutoLabeler()
        self.auto_mode = auto_mode

    def get_unlabeled_tickets(self):
        """레이블이 없는 티켓 가져오기"""
        # 모든 incident issue keys
        all_issue_keys = self.loader.get_incident_issue_keys()

        # 이미 레이블된 issue keys
        labeled_keys = set(self.loader.get_existing_change_types().keys())

        # 레이블이 없는 issue keys
        unlabeled_keys = [key for key in all_issue_keys if key not in labeled_keys]

        return unlabeled_keys

    def update_riskpoints_for_labeled_tickets(self, reclassify=False):
        """
        이미 changeType이 있는 티켓들의 riskpoint를 재계산하여 업데이트

        Args:
            reclassify: True이면 세분화된 changeType으로 재분류
        """
        # changeType이 있는 티켓들 가져오기
        change_types = self.loader.get_existing_change_types()

        if not change_types:
            print("No labeled tickets found.")
            return

        if reclassify:
            print(f"\nReclassifying and updating {len(change_types)} labeled tickets to detailed changeTypes...")
        else:
            print(f"\nUpdating riskpoint for {len(change_types)} labeled tickets...")

        updated_count = 0
        reclassified_count = 0
        failed_count = 0
        changed_risks = []  # 변경된 riskpoint 추적

        for idx, (issue_key, old_change_type) in enumerate(change_types.items(), 1):
            # 티켓 정보 가져오기
            ticket = self.loader.get_jira_ticket_from_dynamodb(issue_key)

            if not ticket:
                print(f"  [{idx}/{len(change_types)}] {issue_key}: Ticket not found in DynamoDB")
                failed_count += 1
                continue

            summary = ticket.get('summary', '')
            description = ticket.get('description', '')
            components = ticket.get('components', [])
            comments = ticket.get('comments', [])
            old_risk_score = ticket.get('riskpoint', 0)  # 기존 riskpoint

            # 세분화된 changeType으로 재분류
            new_change_type = old_change_type
            if reclassify:
                prediction = self.auto_labeler.predict_label(
                    summary, description, threshold=0.2
                )
                if prediction:
                    predicted_label, confidence, matched_kw = prediction
                    new_change_type = predicted_label
                    if new_change_type != old_change_type:
                        reclassified_count += 1

            # 위험평가점수 재계산 (comments 포함)
            new_risk_score = RiskCalculator.calculate_risk_score(
                new_change_type, summary, description, components, comments
            )

            # riskpoint 변경 여부 확인
            risk_changed = (old_risk_score != new_risk_score)

            # changeType과 riskpoint 업데이트
            try:
                # updatedAt 생성 (KST 타임존)
                kst = pytz.timezone('Asia/Seoul')
                now_kst = datetime.now(kst)
                updated_at = now_kst.strftime('%Y-%m-%d %H:%M')

                if reclassify and new_change_type != old_change_type:
                    # changeType도 함께 업데이트
                    self.table.update_item(
                        Key={'dataId': issue_key},
                        UpdateExpression='SET changeType = :ct, riskpoint = :riskpoint, updatedAt = :updated',
                        ExpressionAttributeValues={
                            ':ct': new_change_type,
                            ':riskpoint': new_risk_score,
                            ':updated': updated_at
                        }
                    )
                    print(f"  [{idx}/{len(change_types)}] {issue_key}: {old_change_type} -> {new_change_type} (risk: {old_risk_score} -> {new_risk_score})")
                else:
                    # riskpoint만 업데이트
                    self.table.update_item(
                        Key={'dataId': issue_key},
                        UpdateExpression='SET riskpoint = :riskpoint, updatedAt = :updated',
                        ExpressionAttributeValues={
                            ':riskpoint': new_risk_score,
                            ':updated': updated_at
                        }
                    )
                    if risk_changed:
                        print(f"  [{idx}/{len(change_types)}] {issue_key}: {new_change_type} -> risk: {old_risk_score} -> {new_risk_score}")
                    else:
                        print(f"  [{idx}/{len(change_types)}] {issue_key}: {new_change_type} -> risk: {new_risk_score} (no change)")

                updated_count += 1

                # 변경된 경우 추적
                if risk_changed:
                    changed_risks.append({
                        'issue_key': issue_key,
                        'summary': summary[:80] if len(summary) <= 80 else summary[:77] + '...',
                        'change_type': new_change_type,
                        'old_risk': old_risk_score,
                        'new_risk': new_risk_score,
                        'diff': new_risk_score - old_risk_score
                    })

            except Exception as e:
                print(f"  [{idx}/{len(change_types)}] {issue_key}: Failed to update - {e}")
                failed_count += 1

        print(f"\nUpdate completed:")
        print(f"  Updated: {updated_count} tickets")
        if reclassify:
            print(f"  Reclassified: {reclassified_count} tickets")
        print(f"  Failed: {failed_count} tickets")

        # 변경된 riskpoint 요약 출력
        if changed_risks:
            print(f"\n{'=' * 80}")
            print(f"Changed Risk Scores Summary ({len(changed_risks)} tickets)")
            print(f"{'=' * 80}")

            # 변경폭이 큰 순서로 정렬
            changed_risks.sort(key=lambda x: abs(x['diff']), reverse=True)

            for item in changed_risks:
                diff_str = f"+{item['diff']}" if item['diff'] > 0 else str(item['diff'])
                print(f"\n  {item['issue_key']}")
                print(f"    Summary: {item['summary']}")
                print(f"    ChangeType: {item['change_type']}")
                print(f"    Risk: {item['old_risk']} -> {item['new_risk']} ({diff_str})")

            print(f"\n{'=' * 80}")
        else:
            print(f"\n  No risk score changes detected.")

    def save_label(self, issue_key: str, change_type: str, ticket: Dict = None) -> bool:
        """
        DynamoDB에 레이블 및 티켓 정보 저장

        Args:
            issue_key: JIRA 이슈 키
            change_type: 변경 유형
            ticket: JIRA 티켓 정보 (summary, description, status 포함)

        Returns:
            bool: 성공 여부
        """
        try:
            # updatedAt 생성 (KST 타임존)
            kst = pytz.timezone('Asia/Seoul')
            now_kst = datetime.now(kst)
            updated_at = now_kst.strftime('%Y-%m-%d %H:%M')

            # 기본 업데이트: changeType
            update_expression = 'SET changeType = :ct'
            expression_values = {':ct': change_type}

            # 위험평가점수 계산
            risk_score = 50  # 기본값
            if ticket:
                summary = ticket.get('summary', '')
                description = ticket.get('description', '')
                components = ticket.get('components', [])
                comments = ticket.get('comments', [])
                risk_score = RiskCalculator.calculate_risk_score(
                    change_type, summary, description, components, comments
                )

            # riskpoint 추가
            update_expression += ', riskpoint = :riskpoint'
            expression_values[':riskpoint'] = risk_score

            # updatedAt 추가
            update_expression += ', updatedAt = :updated'
            expression_values[':updated'] = updated_at

            # ticket 정보가 있으면 추가 필드도 업데이트
            if ticket:
                if 'summary' in ticket and ticket['summary']:
                    update_expression += ', summary = :summary'
                    expression_values[':summary'] = ticket['summary']

                if 'description' in ticket and ticket['description']:
                    update_expression += ', description = :desc'
                    expression_values[':desc'] = ticket['description']

                if 'status' in ticket and ticket['status']:
                    update_expression += ', #status = :status'
                    expression_values[':status'] = ticket['status']

            # DynamoDB 업데이트
            update_kwargs = {
                'Key': {'dataId': issue_key},
                'UpdateExpression': update_expression,
                'ExpressionAttributeValues': expression_values
            }

            # status는 예약어이므로 ExpressionAttributeNames 필요
            if ticket and 'status' in ticket and ticket['status']:
                update_kwargs['ExpressionAttributeNames'] = {'#status': 'status'}

            self.table.update_item(**update_kwargs)
            return True
        except Exception as e:
            print(f"Error saving label: {e}")
            return False

    def print_ticket_info(self, ticket):
        """티켓 정보 출력"""
        print("\n" + "=" * 80)
        print(f"Issue Key: {ticket.get('issue_key')}")
        print("=" * 80)
        print(f"\nCreated: {ticket.get('created', 'N/A')}")
        print(f"Status: {ticket.get('status', 'N/A')}")
        print(f"\nSummary:\n{ticket.get('summary', 'N/A')}")
        print(f"\nDescription:\n{ticket.get('description', 'N/A')[:300]}...")
        print(f"\nComponents: {', '.join(ticket.get('components', []))}")
        print(f"Sprint: {ticket.get('sprint', 'N/A')}")
        print("=" * 80)

    def print_change_types_menu(self):
        """변경 유형 메뉴 출력"""
        print("\nAvailable Change Types:")
        for idx, change_type in enumerate(CHANGE_TYPES, 1):
            print(f"  {idx}. {change_type}")
        print(f"  s. Skip this ticket")
        print(f"  q. Quit")

    def auto_labeling(self, confidence_threshold: float = 0.4, confirm: bool = True):
        """
        자동 레이블링 (키워드 기반)

        Args:
            confidence_threshold: 자동 레이블링 최소 신뢰도
            confirm: True이면 사용자 확인 후 저장, False이면 자동 저장
        """
        unlabeled_keys = self.get_unlabeled_tickets()

        if not unlabeled_keys:
            print("No unlabeled tickets found. All incidents are already labeled!")
            return

        print(f"\nFound {len(unlabeled_keys)} unlabeled tickets.")
        print(f"Auto-labeling with confidence threshold: {confidence_threshold:.2f}")
        print(f"Confirmation mode: {'ON' if confirm else 'OFF'}\n")

        labeled_count = 0
        skipped_count = 0
        labeled_tickets = []  # 레이블링된 티켓 정보 추적

        for idx, issue_key in enumerate(unlabeled_keys, 1):
            ticket = self.loader.get_jira_ticket_from_dynamodb(issue_key)
            if not ticket:
                print(f"Warning: Ticket not found in DynamoDB: {issue_key}")
                skipped_count += 1
                continue

            summary = ticket.get('summary', '')
            description = ticket.get('description', '')

            # 자동 레이블 예측
            prediction = self.auto_labeler.predict_label(
                summary, description, threshold=confidence_threshold
            )

            if not prediction:
                # 예측 실패 - 수동 레이블링으로 전환
                print(f"\n[{idx}/{len(unlabeled_keys)}] {issue_key}")
                print(f"  Summary: {summary[:80] if len(summary) <= 80 else summary[:77] + '...'}")
                if description:
                    desc_preview = description[:150] if len(description) <= 150 else description[:147] + '...'
                    print(f"  Description: {desc_preview}")
                print("  → No confident prediction. Manual labeling required.")

                if confirm:
                    self.manual_label_single_ticket(ticket)
                    labeled_count += 1
                else:
                    skipped_count += 1
                continue

            predicted_label, confidence, matched_keywords = prediction

            # 위험평가점수 계산
            components = ticket.get('components', [])
            comments = ticket.get('comments', [])
            risk_score = RiskCalculator.calculate_risk_score(
                predicted_label, summary, description, components, comments
            )

            print(f"\n[{idx}/{len(unlabeled_keys)}] {issue_key}")
            print(f"  Summary: {summary[:80] if len(summary) <= 80 else summary[:77] + '...'}")
            if description:
                desc_preview = description[:150] if len(description) <= 150 else description[:147] + '...'
                print(f"  Description: {desc_preview}")
            print(f"  → Predicted: {predicted_label} (confidence: {confidence:.2f})")
            print(f"  → Risk Score: {risk_score}/100")
            print(f"  → Matched keywords: {', '.join(matched_keywords[:5])}")

            # 확인 모드
            if confirm:
                choice = input("  Accept? (y/n/m=manual/s=skip/q=quit): ").strip().lower()

                if choice == 'q':
                    print(f"\nLabeled {labeled_count} tickets. Exiting...")
                    return
                elif choice == 's':
                    print("  Skipped.")
                    skipped_count += 1
                    continue
                elif choice == 'm':
                    # 수동 레이블링
                    self.manual_label_single_ticket(ticket)
                    labeled_count += 1
                    continue
                elif choice != 'y':
                    print("  Skipped (invalid input).")
                    skipped_count += 1
                    continue

            # 저장
            if self.save_label(issue_key, predicted_label, ticket):
                print(f"  ✓ Saved: {issue_key} -> {predicted_label} (risk: {risk_score}/100)")
                labeled_count += 1

                # 레이블링된 티켓 정보 추적
                labeled_tickets.append({
                    'issue_key': issue_key,
                    'summary': summary[:80] if len(summary) <= 80 else summary[:77] + '...',
                    'change_type': predicted_label,
                    'risk_score': risk_score
                })
            else:
                print(f"  ✗ Failed to save.")
                skipped_count += 1

        print(f"\n{'=' * 80}")
        print(f"Auto-labeling completed!")
        print(f"  Labeled: {labeled_count} tickets")
        print(f"  Skipped: {skipped_count} tickets")
        print(f"{'=' * 80}")

        # 레이블링된 티켓 요약 출력
        if labeled_tickets:
            print(f"\n{'=' * 80}")
            print(f"Newly Labeled Tickets Summary ({len(labeled_tickets)} tickets)")
            print(f"{'=' * 80}")

            # 위험점수가 높은 순서로 정렬
            labeled_tickets.sort(key=lambda x: x['risk_score'], reverse=True)

            for item in labeled_tickets:
                print(f"\n  {item['issue_key']}")
                print(f"    Summary: {item['summary']}")
                print(f"    ChangeType: {item['change_type']}")
                print(f"    Risk Score: {item['risk_score']}/100")

            print(f"\n{'=' * 80}")

    def manual_label_single_ticket(self, ticket):
        """단일 티켓 수동 레이블링"""
        issue_key = ticket.get('issue_key')
        self.print_ticket_info(ticket)

        # 자동 레이블 후보 제시
        summary = ticket.get('summary', '')
        description = ticket.get('description', '')
        components = ticket.get('components', [])
        comments = ticket.get('comments', [])
        top_predictions = self.auto_labeler.predict_top_labels(summary, description, top_k=3)

        if top_predictions:
            print("\n  Auto-prediction suggestions:")
            for i, (label, conf, keywords) in enumerate(top_predictions, 1):
                risk = RiskCalculator.calculate_risk_score(label, summary, description, components, comments)
                print(f"    {i}. {label} (confidence: {conf:.2f}, risk: {risk}/100) - {', '.join(keywords[:3])}")

        while True:
            self.print_change_types_menu()
            choice = input("\nYour choice: ").strip().lower()

            if choice == 's':
                print("Skipped.")
                return False

            try:
                choice_idx = int(choice)
                if 1 <= choice_idx <= len(CHANGE_TYPES):
                    change_type = CHANGE_TYPES[choice_idx - 1]

                    # 위험평가점수 계산
                    risk_score = RiskCalculator.calculate_risk_score(
                        change_type, summary, description, components, comments
                    )

                    if self.save_label(issue_key, change_type, ticket):
                        print(f"✓ Saved: {issue_key} -> {change_type} (risk: {risk_score}/100)")
                        return True
                    else:
                        print("✗ Failed to save. Try again.")
                else:
                    print(f"Invalid choice. Please enter 1-{len(CHANGE_TYPES)} or s.")
            except ValueError:
                print(f"Invalid input. Please enter 1-{len(CHANGE_TYPES)} or s.")

    def interactive_labeling(self):
        """인터랙티브 레이블링 (수동)"""
        unlabeled_keys = self.get_unlabeled_tickets()

        if not unlabeled_keys:
            print("No unlabeled tickets found. All incidents are already labeled!")
            return

        print(f"\nFound {len(unlabeled_keys)} unlabeled tickets.")
        print("Let's start labeling...\n")

        labeled_count = 0

        for idx, issue_key in enumerate(unlabeled_keys, 1):
            ticket = self.loader.get_jira_ticket_from_dynamodb(issue_key)
            if not ticket:
                print(f"Warning: Ticket not found in DynamoDB: {issue_key}")
                continue

            print(f"\n[{idx}/{len(unlabeled_keys)}]")

            if self.manual_label_single_ticket(ticket):
                labeled_count += 1

        print(f"\n{'=' * 80}")
        print(f"Labeling completed! Total labeled: {labeled_count} tickets")
        print(f"{'=' * 80}")


def main():
    """메인 함수"""
    print("=" * 80)
    print("JIRA Change Type Labeling Tool")
    print("=" * 80)

    # DynamoDB에서 메타데이터 로드
    load_metadata_from_dynamodb()

    # 과거 장애 발생 통계 로드
    print("Loading incident risk statistics...")
    incident_stats = RiskCalculator.load_incident_risk_stats()
    if incident_stats:
        print("\nIncident Risk by Change Type:")
        for change_type, data in sorted(incident_stats.items()):
            rate = data.get('incident_rate', 0.0)
            total = data.get('total', 0)
            incidents = data.get('incidents', 0)
            print(f"  {change_type}: {incidents}/{total} ({rate*100:.1f}% incident rate)")

    labeler = DataLabeler(auto_mode=True)

    # 1. 기존 레이블된 티켓들을 세분화된 changeType으로 재분류 및 riskpoint 업데이트
    print("\n" + "=" * 80)
    print("Step 1: Reclassifying to detailed changeTypes and updating riskpoint")
    print("=" * 80)
    labeler.update_riskpoints_for_labeled_tickets(reclassify=True)

    # 2. 완전 자동 레이블링 모드로 unlabeled 티켓 처리
    print("\n" + "=" * 80)
    print("Step 2: Auto-labeling unlabeled tickets")
    print("=" * 80)
    print("\nStarting fully automatic labeling (no confirmation required)...")
    labeler.auto_labeling(confidence_threshold=0.3, confirm=False)


if __name__ == "__main__":
    main()
