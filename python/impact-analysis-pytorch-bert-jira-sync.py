#!/usr/bin/env python3
"""
하나 또는 여러 Sprint에 해당하는 모든 Jira 이슈를 가져와서 DynamoDB에 저장하는 스크립트

사용법:
    # 단일 Sprint
    python read_jira_issue_sprint_db.py xxxx

    # 여러 Sprint (공백으로 구분)
    python read_jira_issue_sprint_db.py xxxx xxxx xxxx

    # 기본값 사용 (DEFAULT_SPRINTS)
    python read_jira_issue_sprint_db.py
"""
import sys
import os
import json
import boto3
from jira import JIRA
from datetime import datetime
import pytz
import requests
from requests.auth import HTTPBasicAuth

# config-jira.py에서 설정 읽기
sys.path.append('/git/xxxx')

# Jira 연결 정보
JIRA_EMAIL = "xxxx"
JIRA_URL = "xxxx"
JIRA_TOKEN_FILE = "xxxx"

# DynamoDB 정보
DYNAMODB_TABLE_NAME = "xxxx"
AWS_REGION = "ap-northeast-2"

# Sprint 이름 리스트 (명령행 인자로 받거나 기본값 사용)
DEFAULT_SPRINTS = ["xxxx"]

def extract_text_from_adf(obj):
    """
    Atlassian Document Format(ADF)에서 텍스트 추출

    Args:
        obj: PropertyHolder 객체 또는 기타 객체

    Returns:
        str: 추출된 텍스트
    """
    text_parts = []

    try:
        # 문자열이면 그대로 반환
        if isinstance(obj, str):
            return obj

        # text 속성이 있으면 추가
        if hasattr(obj, 'text'):
            text_parts.append(str(obj.text))

        # content 리스트가 있으면 재귀적으로 처리
        if hasattr(obj, 'content') and isinstance(obj.content, list):
            for item in obj.content:
                sub_text = extract_text_from_adf(item)
                if sub_text:
                    text_parts.append(sub_text)

        return ' '.join(text_parts).strip()

    except Exception as e:
        return ""

def get_jira_issue(issue_key):
    """
    Jira 이슈의 summary, description, components, created, status, sprint, comments를 가져옵니다.

    Args:
        issue_key: Jira 이슈 번호 (예: xxxx)

    Returns:
        dict: summary, description, components, created, status, sprint, comments를 포함한 딕셔너리
    """
    try:
        # API 토큰 읽기
        with open(JIRA_TOKEN_FILE, 'r') as f:
            api_token = f.read().strip()

        # Jira 연결 (API v3 사용)
        jira = JIRA(
            server=JIRA_URL,
            basic_auth=(JIRA_EMAIL, api_token),
            options={'rest_api_version': '3'}
        )

        # 이슈 가져오기
        issue = jira.issue(issue_key)

        # summary, description, components, created, status 추출
        summary = str(issue.fields.summary) if issue.fields.summary else ""

        # description 안전하게 추출 (Atlassian Document Format 처리)
        description = ""
        if hasattr(issue.fields, 'description') and issue.fields.description is not None:
            desc_value = issue.fields.description

            # 문자열이면 그대로 사용
            if isinstance(desc_value, str):
                description = desc_value
            else:
                # PropertyHolder 객체면 ADF에서 텍스트 추출
                type_name = desc_value.__class__.__name__ if hasattr(desc_value, '__class__') else ''

                if 'PropertyHolder' in type_name:
                    # Atlassian Document Format 파싱
                    description = extract_text_from_adf(desc_value)
                    if not description:
                        # 내용이 없으면 빈 문자열
                        description = ""
                else:
                    # 기타 타입은 문자열로 변환
                    description = str(desc_value)

        components = [str(comp.name) for comp in issue.fields.components] if issue.fields.components else []
        created = str(issue.fields.created) if issue.fields.created else ""
        status = str(issue.fields.status.name) if issue.fields.status else ""

        # comments 추출
        comments = []
        try:
            if hasattr(issue.fields, 'comment') and issue.fields.comment:
                for comment in issue.fields.comment.comments:
                    comments.append({
                        'author': str(comment.author.displayName) if hasattr(comment.author, 'displayName') else str(comment.author),
                        'body': str(comment.body) if comment.body else "",
                        'created': str(comment.created) if comment.created else ""
                    })
        except Exception as e:
            print(f"Warning: Could not extract comments: {e}")
            comments = []

        # sprint 추출 (customfield 또는 sprint 필드)
        sprint = None
        try:
            # Sprint 필드 찾기 - 여러 가능한 customfield 확인
            sprint_field_candidates = ['customfield_10020', 'customfield_10010', 'customfield_10104', 'customfield_10001']

            for field_name in sprint_field_candidates:
                if hasattr(issue.fields, field_name):
                    field_value = getattr(issue.fields, field_name)
                    if field_value:
                        # Sprint는 리스트로 반환될 수 있음
                        if isinstance(field_value, list) and len(field_value) > 0:
                            # Sprint 객체에서 name 추출
                            sprint_names = []
                            for s in field_value:
                                if hasattr(s, 'name'):
                                    sprint_names.append(str(s.name))  # str()로 명시적 변환
                                elif isinstance(s, str):
                                    sprint_names.append(s)
                                else:
                                    # PropertyHolder나 기타 객체는 str()로 변환
                                    sprint_names.append(str(s))
                            if sprint_names:
                                sprint = sprint_names
                                break
                        elif isinstance(field_value, str):
                            sprint = field_value
                            break
                        elif hasattr(field_value, 'name'):
                            sprint = str(field_value.name)  # str()로 명시적 변환
                            break
                        else:
                            # PropertyHolder나 기타 객체는 str()로 변환
                            sprint = str(field_value)
                            break

            # 만약 sprint 필드가 직접 있다면
            if not sprint and hasattr(issue.fields, 'sprint'):
                sprint_obj = issue.fields.sprint
                if hasattr(sprint_obj, 'name'):
                    sprint = str(sprint_obj.name)
                else:
                    sprint = str(sprint_obj)

        except Exception as e:
            print(f"Warning: Could not extract sprint field: {e}")
            sprint = None

        return {
            'issue_key': issue_key,
            'summary': summary,
            'description': description,
            'components': components,
            'created': created,
            'status': status,
            'sprint': sprint,
            'comments': comments
        }

    except Exception as e:
        print(f"Error: {e}")
        return None

