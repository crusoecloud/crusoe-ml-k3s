from flask import Flask, send_file
app = Flask(__name__)

@app.route('/k3-server-token')
def serve_text_file1():
    file_path= '/var/lib/rancher/k3s/server/token'
    return send_file(file_path,mimetype='text/plain')

@app.route('/k3-agent-token')
def serve_text_file2():
    file_path= '/var/lib/rancher/k3s/server/node-token'
    return send_file(file_path,mimetype='text/plain')

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5500)
