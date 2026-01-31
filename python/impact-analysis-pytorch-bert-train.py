#!/usr/bin/env python3
"""
PyTorch 기반 모델 학습 스크립트
KLUE BERT를 사용한 한국어 텍스트 분류
"""
import os
import sys
import json
import boto3
from typing import List, Dict
from data_loader import JiraDataLoader
from preprocessor import JiraTextPreprocessor
from model import ChangeTypeClassifier
from config import (
    MODEL_DIR,
    MODEL_PATH,
    VECTORIZER_PATH,
    MIN_SAMPLES_PER_CLASS,
    AWS_REGION,
    BATCH_SIZE,
    LEARNING_RATE,
    NUM_EPOCHS
)
from collections import Counter
import numpy as np


def prepare_training_data(
    tickets: List[Dict],
    change_types: Dict[str, str],
    preprocessor: JiraTextPreprocessor,
    incident_history_keys: List[str]
) -> tuple[List[str], List[str], List[bool]]:
    """
    학습 데이터 준비

    Args:
        tickets: JIRA 티켓 리스트
        change_types: {issue_key: changeType} 매핑
        preprocessor: 텍스트 전처리기
        incident_history_keys: INCIDENT#HISTORY에서 가져온 incident issue_key 리스트

    Returns:
        (texts, labels, is_incident): 텍스트, 레이블, incident 여부 리스트
    """
    # incident_history_keys를 set으로 변환 (빠른 검색)
    incident_set = set(incident_history_keys)

    texts = []
    labels = []
    is_incident = []

    for ticket in tickets:
        issue_key = ticket.get('issue_key')

        # 레이블이 있는 티켓만 사용
        if issue_key not in change_types:
            continue

        # 텍스트 추출 및 전처리
        text = preprocessor.extract_features(ticket)
        if not text:
            continue

        label = change_types[issue_key]
        incident = issue_key in incident_set

        texts.append(text)
        labels.append(label)
        is_incident.append(incident)

    return texts, labels, is_incident


def check_data_quality(texts: List[str], labels: List[str]) -> bool:
    """
    학습 데이터의 품질 검사

    Args:
        texts: 텍스트 리스트
        labels: 레이블 리스트

    Returns:
        bool: 학습 가능 여부
    """
    if len(texts) < 10:
        print(f"Error: Not enough training samples. Need at least 10, got {len(texts)}")
        return False

    # 클래스별 샘플 수 확인
    label_counts = Counter(labels)

    print("\nClass distribution (Before balancing):")
    for label, count in sorted(label_counts.items()):
        print(f"  {label}: {count} samples")

    # 최소 샘플 수 확인
    min_count = min(label_counts.values())
    max_count = max(label_counts.values())
    imbalance_ratio = max_count / min_count if min_count > 0 else float('inf')

    print(f"\nImbalance ratio: {imbalance_ratio:.2f}:1")

    if min_count < MIN_SAMPLES_PER_CLASS:
        print(f"\nWarning: Some classes have less than {MIN_SAMPLES_PER_CLASS} samples.")
        print(f"Minimum samples per class: {min_count}")
        print("Will apply data balancing techniques.")

    return True


def balance_data(
    texts: List[str],
    labels: List[str],
    preprocessor: JiraTextPreprocessor,
    strategy: str = 'auto'
) -> tuple[List[str], List[str]]:
    """
    불균형 데이터 처리 - PyTorch 모델이 class_weight로 처리하므로 간단한 증강만 수행

    Args:
        texts: 텍스트 리스트
        labels: 레이블 리스트
        preprocessor: 텍스트 전처리기
        strategy: 'augment', 'auto'

    Returns:
        (balanced_texts, balanced_labels): 균형잡힌 텍스트와 레이블
    """
    label_counts = Counter(labels)
    min_count = min(label_counts.values())
    max_count = max(label_counts.values())
    imbalance_ratio = max_count / min_count if min_count > 0 else float('inf')

    print(f"\n[Data Balancing]")
    print(f"Imbalance ratio: {imbalance_ratio:.2f}:1")

    # 불균형이 심하지 않으면 그대로 사용
    if imbalance_ratio < 2.0:
        print("Data is relatively balanced. No balancing needed.")
        return texts, labels

    # PyTorch 모델이 class_weight로 처리하므로 간단한 증강만 수행
    print("Using text augmentation for minority classes")
    print("Note: PyTorch model will use class weights for additional balancing")

    return augment_text_data(texts, labels)