def save_to_dynamodb(data, issue_key):
    """
    Jira 이슈 데이터를 DynamoDB에 저장합니다.

    Args:
        data: 저장할 데이터 (딕셔너리)
        issue_key: Jira 이슈 번호 (예: xxxx)

    Returns:
        bool: 성공 여부
    """
    try:
        session = boto3.Session(profile_name='AUTO')
        dynamodb = session.resource('dynamodb', region_name=AWS_REGION)
        table = dynamodb.Table(DYNAMODB_TABLE_NAME)

        # DynamoDB 아이템 구성 - 모든 값을 안전하게 변환
        item = {
            'dataId': str(issue_key),
            'summary': str(data.get('summary', '')),
            'description': str(data.get('description', '')),
            'status': str(data.get('status', ''))
        }

        # components가 있으면 추가 (리스트의 모든 항목을 문자열로 변환)
        if data.get('components'):
            components = data['components']
            if isinstance(components, list):
                item['components'] = [str(c) for c in components]
            else:
                item['components'] = [str(components)]

        # sprint가 있으면 추가 (문자열 또는 문자열 리스트로 변환)
        if data.get('sprint'):
            sprint = data['sprint']
            if isinstance(sprint, list):
                item['sprint'] = [str(s) for s in sprint]
            else:
                item['sprint'] = str(sprint)

        # comments가 있으면 추가 (모든 필드를 문자열로 변환)
        if data.get('comments'):
            comments = data['comments']
            if isinstance(comments, list):
                safe_comments = []
                for comment in comments:
                    safe_comment = {
                        'author': str(comment.get('author', '')),
                        'body': str(comment.get('body', '')),
                        'created': str(comment.get('created', ''))
                    }
                    safe_comments.append(safe_comment)
                item['comments'] = safe_comments
            else:
                item['comments'] = []

        # updatedAt 추가 (KST 타임존)
        kst = pytz.timezone('Asia/Seoul')
        now_kst = datetime.now(kst)
        item['updatedAt'] = now_kst.strftime('%Y-%m-%d %H:%M')

        # DynamoDB에 저장
        table.put_item(Item=item)

        print(f"Successfully saved to DynamoDB: {DYNAMODB_TABLE_NAME} (dataId: {issue_key})")
        return True

    except Exception as e:
        print(f"Error saving to DynamoDB: {e}")
        return False

