import os
from flask import Flask, request
from werkzeug.utils import secure_filename
app = Flask(__name__)

import pickle, time
@app.route('/upload', methods=["POST"])
def upload():
    print(request.get_json())
    pickle.dump(request.get_json(), open("uploads/" + str(time.time()), "wb"))
    return ""

@app.route('/imageupload/<float:name>', methods=['GET', 'POST'])
def imageupload(name):
	if request.method == 'POST':
		#print(request.data)
		
		filename = secure_filename(str(name) + ".png")
		out = open(os.path.join("image_uploads", filename), "wb")
		out.write(request.data)
		out.close()
	return ''

app.run(host='0.0.0.0', port=80)
