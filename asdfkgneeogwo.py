import re
from datetime import datetime


def extract_text(image_path):
    """
    문서 이미지에서 텍스트를 추출하는 OCR 처리 모듈
    지금은 실행 확인용으로 예시 텍스트를 반환함
    """

    text = """
    임대차 계약서
    이름: 김철수
    주소: 서울시 강남구
    금액: 5000000원
    계약일: 2026-05-10
    만료일: 2026-05-20
    """

    return text


def classify_document(text):
    """
    문서 유형 분류
    """

    if "계약서" in text or "임대차" in text:
        return "계약서"
    elif "영수증" in text or "결제" in text or "합계" in text:
        return "영수증"
    elif "신청서" in text or "접수" in text:
        return "신청서"
    else:
        return "기타 문서"


def extract_key_info(text):
    """
    이름, 금액, 주소, 날짜 추출
    """

    key_info = {}

    name_match = re.search(r"이름:\s*([가-힣]+)", text)
    money_match = re.search(r"금액:\s*([0-9,]+원)", text)
    address_match = re.search(r"주소:\s*(.+)", text)
    date_match = re.findall(r"\d{4}-\d{2}-\d{2}", text)

    key_info["이름"] = name_match.group(1) if name_match else "미확인"
    key_info["금액"] = money_match.group(1) if money_match else "미확인"
    key_info["주소"] = address_match.group(1).strip() if address_match else "미확인"
    key_info["날짜"] = date_match if date_match else []

    return key_info


def analyze_risk(key_info, text):
    """
    위험도 분석
    """

    risk_score = 0
    messages = []

    if key_info["이름"] == "미확인":
        risk_score += 1
        messages.append("이름 정보가 누락되었습니다.")

    if key_info["금액"] == "미확인":
        risk_score += 1
        messages.append("금액 정보가 누락되었습니다.")

    if "위약금" in text or "책임" in text or "손해배상" in text:
        risk_score += 1
        messages.append("주의가 필요한 계약 관련 단어가 포함되어 있습니다.")

    if len(key_info["날짜"]) >= 2:
        end_date = datetime.strptime(key_info["날짜"][-1], "%Y-%m-%d")
        today = datetime.today()

        if end_date < today:
            risk_score += 1
            messages.append("문서의 만료일이 이미 지났습니다.")

    if risk_score == 0:
        level = "안전"
        message = "특별한 위험 요소가 발견되지 않았습니다."
    elif risk_score <= 2:
        level = "주의"
        message = " / ".join(messages)
    else:
        level = "위험"
        message = " / ".join(messages)

    return {
        "level": level,
        "message": message
    }


def main():
    image_path = "sample_document.jpg"

    print("1. OCR 처리 시작")
    text = extract_text(image_path)

    print("2. 문서 분류 시작")
    document_type = classify_document(text)

    print("3. 핵심 정보 추출 시작")
    key_info = extract_key_info(text)

    print("4. 위험도 분석 시작")
    risk_result = analyze_risk(key_info, text)

    print("\n===== 분석 결과 =====")
    print("문서 유형:", document_type)
    print("추출 정보:", key_info)
    print("위험도:", risk_result["level"])
    print("분석 내용:", risk_result["message"])


if __name__ == "__main__":
    main()