import os
import re
import tempfile
from typing import Dict, Tuple
from datetime import datetime

import gspread
from fastapi import FastAPI, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from google.oauth2.service_account import Credentials
import google.generativeai as genai
from PIL import Image

# =========================================================
# 종이 비서 백엔드 서버
# 실행: python server.py
# 주소: http://127.0.0.1:8001
# =========================================================

app = FastAPI(title="종이 비서 API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# =========================================================
# 구글 스프레드시트 설정
# 시트 주소:
# https://docs.google.com/spreadsheets/d/1geMh_An9ZJtOZDAysXqan55JCIOAlp_LX5WHVJYcUG4/edit
#
# 시트 구조:
# A열 user_id / B열 password / C열 name
# =========================================================

SERVICE_ACCOUNT_FILE = "/etc/secrets/credentials.json"
SPREADSHEET_ID = "1geMh_An9ZJtOZDAysXqan55JCiOAIp_LX5WHVJYcUG4"
SHEET_NAME = "users"
SHEET_NAME = "users"
SAVE_SHEET_NAME = "문서저장"

GOOGLE_SCOPE = [
    "https://www.googleapis.com/auth/spreadsheets",
    "https://www.googleapis.com/auth/drive",
]

sheet = None
sheet = None
save_sheet = None
user_cache: Dict[str, Dict[str, str]] = {}
reader = None


# =========================================================
# 구글 시트 연결
# =========================================================

def connect_sheet():
    global sheet, save_sheet

    if sheet is not None and save_sheet is not None:
        return sheet, save_sheet

    if not os.path.exists(SERVICE_ACCOUNT_FILE):
        raise FileNotFoundError("credentials.json 파일이 없습니다.")

    credentials = Credentials.from_service_account_file(
        SERVICE_ACCOUNT_FILE,
        scopes=GOOGLE_SCOPE,
    )

    print("사용 중인 서비스 계정:", credentials.service_account_email)
    print("사용 중인 시트 ID:", SPREADSHEET_ID)
    print("사용 중인 시트 탭 이름:", SHEET_NAME)

    gc = gspread.authorize(credentials)

    try:
        spreadsheet = gc.open_by_key(SPREADSHEET_ID)
        print("연결된 스프레드시트 제목:", spreadsheet.title)

        sheet = spreadsheet.worksheet(SHEET_NAME)
        save_sheet = spreadsheet.worksheet(SAVE_SHEET_NAME)
        
        print("연결된 워크시트 제목:", sheet.title)
        print("저장 워크시트 제목:", save_sheet.title)
        return sheet, save_sheet

    except Exception as e:
        print("정확한 에러 타입:", type(e))
        print("정확한 에러 내용:", repr(e))
        raise e


def load_users_from_sheet():
    global user_cache

    ws, _ = connect_sheet()
    values = ws.get_all_values()
    user_cache = {}

    # 1행은 제목: user_id / password / name
    for row in values[1:]:
        if len(row) < 3:
            continue

        user_id = row[0].strip()
        password = row[1].strip()
        name = row[2].strip()

        if user_id:
            user_cache[user_id] = {
                "password": password,
                "name": name,
            }


@app.on_event("startup")
def startup_event():
    print("서버 시작 완료")


# =========================================================
# OCR 설정
# =========================================================

def extract_text_with_gemini(image_path: str) -> str:
    api_key = os.environ.get("GOOGLE_API_KEY")

    if not api_key:
        raise ValueError("GOOGLE_API_KEY 환경변수가 없습니다.")

    genai.configure(api_key=api_key)

    image = Image.open(image_path)

    model = genai.GenerativeModel("gemini-1.5-flash")

    response = model.generate_content([
        "이 이미지 안의 모든 글자를 OCR처럼 최대한 정확히 한국어로 추출해줘. 설명은 하지 말고 추출된 텍스트만 출력해줘.",
        image
    ])

    return response.text.strip()

# =========================================================
# 로그인
# =========================================================

@app.post("/login")
async def login(
    user_id: str = Form(...),
    password: str = Form(...),
):
    user_id = user_id.strip()
    password = password.strip()

    try:
        if not user_cache:
            load_users_from_sheet()
    except Exception as e:
        return {
            "success": False,
            "message": f"구글 시트 연결 오류: {e}",
        }

    if user_id not in user_cache:
        return {
            "success": False,
            "message": "존재하지 않는 아이디입니다.",
        }

    if user_cache[user_id]["password"] != password:
        return {
            "success": False,
            "message": "비밀번호가 일치하지 않습니다.",
        }

    return {
        "success": True,
        "message": "로그인 성공",
        "user_id": user_id,
        "name": user_cache[user_id]["name"],
    }


# =========================================================
# 회원가입
# =========================================================

@app.post("/signup")
async def signup(
    user_id: str = Form(...),
    password: str = Form(...),
    name: str = Form(...),
):
    user_id = user_id.strip()
    password = password.strip()
    name = name.strip()

    if not user_id or not password or not name:
        return {
            "success": False,
            "message": "아이디, 비밀번호, 이름을 모두 입력해주세요.",
        }

    try:
        if not user_cache:
            load_users_from_sheet()
    except Exception as e:
        return {
            "success": False,
            "message": f"구글 시트 연결 오류: {e}",
        }

    if user_id in user_cache:
        return {
            "success": False,
            "message": "이미 존재하는 아이디입니다.",
        }

    try:
        ws, _ = connect_sheet()

        # 시트 구조: A열 user_id / B열 password / C열 name
        ws.append_row([user_id, password, name])

        user_cache[user_id] = {
            "password": password,
            "name": name,
        }

        return {
            "success": True,
            "message": "회원가입이 완료되었습니다.",
        }

    except Exception as e:
        return {
            "success": False,
            "message": f"회원가입 저장 오류: {e}",
        }


# =========================================================
# 문서 분석 함수
# =========================================================

def classify_document(text: str, selected_type: str = "general") -> str:
    if selected_type == "contract":
        return "계약서"
    if selected_type == "notice":
        return "신청서 / 안내문"
    if selected_type == "receipt":
        return "영수증 / 고지서"
    if selected_type == "general":
        return "기타 문서"

    if "계약서" in text or "임대차" in text:
        return "계약서"
    if "영수증" in text or "결제" in text or "합계" in text:
        return "영수증 / 고지서"
    if "신청서" in text or "접수" in text or "안내" in text:
        return "신청서 / 안내문"

    return "기타 문서"


def extract_key_info(text: str, document_type: str) -> Dict[str, str]:
    name_match = re.search(r"(?:이름|성명|임차인|임대인)[:\s]*([가-힣]{2,5})", text)
    money_matches = re.findall(r"([0-9,]+)\s*원", text)
    address_match = re.search(
        r"(서울|경기|인천|대전|부산|대구|광주|울산|세종|강원|충북|충남|전북|전남|경북|경남|제주)[^\n]+",
        text,
    )
    date_matches = re.findall(
        r"\d{4}\s*[년\-./]\s*\d{1,2}\s*[월\-./]\s*\d{1,2}\s*일?",
        text,
    )

    money_text = "미확인"
    if money_matches:
        money_text = ", ".join([m + "원" for m in money_matches])

    key_info = {
        "문서 종류": document_type,
        "이름": name_match.group(1) if name_match else "미확인",
        "금액": money_text,
        "주소": address_match.group(0).strip() if address_match else "미확인",
        "날짜": ", ".join(date_matches) if date_matches else "미확인",
    }

    if document_type == "계약서":
        key_info["검토 항목"] = "계약 당사자, 금액, 주소, 날짜, 위험 표현"
    elif document_type == "신청서 / 안내문":
        key_info["검토 항목"] = "신청 기한, 제출 서류, 안내 사항"
    elif document_type == "영수증 / 고지서":
        key_info["검토 항목"] = "결제일자, 결제금액, 사용처"
    else:
        key_info["검토 항목"] = "핵심 문장 및 주요 정보"

    return key_info


def analyze_risk(key_info: Dict[str, str], text: str) -> Tuple[str, str]:
    risk_score = 0
    messages = []

    if key_info.get("이름") == "미확인":
        risk_score += 1
        messages.append("계약 당사자 이름이 명확히 확인되지 않았습니다.")

    if key_info.get("금액") == "미확인":
        risk_score += 1
        messages.append("금액 정보가 확인되지 않았습니다.")

    risk_words = [
        "위약금",
        "손해배상",
        "책임",
        "환불 불가",
        "별도 협의",
        "추후 변경",
        "해지",
        "불이익",
        "임의",
        "보증금 반환",
    ]

    found_words = []

    for word in risk_words:
        if word in text:
            risk_score += 1
            found_words.append(word)

    if found_words:
        messages.append("주의 표현: " + ", ".join(found_words))

    if risk_score == 0:
        return "안전", "특별한 위험 요소가 발견되지 않았습니다."

    if risk_score <= 2:
        return "주의", " / ".join(messages)

    return "위험", " / ".join(messages)


def make_summary(
    document_type: str,
    key_info: Dict[str, str],
    risk_level: str = None,
    risk_message: str = None,
) -> str:
    summary = (
        f"이 문서는 {document_type}로 분류됩니다. "
        f"확인된 이름은 {key_info.get('이름', '미확인')}이며, "
        f"금액은 {key_info.get('금액', '미확인')}입니다. "
        f"주소 정보는 {key_info.get('주소', '미확인')}로 확인됩니다. "
        f"날짜 정보는 {key_info.get('날짜', '미확인')}입니다."
    )

    if document_type == "계약서" and risk_level:
        summary += f" 계약서 위험도는 {risk_level} 단계이며, {risk_message}"

    return summary


# =========================================================
# 문서 분석 API
# =========================================================

@app.post("/analyze")
async def analyze_document(
    file: UploadFile = File(...),
    user_id: str = Form(""),
    document_type: str = Form("general"),
):
    try:
        image_bytes = await file.read()

        with tempfile.NamedTemporaryFile(delete=False, suffix=".jpg") as temp_file:
            temp_file.write(image_bytes)
            temp_path = temp_file.name
            
        text = extract_text_with_gemini(temp_path)
        final_document_type = classify_document(text, document_type)
        key_info = extract_key_info(text, final_document_type)

        risk_level = "해당 없음"
        risk_message = "위험도 분석이 적용되지 않는 문서입니다."

        if document_type == "contract":
            risk_level, risk_message = analyze_risk(key_info, text)

        summary = make_summary(
            final_document_type,
            key_info,
            risk_level if document_type == "contract" else None,
            risk_message if document_type == "contract" else None,
        )

        return {
            "success": True,
            "ocr_text": text,
            "document_type": final_document_type,
            "key_info": key_info,
            "risk_level": risk_level,
            "risk_message": risk_message,
            "summary": summary,
        }

    except Exception as e:
        return {
            "success": False,
            "ocr_text": "",
            "document_type": "분석 실패",
            "key_info": {},
            "risk_level": "오류",
            "risk_message": str(e),
            "summary": "문서 분석 중 오류가 발생했습니다.",
        }
    
@app.post("/analyze_multi")
async def analyze_multi_document(
    files: list[UploadFile] = File(...),
    user_id: str = Form(""),
    document_type: str = Form("general"),
):
    try:
        all_texts = []

        for index, file in enumerate(files):
            image_bytes = await file.read()

            with tempfile.NamedTemporaryFile(delete=False, suffix=".jpg") as temp_file:
                temp_file.write(image_bytes)
                temp_path = temp_file.name

            page_text = extract_text_with_gemini(temp_path)
            all_texts.append(f"[{index + 1}쪽]\n{page_text}")

        text = "\n\n".join(all_texts)

        final_document_type = classify_document(text, document_type)
        key_info = extract_key_info(text, final_document_type)

        risk_level = "해당 없음"
        risk_message = "위험도 분석이 적용되지 않는 문서입니다."

        if document_type == "contract":
            risk_level, risk_message = analyze_risk(key_info, text)

        summary = make_summary(
            final_document_type,
            key_info,
            risk_level if document_type == "contract" else None,
            risk_message if document_type == "contract" else None,
        )

        return {
            "success": True,
            "ocr_text": text,
            "document_type": final_document_type,
            "key_info": key_info,
            "risk_level": risk_level,
            "risk_message": risk_message,
            "summary": summary,
            "page_count": len(files),
        }

    except Exception as e:
        return {
            "success": False,
            "ocr_text": "",
            "document_type": "분석 실패",
            "key_info": {},
            "risk_level": "오류",
            "risk_message": str(e),
            "summary": "여러 장 문서 분석 중 오류가 발생했습니다.",
            "page_count": 0,
        }

@app.post("/save_document")
async def save_document(
    user_id: str = Form(...),
    title: str = Form(...),
    doc_type: str = Form(...),
    summary: str = Form(...),
    risk_level: str = Form(""),
    ocr_text: str = Form("")
):
    try:
        _, ws_save = connect_sheet()

        created_at = datetime.now().strftime("%Y-%m-%d %H:%M")

        ws_save.append_row([
            user_id,
            title,
            doc_type,
            summary,
            risk_level,
            ocr_text,
            created_at
        ])

        return {
            "success": True,
            "message": "문서가 구글 시트에 저장되었습니다."
        }

    except Exception as e:
        return {
            "success": False,
            "message": f"문서 저장 중 오류가 발생했습니다: {e}"
        }
    
@app.get("/")
async def root():
    return {"message": "종이 비서 서버 실행 중"}

@app.get("/get_documents")
async def get_documents(user_id: str):
    try:
        _, ws_save = connect_sheet()

        records = ws_save.get_all_records()

        user_docs = []
        for row in records:
            if str(row.get("user_id", "")).strip() == user_id.strip():
                user_docs.append(row)

        return {
            "success": True,
            "documents": user_docs
        }

    except Exception as e:
        return {
            "success": False,
            "message": f"문서 목록 불러오기 오류: {e}",
            "documents": []
        }