def augment_text_data(texts: List[str], labels: List[str]) -> tuple[List[str], List[str]]:
    """
    소수 클래스 데이터 증강

    Args:
        texts: 텍스트 리스트
        labels: 레이블 리스트

    Returns:
        (augmented_texts, augmented_labels)
    """
    label_counts = Counter(labels)
    max_count = max(label_counts.values())

    augmented_texts = list(texts)
    augmented_labels = list(labels)

    # 각 클래스별로 최대 클래스 수만큼 증강
    for label, count in label_counts.items():
        if count < max_count:
            # 해당 레이블의 텍스트만 추출
            label_texts = [text for text, l in zip(texts, labels) if l == label]

            # 부족한 만큼 증강
            needed = max_count - count
            for i in range(needed):
                # 원본 텍스트 선택 (순환)
                original_text = label_texts[i % len(label_texts)]
                # 증강
                augmented_text = augment_single_text(original_text)

                augmented_texts.append(augmented_text)
                augmented_labels.append(label)

    print(f"\nAugmented {len(augmented_texts) - len(texts)} samples")
    return augmented_texts, augmented_labels


def augment_single_text(text: str) -> str:
    """
    단일 텍스트 증강 (동의어 치환, 문장 순서 변경 등)

    Args:
        text: 원본 텍스트

    Returns:
        증강된 텍스트
    """
    # 간단한 증강: 단어 순서 약간 변경, 공백 추가 등
    words = text.split()

    # 기법 1: 마지막 단어와 앞 단어 스왑
    if len(words) > 3:
        import random
        idx = random.randint(0, len(words) - 2)
        words[idx], words[idx + 1] = words[idx + 1], words[idx]

    return ' '.join(words)


def boost_incident_samples(
    texts: List[str],
    labels: List[str],
    is_incident: List[bool],
    boost_factor: int = 3
) -> tuple[List[str], List[str], List[bool]]:
    """
    Incident가 발생한 샘플을 강조하여 학습 데이터 증강

    Args:
        texts: 텍스트 리스트
        labels: 레이블 리스트
        is_incident: incident 여부 리스트
        boost_factor: incident 샘플 복제 배수 (기본값: 3배)

    Returns:
        (boosted_texts, boosted_labels, boosted_is_incident): 증강된 데이터
    """
    boosted_texts = []
    boosted_labels = []
    boosted_is_incident = []

    incident_count = sum(is_incident)

    if incident_count == 0:
        print("\n[Incident Boost]")
        print("  No incident samples found. Skipping boost.")
        return texts, labels, is_incident

    print(f"\n[Incident Boost]")
    print(f"  Original incident samples: {incident_count}")
    print(f"  Boost factor: {boost_factor}x")

    for text, label, incident in zip(texts, labels, is_incident):
        # 모든 샘플 추가
        boosted_texts.append(text)
        boosted_labels.append(label)
        boosted_is_incident.append(incident)

        # incident 샘플은 추가로 복제
        if incident:
            for _ in range(boost_factor - 1):
                # 약간의 변형을 주어 복제 (과적합 방지)
                augmented_text = augment_single_text(text)
                boosted_texts.append(augmented_text)
                boosted_labels.append(label)
                boosted_is_incident.append(incident)

    new_incident_count = sum(boosted_is_incident)
    print(f"  After boost: {new_incident_count} incident samples ({new_incident_count - incident_count} added)")
    print(f"  Total samples: {len(texts)} → {len(boosted_texts)}")

    return boosted_texts, boosted_labels, boosted_is_incident


