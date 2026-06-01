import os
from flask import Flask, request, jsonify

app = Flask(__name__)

# [핵심] 파일이 실제로 저장될 컴퓨터 안의 절대 경로 설정
BASE_UPLOAD_FOLDER = os.path.join(os.getcwd(), 'uploads')

documents = []

@app.route('/upload', methods=['POST'])
def upload():
    category = request.form.get('category', 'others')
    
    if 'file' not in request.files:
        return jsonify({"message": "파일이 없습니다."}), 400
        
    file = request.files['file']
    
    if file.filename == '':
        return jsonify({"message": "선택된 파일이 없습니다."}), 400

    category_folder = os.path.join(BASE_UPLOAD_FOLDER, category)
    
    if not os.path.exists(category_folder):
        os.makedirs(category_folder)
        
    save_path = os.path.join(category_folder, file.filename)
    file.save(save_path)

    document = {
        "fileName": file.filename,
        "category": category,
        "path": save_path
    }
    documents.append(document)

    return jsonify({
        "message": "카테고리 분류 저장 완료!",
        "document": document
    })

@app.route('/documents')
def get_documents():
    return jsonify(documents)

if __name__ == "__main__":
    app.run(debug=True)