def search_issues_by_sprint(sprint_name):
    """
    특정 Sprint에 해당하는 모든 이슈를 검색합니다.
    requests를 사용하여 새로운 /rest/api/3/search/jql 엔드포인트를 호출합니다.

    Args:
        sprint_name: Sprint 이름 (예: 2026_Sprint01)

    Returns:
        list: 이슈 키 리스트
    """
    try:
        # API 토큰 읽기
        with open(JIRA_TOKEN_FILE, 'r') as f:
            api_token = f.read().strip()

        # JQL로 Sprint 검색
        # Sprint 이름으로 검색 (여러 customfield 시도)
        jql_queries = [
            f'Sprint = "{sprint_name}"',
            f'cf[10020] = "{sprint_name}"',
            f'cf[10010] = "{sprint_name}"',
            f'cf[10104] = "{sprint_name}"',
            f'cf[10001] = "{sprint_name}"'
        ]

        all_issues = []
        auth = HTTPBasicAuth(JIRA_EMAIL, api_token)
        headers = {
            'Accept': 'application/json',
            'Content-Type': 'application/json'
        }

        for jql in jql_queries:
            try:
                print(f"Trying JQL: {jql}")

                # 새로운 API v3 엔드포인트 사용
                url = f"{JIRA_URL}/rest/api/3/search/jql"

                params = {
                    'jql': jql,
                    'maxResults': 1000,
                    'fields': '*all'
                }

                response = requests.get(url, auth=auth, headers=headers, params=params)

                if response.status_code == 200:
                    data = response.json()
                    issues = data.get('issues', [])
                    if issues:
                        print(f"Found {len(issues)} issues with this query")
                        # issue key만 추출
                        issue_keys = [issue['key'] for issue in issues]
                        all_issues.extend(issue_keys)
                        break  # 성공하면 다른 쿼리는 시도하지 않음
                else:
                    print(f"Query failed: HTTP {response.status_code}")
                    print(f"Response: {response.text[:200]}")
                    continue

            except Exception as e:
                print(f"Query failed: {e}")
                continue

        # 중복 제거
        unique_issue_keys = list(set(all_issues))

        print(f"\nTotal unique issues found: {len(unique_issue_keys)}")
        return unique_issue_keys

    except Exception as e:
        print(f"Error searching issues: {e}")
        return []

def process_issue(issue_key):
    """
    단일 이슈를 처리합니다 (가져오기 및 DynamoDB 저장).

    Args:
        issue_key: Jira 이슈 번호

    Returns:
        bool: 성공 여부
    """
    print(f"\nProcessing issue: {issue_key}")
    print("-" * 80)

    result = get_jira_issue(issue_key)

    if result:
        print(f"Issue Key: {result['issue_key']}")
        print(f"Created: {result['created']}")
        print(f"Status: {result['status']}")
        print(f"Summary: {result['summary'][:50]}..." if len(result['summary']) > 50 else result['summary'])
        print(f"Sprint: {', '.join(result['sprint']) if result['sprint'] and isinstance(result['sprint'], list) else (result['sprint'] if result['sprint'] else 'None')}")

        # DynamoDB에 저장
        return save_to_dynamodb(result, issue_key)
    else:
        print(f"Failed to fetch issue: {issue_key}")
        return False

def main():
    # 명령행 인자에서 Sprint 이름 가져오기
    # 여러 Sprint를 공백으로 구분하여 입력 가능
    if len(sys.argv) > 1:
        sprint_names = sys.argv[1:]  # 모든 인자를 Sprint 이름으로 사용
    else:
        sprint_names = DEFAULT_SPRINTS

    print(f"Processing {len(sprint_names)} Sprint(s): {', '.join(sprint_names)}")
    print("=" * 80)

    total_success = 0
    total_fail = 0
    total_issues = 0

    # 각 Sprint 순회 처리
    for sprint_idx, sprint_name in enumerate(sprint_names, 1):
        print(f"\n{'='*80}")
        print(f"[Sprint {sprint_idx}/{len(sprint_names)}] {sprint_name}")
        print(f"{'='*80}")

        # Sprint에 해당하는 모든 이슈 검색
        issue_keys = search_issues_by_sprint(sprint_name)

        if not issue_keys:
            print(f"No issues found for Sprint: {sprint_name}")
            continue

        print(f"\nFound {len(issue_keys)} issues to process")
        print(f"Issues: {', '.join(issue_keys)}")
        print("=" * 80)

        # 각 이슈 처리
        success_count = 0
        fail_count = 0

        for idx, issue_key in enumerate(issue_keys, 1):
            print(f"\n[{sprint_name}] [{idx}/{len(issue_keys)}]")
            if process_issue(issue_key):
                success_count += 1
            else:
                fail_count += 1

        # Sprint별 결과 요약
        print("\n" + "-" * 80)
        print(f"Sprint '{sprint_name}' Summary:")
        print(f"  Total: {len(issue_keys)} issues")
        print(f"  Success: {success_count} issues")
        print(f"  Failed: {fail_count} issues")
        print("-" * 80)

        total_issues += len(issue_keys)
        total_success += success_count
        total_fail += fail_count

    # 전체 결과 요약
    print("\n" + "=" * 80)
    print("Overall Processing Summary:")
    print(f"  Sprints Processed: {len(sprint_names)}")
    print(f"  Total Issues: {total_issues}")
    print(f"  Success: {total_success} issues")
    print(f"  Failed: {total_fail} issues")
    print("=" * 80)

if __name__ == "__main__":
    main()