def analyze_incident_risk(
    tickets: List[Dict],
    change_types: Dict[str, str],
    incident_history_keys: List[str]
) -> tuple[Dict, List[str]]:
    """
    변경 유형별 장애 발생 비율 분석

    Args:
        tickets: JIRA 티켓 리스트
        change_types: {issue_key: changeType} 매핑
        incident_history_keys: INCIDENT#HISTORY에서 가져온 incident issue_key 리스트

    Returns:
        tuple[Dict, List[str]]: (변경 유형별 장애 발생 통계, incident 발생 issue_key 리스트)
    """
    # incident_history_keys를 set으로 변환 (빠른 검색)
    incident_set = set(incident_history_keys)

    # 변경 유형별 incident 통계
    stats = {}
    current_incident_keys = []  # 현재 학습 데이터에서 발견된 incident

    for ticket in tickets:
        issue_key = ticket.get('issue_key')
        if issue_key not in change_types:
            continue

        change_type = change_types[issue_key]
        is_incident = issue_key in incident_set

        if change_type not in stats:
            stats[change_type] = {
                'total': 0,
                'incidents': 0,
                'incident_rate': 0.0
            }

        stats[change_type]['total'] += 1
        if is_incident:
            stats[change_type]['incidents'] += 1
            current_incident_keys.append(issue_key)

    # 비율 계산
    for change_type, data in stats.items():
        if data['total'] > 0:
            data['incident_rate'] = data['incidents'] / data['total']

    return stats, current_incident_keys


def save_incident_risk_stats(
    stats: Dict,
    incident_issue_keys: List[str],
    existing_incident_keys: List[str],
    output_path: str
):
    """
    장애 발생 통계를 DynamoDB와 파일에 저장
    기존 incident history와 새로 발견한 incident를 합쳐서 저장

    Args:
        stats: 변경 유형별 장애 발생 통계
        incident_issue_keys: 현재 학습 데이터에서 발견한 incident issue_key 리스트
        existing_incident_keys: 기존 INCIDENT#HISTORY의 issue_key 리스트
        output_path: 파일 저장 경로 (백업용)
    """
    try:
        # 기존 incident와 새로 발견한 incident를 합침 (중복 제거)
        all_incident_keys = list(set(existing_incident_keys + incident_issue_keys))

        print(f"\n[Incident History Update]")
        print(f"  Existing incidents: {len(existing_incident_keys)}")
        print(f"  New incidents found: {len(incident_issue_keys)}")
        print(f"  Total unique incidents: {len(all_incident_keys)}")

        # 1. DynamoDB에 저장
        session = boto3.Session(profile_name='AUTO')
        dynamodb = session.resource('dynamodb', region_name=AWS_REGION)
        metadata_table = dynamodb.Table('impactanalysis-metadata')

        # INCIDENT#HISTORY에 issue_key 리스트를 | 구분자로 저장
        incident_history = '|'.join(sorted(all_incident_keys)) if all_incident_keys else ''

        metadata_table.put_item(
            Item={
                'dataId': 'INCIDENT#HISTORY',
                'metadata': incident_history
            }
        )

        print(f"\n✓ Incident history saved to DynamoDB")
        print(f"  Table: impactanalysis-metadata")
        print(f"  DataId: INCIDENT#HISTORY")
        print(f"  Total incidents: {len(all_incident_keys)}")

        # 2. 파일에도 백업 저장 (호환성 유지)
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(stats, f, indent=2, ensure_ascii=False)
        print(f"  Backup file: {output_path}")

    except Exception as e:
        print(f"Error saving incident risk statistics: {e}")
        # DynamoDB 저장 실패시 최소한 파일에는 저장
        try:
            with open(output_path, 'w', encoding='utf-8') as f:
                json.dump(stats, f, indent=2, ensure_ascii=False)
            print(f"  Fallback: saved to file only - {output_path}")
        except:
            pass


def main():
    """메인 학습 프로세스"""

    print("=" * 80)
    print("JIRA Change Type Classifier - Training")
    print("=" * 80)

    # 1. 데이터 로딩
    print("\n[1/8] Loading data from DynamoDB and S3...")
    loader = JiraDataLoader()

    # 기존 INCIDENT#HISTORY 로드 (학습 참고자료)
    print("\nLoading existing incident history...")
    existing_incident_keys = loader.get_incident_history()

    # 레이블된 데이터 가져오기
    change_types = loader.get_existing_change_types()
    if not change_types:
        print("Error: No labeled data found in DynamoDB.")
        print("Please add 'changeType' field to some incidents first.")
        sys.exit(1)

    # 학습에 사용할 issue_key: changeType이 있는 것 + 기존 incident 이력
    all_issue_keys = set(change_types.keys())
    all_issue_keys.update(existing_incident_keys)

    print(f"Total issue keys to load: {len(all_issue_keys)}")
    print(f"  - Labeled (changeType): {len(change_types)}")
    print(f"  - Historical incidents: {len(existing_incident_keys)}")

    # 해당 issue_key의 티켓 데이터 가져오기 (incident 정보 포함)
    print("\nLoading tickets with incident information...")
    tickets = loader.get_tickets_from_dynamodb(list(all_issue_keys))

    print(f"Loaded {len(tickets)} tickets")

    # 2. 전처리
    print("\n[2/8] Preprocessing text...")
    preprocessor = JiraTextPreprocessor()
    texts, labels, is_incident = prepare_training_data(tickets, change_types, preprocessor, existing_incident_keys)

    print(f"Prepared {len(texts)} training samples")
    print(f"  - Incident samples: {sum(is_incident)}")
    print(f"  - Normal samples: {len(texts) - sum(is_incident)}")

    # 3. 데이터 품질 검사
    print("\n[3/8] Checking data quality...")
    if not check_data_quality(texts, labels):
        sys.exit(1)

    # 4. Incident 샘플 증강 (장애 이력 활용)
    print("\n[4/8] Boosting incident samples...")
    texts, labels, is_incident = boost_incident_samples(texts, labels, is_incident, boost_factor=3)

    # 5. 불균형 데이터 처리 (간단한 증강만)
    print("\n[5/8] Balancing imbalanced data...")
    texts, labels = balance_data(texts, labels, preprocessor, strategy='auto')

    # 6. PyTorch BERT 모델 학습 (클래스 가중치 적용)
    print("\n[6/8] Training PyTorch BERT model with class weights...")

    # GPU 사용 확인
    import torch
    if not torch.cuda.is_available():
        print("❌ Error: GPU not available!")
        print("   This script requires GPU for training.")
        print("   Please ensure:")
        print("   - CUDA is properly installed")
        print("   - PyTorch is installed with CUDA support")
        print("   - GPU device is available")
        sys.exit(1)

    # GPU 정보 출력
    gpu_name = torch.cuda.get_device_name(0)
    gpu_count = torch.cuda.device_count()
    print(f"✓ Using GPU: {gpu_name}")
    print(f"  Available GPUs: {gpu_count}")
    print(f"  CUDA Version: {torch.version.cuda}")

    model_name = 'klue/bert-base'
    print(f"  Model: {model_name}")

    model = ChangeTypeClassifier(
        model_name=model_name,
        batch_size=BATCH_SIZE,
        learning_rate=LEARNING_RATE,
        num_epochs=NUM_EPOCHS,
        use_class_weight=True
    )
    model.train(texts, labels)

    # 7. 모델 저장
    print("\n[7/8] Saving model...")
    os.makedirs(MODEL_DIR, exist_ok=True)

    # MODEL_PATH에서 확장자 제거하고 vectorizer와 classifier 파일명 생성
    base_path = MODEL_PATH.rsplit('.', 1)[0]
    vectorizer_save_path = VECTORIZER_PATH if VECTORIZER_PATH else f"{base_path}_vectorizer.pkl"
    classifier_save_path = f"{base_path}_classifier.pkl"

    model.save(vectorizer_save_path, classifier_save_path)

    # 8. 변경 유형별 장애 발생 비율 분석 및 저장
    print("\n[8/8] Analyzing incident risk by change type...")
    incident_stats, incident_issue_keys = analyze_incident_risk(tickets, change_types, existing_incident_keys)

    print("\nIncident Risk by Change Type:")
    for change_type, data in sorted(incident_stats.items()):
        print(f"  {change_type}: {data['incidents']}/{data['total']} "
              f"({data['incident_rate']*100:.1f}% incident rate)")

    print(f"\nTotal incidents found: {len(incident_issue_keys)}")
    if incident_issue_keys:
        print(f"Incident issue keys: {', '.join(incident_issue_keys[:5])}")
        if len(incident_issue_keys) > 5:
            print(f"  ... and {len(incident_issue_keys) - 5} more")

    # 통계 저장 (DynamoDB + 파일)
    incident_risk_path = f"{MODEL_DIR}/incident_risk_stats.json"
    save_incident_risk_stats(incident_stats, incident_issue_keys, existing_incident_keys, incident_risk_path)

    print("\n" + "=" * 80)
    print("Training completed successfully!")
    print("=" * 80)
    print("\nNext steps:")
    print("  1. Review the model performance above")
    print("  2. Run predict.py to classify unlabeled tickets")
    print("  3. Update predictions in DynamoDB")
    print(f"  4. Incident risk stats saved: {incident_risk_path}")


if __name__ == "__main__":
    main()
